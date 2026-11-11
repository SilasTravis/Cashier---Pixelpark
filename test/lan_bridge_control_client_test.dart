import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cashier_app/core/lan_bridge/frame.dart';
import 'package:cashier_app/core/lan_bridge/lan_bridge_control_client.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

const _controlPath = '/api/v1/pos/lan-bridge/control';

Future<void> _until(bool Function() cond, {String what = 'condition'}) async {
  final sw = Stopwatch()..start();
  while (!cond()) {
    if (sw.elapsed > const Duration(seconds: 2)) {
      fail('timed out waiting for $what');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Terminal token store double: forget() nulls it and fires a change.
class _Token {
  _Token(this.value);
  String? value;
  int forgotten = 0;
  final StreamController<void> changes = StreamController<void>.broadcast();

  Future<void> forget() async {
    forgotten++;
    value = null;
    changes.add(null);
  }

  void set(String? v) {
    value = v;
    changes.add(null);
  }
}

class _Net {
  bool online = true;
  final StreamController<void> changes = StreamController<void>.broadcast();

  void set(bool v) {
    online = v;
    changes.add(null);
  }
}

/// Local HttpServer playing the backend: the control path and per-session
/// agent paths are upgraded with WebSocketTransformer.
class _Backend {
  _Backend._(this.server);
  final HttpServer server;

  /// When set, the control upgrade is answered with this HTTP status.
  int? refuseControl;
  final List<String?> controlAuth = [];
  final List<WebSocket> controls = [];
  final List<List<Map<String, Object?>>> controlMessages = [];
  final List<String?> agentAuth = [];
  final List<WebSocket> agents = [];
  final List<Map<String, Object?>> agentInfos = [];

  /// Server-side streams that ended (the cashier closed its end).
  int controlsEnded = 0;
  int agentsEnded = 0;

  static Future<_Backend> start() async {
    final b = _Backend._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    b.server.listen(b._handle);
    return b;
  }

  String get apiBaseUrl => 'http://127.0.0.1:${server.port}/api';

  Future<void> _handle(HttpRequest req) async {
    final auth = req.headers.value(HttpHeaders.authorizationHeader);
    if (req.uri.path == _controlPath) {
      controlAuth.add(auth);
      if (refuseControl != null) {
        req.response.statusCode = refuseControl!;
        await req.response.close();
        return;
      }
      final ws = await WebSocketTransformer.upgrade(req);
      final msgs = <Map<String, Object?>>[];
      controls.add(ws);
      controlMessages.add(msgs);
      ws.listen(
        (m) => msgs.add(jsonDecode(m as String) as Map<String, Object?>),
        onError: (Object _) {},
        onDone: () => controlsEnded++,
      );
      return;
    }
    if (req.uri.path.startsWith('/api/v1/pos/lan-bridge/sessions/') &&
        req.uri.path.endsWith('/agent')) {
      agentAuth.add(auth);
      final ws = await WebSocketTransformer.upgrade(req);
      agents.add(ws);
      ws.listen(
        (m) {
          final f = decodeFrame(Uint8List.fromList(m as List<int>));
          if (f is InfoFrame) agentInfos.add(f.info);
        },
        onError: (Object _) {},
        onDone: () => agentsEnded++,
      );
      return;
    }
    req.response.statusCode = 404;
    await req.response.close();
  }

  void sendControl(Map<String, Object?> msg, {int index = -1}) {
    final ws = index < 0 ? controls.last : controls[index];
    ws.add(jsonEncode(msg));
  }

  Future<void> stop() async {
    for (final w in [...controls, ...agents]) {
      await w.close();
    }
    await server.close(force: true);
  }
}

Map<String, Object?> _open(String id, {String token = 'agent-tok-1'}) => {
  'type': 'session.open',
  'sessionId': id,
  'agentToken': token,
  'wsPath': '/api/v1/pos/lan-bridge/sessions/$id/agent',
};

void main() {
  group('real sockets', () {
    late _Backend backend;
    late _Token token;
    late _Net net;
    late LanBridgeControlClient client;
    late List<LanBridgeState> states;
    late List<Uri> dialled;

    LanBridgeControlClient make({
      Duration min = const Duration(milliseconds: 20),
    }) {
      final c = LanBridgeControlClient(
        apiBaseUrl: () => backend.apiBaseUrl,
        terminalToken: () => token.value,
        tokenChanges: token.changes.stream,
        forgetToken: token.forget,
        terminalId: () => 'term-1',
        appVersion: '1.0.30',
        hostname: () => 'till-pc',
        isOnline: () => net.online,
        onlineChanges: net.changes.stream,
        connect: (u, h) {
          dialled.add(u);
          return WebSocket.connect(u.toString(), headers: h);
        },
        minBackoff: min,
      );
      c.states.listen(states.add);
      return c;
    }

    setUp(() async {
      backend = await _Backend.start();
      token = _Token('term-tok-1');
      net = _Net();
      states = [];
      dialled = [];
    });

    tearDown(() async {
      client.dispose();
      await backend.stop();
    });

    test(
      'without a token the state is disabled and nothing connects',
      () async {
        token.value = null;
        client = make()..start();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(client.state.control, ControlStatus.disabled);
        expect(dialled, isEmpty);
        expect(backend.controlAuth, isEmpty);
      },
    );

    test('connects with the bearer header and sends hello', () async {
      client = make()..start();
      await _until(
        () =>
            backend.controlMessages.isNotEmpty &&
            backend.controlMessages.first.isNotEmpty,
        what: 'hello',
      );
      expect(
        dialled.single.toString(),
        'ws://127.0.0.1:${backend.server.port}$_controlPath',
      );
      expect(backend.controlAuth.single, 'Bearer term-tok-1');
      expect(backend.controlMessages.first.first, {
        'type': 'hello',
        'terminalId': 'term-1',
        'appVersion': '1.0.30',
        'hostname': 'till-pc',
      });
      expect(client.state.control, ControlStatus.connected);
      expect(
        states.map((s) => s.control),
        containsAllInOrder([ControlStatus.connecting, ControlStatus.connected]),
      );
    });

    test(
      'session.open spawns one agent; a second session.open is ignored while active',
      () async {
        client = make()..start();
        await _until(() => client.state.control == ControlStatus.connected);
        backend.sendControl(_open('s1', token: 'agent-tok-1'));
        await _until(() => backend.agentInfos.isNotEmpty, what: 'INFO');
        expect(backend.agentAuth.single, 'Bearer agent-tok-1');
        final agentInfo = backend.agentInfos.single['agent'] as Map;
        expect(agentInfo['version'], '1.0.30');
        expect(agentInfo['host'], 'till-pc');
        expect(client.state.activeSessionId, 's1');
        expect(client.state.activeSince, isNotNull);

        backend.sendControl(_open('s2', token: 'agent-tok-2'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(backend.agentAuth, ['Bearer agent-tok-1']);
        expect(client.state.activeSessionId, 's1');
      },
    );

    test('agent end clears activeSessionId', () async {
      client = make()..start();
      await _until(() => client.state.control == ControlStatus.connected);
      backend.sendControl(_open('s1'));
      await _until(() => backend.agentInfos.isNotEmpty, what: 'INFO');
      await backend.agents.single.close();
      await _until(
        () => client.state.activeSessionId == null,
        what: 'session cleared',
      );
      expect(client.state.activeSince, isNull);
      expect(client.state.control, ControlStatus.connected);

      // A new session is accepted afterwards.
      backend.sendControl(_open('s2', token: 'agent-tok-2'));
      await _until(() => backend.agentInfos.length == 2, what: 'second INFO');
      expect(client.state.activeSessionId, 's2');
    });

    test('session.close for the active id closes the agent', () async {
      client = make()..start();
      await _until(() => client.state.control == ControlStatus.connected);
      backend.sendControl(_open('s1'));
      await _until(() => backend.agentInfos.isNotEmpty, what: 'INFO');
      backend.sendControl({'type': 'session.close', 'sessionId': 'other'});
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(client.state.activeSessionId, 's1');
      backend.sendControl({'type': 'session.close', 'sessionId': 's1'});
      await _until(
        () => backend.agentsEnded == 1 && client.state.activeSessionId == null,
        what: 'agent closed',
      );
    });

    test(
      '401 on upgrade forgets the token and goes disabled; a new token resumes',
      () async {
        backend.refuseControl = 401;
        client = make()..start();
        await _until(() => token.forgotten == 1, what: 'forget');
        await _until(() => client.state.control == ControlStatus.disabled);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(backend.controlAuth.length, 1);

        backend.refuseControl = null;
        token.set('term-tok-2');
        await _until(() => client.state.control == ControlStatus.connected);
        expect(backend.controlAuth.last, 'Bearer term-tok-2');
      },
    );

    test('503 on upgrade backs off and keeps the token', () async {
      backend.refuseControl = 503;
      client = make()..start();
      await _until(() => backend.controlAuth.length >= 4, what: 'retries');
      expect(token.forgotten, 0);
      expect(client.state.control, ControlStatus.connecting);
    });

    test(
      'terminal.revoked closes the agent, forgets the token and goes disabled',
      () async {
        client = make()..start();
        await _until(() => client.state.control == ControlStatus.connected);
        backend.sendControl(_open('s1'));
        await _until(() => backend.agentInfos.isNotEmpty, what: 'INFO');

        backend.sendControl({'type': 'terminal.revoked'});
        await backend.controls.single.close(1008, 'revoked');
        await _until(() => backend.agentsEnded == 1, what: 'agent closed');
        await _until(() => client.state.control == ControlStatus.disabled);
        expect(token.forgotten, 1);
        expect(client.state.activeSessionId, isNull);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(backend.controlAuth.length, 1, reason: 'no reconnect');
      },
    );

    test('goes offline → closes control, online again → reconnects', () async {
      client = make()..start();
      await _until(() => client.state.control == ControlStatus.connected);

      net.set(false);
      await _until(() => backend.controlsEnded == 1, what: 'control closed');
      expect(client.state.control, ControlStatus.connecting);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(backend.controlAuth.length, 1, reason: 'no dial while offline');

      net.set(true);
      await _until(() => backend.controls.length == 2, what: 'reconnect');
      await _until(() => client.state.control == ControlStatus.connected);
    });

    test('going offline leaves a running agent alone', () async {
      client = make()..start();
      await _until(() => client.state.control == ControlStatus.connected);
      backend.sendControl(_open('s1'));
      await _until(() => backend.agentInfos.isNotEmpty, what: 'INFO');
      net.set(false);
      await _until(() => client.state.control == ControlStatus.connecting);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(client.state.activeSessionId, 's1');
    });
  });

  group('fakeAsync backoff', () {
    late _Token token;
    late _Net net;
    late List<Duration> dialTimes;
    late List<_FakeWs> sockets;

    LanBridgeControlClient make(FakeAsync async, {Object? Function()? fail}) {
      return LanBridgeControlClient(
        apiBaseUrl: () => 'https://test.api.pixelpark.uz/api',
        terminalToken: () => token.value,
        tokenChanges: token.changes.stream,
        forgetToken: token.forget,
        terminalId: () => 'term-1',
        appVersion: '1.0.30',
        hostname: () => 'till-pc',
        isOnline: () => net.online,
        onlineChanges: net.changes.stream,
        connect: (u, h) {
          dialTimes.add(async.elapsed);
          expect(
            u.toString(),
            'wss://test.api.pixelpark.uz/api/v1/pos/lan-bridge/control',
          );
          final err = fail?.call();
          if (err != null) return Future<WebSocket>.error(err);
          final ws = _FakeWs();
          sockets.add(ws);
          return Future<WebSocket>.value(ws);
        },
      );
    }

    setUp(() {
      token = _Token('term-tok-1');
      net = _Net();
      dialTimes = [];
      sockets = [];
    });

    List<int> gaps() => [
      for (var i = 1; i < dialTimes.length; i++)
        (dialTimes[i] - dialTimes[i - 1]).inSeconds,
    ];

    test('server close → reconnect after 1 s, 2 s, 4 s … capped at 60 s', () {
      fakeAsync((async) {
        final c = make(async)..start();
        async.flushMicrotasks();
        const expected = [1, 2, 4, 8, 16, 32, 60, 60];
        for (final s in expected) {
          expect(sockets.last.pingInterval, const Duration(seconds: 30));
          sockets.last.serverClose();
          async.flushMicrotasks();
          final before = sockets.length;
          async.elapse(Duration(seconds: s) - const Duration(milliseconds: 1));
          expect(sockets.length, before, reason: 'too early for $s s');
          async.elapse(const Duration(milliseconds: 1));
          expect(sockets.length, before + 1, reason: 'not dialled at $s s');
        }
        expect(gaps(), expected);
        c.dispose();
      });
    });

    test('a connection that stayed open > 60 s resets the backoff to 1 s', () {
      fakeAsync((async) {
        final c = make(async)..start();
        async.flushMicrotasks();
        sockets.last.serverClose();
        async.elapse(const Duration(seconds: 1)); // #2
        sockets.last.serverClose();
        async.elapse(const Duration(seconds: 2)); // #3, next would be 4 s
        expect(sockets.length, 3);
        async.elapse(const Duration(seconds: 61));
        sockets.last.serverClose();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        expect(sockets.length, 4);
        c.dispose();
      });
    });

    test(
      'upgrade refusals without a status code back off and keep the token',
      () {
        fakeAsync((async) {
          var refuse = true;
          final c = make(
            async,
            fail: () => refuse
                ? const WebSocketException(
                    "Connection to 'x' was not upgraded to websocket",
                  )
                : null,
          )..start();
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 1 + 2 + 4));
          expect(dialTimes.length, 4);
          expect(gaps(), [1, 2, 4]);
          expect(token.forgotten, 0);
          expect(token.value, 'term-tok-1');
          expect(c.state.control, ControlStatus.connecting);

          refuse = false;
          async.elapse(const Duration(seconds: 8));
          expect(dialTimes.length, 5);
          expect(c.state.control, ControlStatus.connected);
          c.dispose();
        });
      },
    );

    test('a control dial that lands after connectTimeout is closed', () {
      fakeAsync((async) {
        final pending = Completer<WebSocket>();
        final c = LanBridgeControlClient(
          apiBaseUrl: () => 'https://test.api.pixelpark.uz/api',
          terminalToken: () => token.value,
          tokenChanges: token.changes.stream,
          forgetToken: token.forget,
          terminalId: () => 'term-1',
          appVersion: '1.0.30',
          hostname: () => 'till-pc',
          isOnline: () => net.online,
          onlineChanges: net.changes.stream,
          connect: (u, h) {
            dialTimes.add(async.elapsed);
            return dialTimes.length == 1
                ? pending.future
                : Completer<WebSocket>().future;
          },
        )..start();
        async.elapse(const Duration(seconds: 21)); // past the 20 s timeout
        expect(c.state.control, ControlStatus.connecting);
        final late = _FakeWs();
        pending.complete(late);
        async.flushMicrotasks();
        expect(late.closed, isTrue);
        c.dispose();
        async.flushMicrotasks();
      });
    });

    test('network errors back off without counting as refusals', () {
      fakeAsync((async) {
        final c = make(async, fail: () => const SocketException('no route'))
          ..start();
        async.elapse(const Duration(seconds: 1 + 2 + 4 + 8));
        expect(dialTimes.length, 5);
        expect(token.forgotten, 0);
        expect(c.state.control, ControlStatus.connecting);
        c.dispose();
      });
    });

    test('repeated online/token events do not cut the backoff short', () {
      fakeAsync((async) {
        final c = make(async)..start();
        async.flushMicrotasks();
        sockets.last.serverClose();
        async.elapse(const Duration(seconds: 1)); // #2
        sockets.last.serverClose();
        async.flushMicrotasks(); // next retry in 2 s
        for (var i = 0; i < 5; i++) {
          net.changes.add(null); // still online
          token.changes.add(null); // same token
          async.elapse(const Duration(milliseconds: 300));
        }
        expect(sockets.length, 2);
        async.elapse(const Duration(milliseconds: 500));
        expect(sockets.length, 3);
        c.dispose();
      });
    });

    test(
      'a single control socket even when token and online fire together',
      () {
        fakeAsync((async) {
          final c = make(async)..start();
          token.changes.add(null);
          net.changes.add(null);
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          expect(sockets.length, 1);
          c.dispose();
          async.flushMicrotasks();
          expect(sockets.single.closed, isTrue);
        });
      },
    );
  });
}

/// In-memory control WebSocket for fakeAsync tests.
class _FakeWs extends Stream<dynamic> implements WebSocket {
  final StreamController<dynamic> incoming = StreamController<dynamic>();
  final List<Object?> sent = [];
  bool closed = false;

  @override
  Duration? pingInterval;

  void serverClose() {
    if (!incoming.isClosed) incoming.close();
  }

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => incoming.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  void add(dynamic data) => sent.add(data);

  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    serverClose();
  }

  @override
  int? get closeCode => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
