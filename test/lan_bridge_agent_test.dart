import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cashier_app/core/lan_bridge/frame.dart';
import 'package:cashier_app/core/lan_bridge/lan_bridge_agent.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake DNS: `mixed.local` lists the link-local address FIRST, so OPEN_OK
/// must carry `fe80::1` (connect goes to the first address).
final Map<String, List<InternetAddress>> _dns = {
  'pi.local': [InternetAddress('127.0.0.1')],
  'public.example': [InternetAddress('8.8.8.8')],
  'mixed.local': [InternetAddress('fe80::1'), InternetAddress('127.0.0.1')],
};

final List<String> _lookups = [];

Future<List<InternetAddress>> _fakeLookup(String host) async {
  _lookups.add(host);
  final r = _dns[host];
  if (r == null) throw SocketException('no such host $host');
  return r;
}

Future<void> _until(bool Function() cond, {String what = 'condition'}) async {
  final sw = Stopwatch()..start();
  while (!cond()) {
    if (sw.elapsed > const Duration(seconds: 2)) {
      fail('timed out waiting for $what');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Local TCP echo server playing the Pi; counts connections that ended.
class _Echo {
  _Echo._(this.server);
  final ServerSocket server;
  int accepted = 0;
  int ended = 0;
  final List<Socket> conns = [];

  static Future<_Echo> start() async {
    final e = _Echo._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));
    e.server.listen((c) {
      e.accepted++;
      e.conns.add(c);
      c.done.then((_) {}, onError: (_) {});
      c.listen(
        c.add,
        onDone: () {
          e.ended++;
          c.destroy();
        },
        onError: (_) {
          e.ended++;
          c.destroy();
        },
        cancelOnError: true,
      );
    });
    return e;
  }

  int get port => server.port;

  Future<void> stop() async {
    for (final c in conns) {
      c.destroy();
    }
    await server.close();
  }
}

/// A local HttpServer upgraded with WebSocketTransformer plays the backend;
/// [ctl] is its end of the agent WebSocket.
class _Harness {
  _Harness(this.server, this.ctl, this.agent);
  final HttpServer server;
  final WebSocket ctl;
  final LanBridgeAgent agent;
  final List<Frame> frames = [];
  int? closeCode;

  void send(Frame f) => ctl.add(encodeFrame(f));

  List<T> of<T extends Frame>() => frames.whereType<T>().toList();

  static Future<_Harness> start({
    Map<String, Object?> info = const {},
    SocketConnector? connect,
    int maxStreams = 64,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final upgraded = Completer<WebSocket>();
    server.listen((req) async {
      upgraded.complete(await WebSocketTransformer.upgrade(req));
    });
    final agentWs = await WebSocket.connect('ws://127.0.0.1:${server.port}');
    final ctl = await upgraded.future;
    final agent = LanBridgeAgent(
      socket: agentWs,
      info: info,
      lookup: _fakeLookup,
      connect: connect,
      maxStreams: maxStreams,
    );
    final h = _Harness(server, ctl, agent);
    ctl.listen(
      (m) => h.frames.add(decodeFrame(Uint8List.fromList(m as List<int>))),
      onDone: () => h.closeCode = ctl.closeCode,
    );
    agent.start();
    return h;
  }

  Future<void> stop() async {
    await agent.close();
    await ctl.close();
    await server.close(force: true);
  }
}

/// In-memory WebSocket for fakeAsync / backpressure tests.
class _FakeWs extends Stream<dynamic> implements WebSocket {
  final StreamController<dynamic> incoming = StreamController<dynamic>();
  final List<Frame> sent = [];
  final List<int?> closeCodes = [];

  void push(Frame f) => incoming.add(encodeFrame(f));

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
  void add(dynamic data) => sent.add(decodeFrame(data as Uint8List));

  @override
  Future<void> close([int? code, String? reason]) async {
    closeCodes.add(code);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory TCP socket whose flush() can be held open by the test.
class _FakeSocket extends Stream<Uint8List> implements Socket {
  _FakeSocket({this.holdFlush = false});
  final bool holdFlush;
  final StreamController<Uint8List> incoming = StreamController<Uint8List>();
  final Completer<void> _done = Completer<void>();
  Completer<void>? pendingFlush;
  int received = 0;
  int flushes = 0;
  bool destroyed = false;
  bool closed = false;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
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
  void add(List<int> data) {
    if (pendingFlush != null) throw StateError('add during flush');
    received += data.length;
  }

  @override
  Future<void> flush() {
    flushes++;
    if (!holdFlush) return Future<void>.value();
    pendingFlush = Completer<void>();
    return pendingFlush!.future;
  }

  void releaseFlush() {
    final c = pendingFlush!;
    pendingFlush = null;
    c.complete();
  }

  @override
  void destroy() {
    destroyed = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> close() {
    // Like IOSink: a sink bound by flush() throws synchronously.
    if (pendingFlush != null) throw StateError('close during flush');
    closed = true;
    if (!_done.isCompleted) _done.complete();
    return _done.future;
  }

  @override
  Future<void> get done => _done.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List _bytes(int n) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 31 + 7) & 0xff));

void main() {
  late _Echo echo;
  _Harness? h;

  setUp(() async {
    _lookups.clear();
    echo = await _Echo.start();
  });

  tearDown(() async {
    await h?.stop();
    h = null;
    await echo.stop();
  });

  test('sends INFO first', () async {
    h = await _Harness.start(
      info: {
        'branch': 'x',
        'agent': {'version': '1.0.28'},
      },
    );
    await _until(() => h!.frames.isNotEmpty, what: 'INFO');
    final info = (h!.frames.first as InfoFrame).info;
    expect(info['branch'], 'x');
    final agent = info['agent'] as Map<String, Object?>;
    expect(agent['kind'], 'dart');
    expect(agent['version'], '1.0.28');
    expect(agent['host'], isA<String>());
  });

  test(
    'OPEN pi.local:echoPort → OPEN_OK 127.0.0.1 and 1 MiB echoes back intact',
    () async {
      h = await _Harness.start();
      h!.send(OpenFrame(1, 'pi.local', echo.port));
      await _until(() => h!.of<OpenOkFrame>().isNotEmpty, what: 'OPEN_OK');
      expect(h!.of<OpenOkFrame>().single.resolvedIp, '127.0.0.1');
      expect(h!.frames.first, isA<InfoFrame>());

      final payload = _bytes(1 << 20);
      h!.send(DataFrame(1, payload)); // one 1 MiB frame: also hits the flush
      int got() => h!.of<DataFrame>().fold(0, (n, f) => n + f.data.length);
      await _until(() => got() == payload.length, what: '1 MiB echo');
      final data = h!.of<DataFrame>();
      expect(data.every((f) => f.streamId == 1), isTrue);
      expect(data.every((f) => f.data.length <= 64 * 1024), isTrue);
      final echoed = BytesBuilder(copy: false);
      for (final f in data) {
        echoed.add(f.data);
      }
      expect(echoed.takeBytes(), payload);
    },
  );

  test('OPEN mixed.local is allowed (all LAN)', () async {
    final dialed = <InternetAddress>[];
    h = await _Harness.start(
      // Records the address, then reaches the echo on loopback (fe80::1 is
      // not routable on the test host).
      connect: (a, p, {timeout = const Duration(seconds: 5)}) {
        dialed.add(a);
        return Socket.connect(
          InternetAddress.loopbackIPv4,
          p,
          timeout: timeout,
        );
      },
    );
    h!.send(OpenFrame(1, 'mixed.local', echo.port));
    await _until(() => h!.of<OpenOkFrame>().isNotEmpty, what: 'OPEN_OK');
    expect(h!.of<OpenOkFrame>().single.resolvedIp, 'fe80::1');
    expect(dialed.map((a) => a.address), ['fe80::1']);
  });

  test(
    'OPEN public.example → OPEN_FAIL not-lan and no connect attempt',
    () async {
      var dials = 0;
      h = await _Harness.start(
        connect: (a, p, {timeout = const Duration(seconds: 5)}) {
          dials++;
          return Socket.connect(a, p, timeout: timeout);
        },
      );
      h!.send(OpenFrame(1, 'public.example', 80));
      h!.send(OpenFrame(3, 'nowhere.invalid', 80));
      h!.send(OpenFrame(5, '8.8.4.4', 80));
      await _until(() => h!.of<OpenFailFrame>().length == 3, what: 'fails');
      final reasons = {
        for (final f in h!.of<OpenFailFrame>()) f.streamId: f.reason,
      };
      expect(reasons, {
        1: OpenFailReason.notLan,
        3: OpenFailReason.resolve,
        5: OpenFailReason.notLan,
      });
      expect(dials, 0);
      expect(_lookups, ['public.example', 'nowhere.invalid']); // IP: no lookup
      expect(h!.agent.openStreams, 0);
    },
  );

  test('OPEN to a closed port → refused', () async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = s.port;
    await s.close();
    h = await _Harness.start();
    h!.send(OpenFrame(1, '127.0.0.1', port));
    await _until(() => h!.of<OpenFailFrame>().isNotEmpty, what: 'OPEN_FAIL');
    expect(h!.of<OpenFailFrame>().single.reason, OpenFailReason.refused);
    expect(h!.agent.openStreams, 0);
  });

  test('connect that never completes → timeout after 5 s (fakeAsync)', () {
    fakeAsync((async) {
      final ws = _FakeWs();
      final pending = Completer<Socket>();
      final agent = LanBridgeAgent(
        socket: ws,
        info: const {},
        lookup: _fakeLookup,
        connect: (a, p, {timeout = const Duration(seconds: 5)}) =>
            pending.future,
      )..start();
      ws.push(const OpenFrame(1, 'pi.local', 22));
      async.elapse(const Duration(milliseconds: 4900));
      expect(ws.sent.whereType<OpenFailFrame>(), isEmpty);
      expect(agent.openStreams, 1);
      async.elapse(const Duration(milliseconds: 200));
      final fails = ws.sent.whereType<OpenFailFrame>().toList();
      expect(fails.single.reason, OpenFailReason.timeout);
      expect(agent.openStreams, 0);

      // A connect that lands after the timeout is torn down, never used.
      final late = _FakeSocket();
      pending.complete(late);
      async.flushMicrotasks();
      expect(late.destroyed, isTrue);
      expect(ws.sent.whereType<OpenOkFrame>(), isEmpty);
      agent.close();
      async.flushMicrotasks();
    });
  });

  // 65th OPEN with the default 64 is the same rule; maxStreams: 3 keeps the
  // test small, so the 4th OPEN is the one refused.
  test('65th OPEN → limit (maxStreams: 3, 4th fails)', () async {
    h = await _Harness.start(maxStreams: 3);
    for (final id in [1, 3, 5]) {
      h!.send(OpenFrame(id, 'pi.local', echo.port));
    }
    h!.send(OpenFrame(7, 'pi.local', echo.port)); // counted while resolving
    await _until(
      () =>
          h!.of<OpenOkFrame>().length == 3 && h!.of<OpenFailFrame>().isNotEmpty,
      what: '3 OK + 1 limit',
    );
    final fail = h!.of<OpenFailFrame>().single;
    expect(fail.streamId, 7);
    expect(fail.reason, OpenFailReason.limit);
    expect(h!.agent.openStreams, 3);

    h!.send(const CloseFrame(1, false));
    await _until(() => h!.agent.openStreams == 2, what: 'slot freed');
    h!.send(OpenFrame(9, 'pi.local', echo.port));
    await _until(() => h!.of<OpenOkFrame>().length == 4, what: 'reuse slot');
  });

  test(
    'CLOSE from controller destroys the socket; echo server sees EOF',
    () async {
      h = await _Harness.start();
      h!.send(OpenFrame(1, 'pi.local', echo.port));
      await _until(() => h!.of<OpenOkFrame>().isNotEmpty, what: 'OPEN_OK');
      await _until(() => echo.accepted == 1, what: 'accept');
      h!.send(const CloseFrame(1, false));
      await _until(() => echo.ended == 1, what: 'echo EOF');
      expect(h!.agent.openStreams, 0);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(h!.of<CloseFrame>(), isEmpty); // no CLOSE reply
    },
  );

  test(
    'WebSocket closed by the server → every socket destroyed and done completes',
    () async {
      h = await _Harness.start();
      h!.send(OpenFrame(1, 'pi.local', echo.port));
      h!.send(OpenFrame(3, '127.0.0.1', echo.port));
      await _until(() => h!.of<OpenOkFrame>().length == 2, what: 'OPEN_OK x2');
      await _until(() => echo.accepted == 2, what: 'accept x2');
      await h!.ctl.close(1000);
      await h!.agent.done.timeout(const Duration(seconds: 2));
      await _until(() => echo.ended == 2, what: 'both sockets gone');
      expect(h!.agent.openStreams, 0);
    },
  );

  test('remote end → CLOSE(false); remote error → CLOSE(true)', () async {
    final sockets = <_FakeSocket>[];
    final ws = _FakeWs();
    final agent = LanBridgeAgent(
      socket: ws,
      info: const {},
      connect: (a, p, {timeout = const Duration(seconds: 5)}) async {
        final s = _FakeSocket();
        sockets.add(s);
        return s;
      },
    )..start();
    ws.push(const OpenFrame(1, '10.0.0.5', 22));
    ws.push(const OpenFrame(3, '10.0.0.6', 22));
    await _until(() => ws.sent.whereType<OpenOkFrame>().length == 2);
    sockets[0].incoming.add(Uint8List.fromList([1, 2, 3]));
    await sockets[0].incoming.close();
    sockets[1].incoming.addError(const SocketException('reset'));
    await _until(() => ws.sent.whereType<CloseFrame>().length == 2);
    final data = ws.sent.whereType<DataFrame>().single;
    expect(data.streamId, 1);
    expect(data.data, [1, 2, 3]);
    final closes = {
      for (final c in ws.sent.whereType<CloseFrame>()) c.streamId: c.error,
    };
    expect(closes, {1: false, 3: true});
    expect(sockets[0].closed, isTrue); // graceful: pending writes flushed
    expect(sockets[1].destroyed, isTrue);
    expect(agent.openStreams, 0);
    await agent.close();
  });

  test(
    'unknown ids, duplicate OPEN and CLOSE while resolving are ignored',
    () async {
      final ws = _FakeWs();
      final release = Completer<List<InternetAddress>>();
      var dials = 0;
      final agent = LanBridgeAgent(
        socket: ws,
        info: const {},
        lookup: (h) => release.future,
        connect: (a, p, {timeout = const Duration(seconds: 5)}) async {
          dials++;
          return _FakeSocket();
        },
      )..start();
      ws.push(DataFrame(99, Uint8List.fromList([1])));
      ws.push(const CloseFrame(99, false));
      ws.push(const OpenFrame(1, 'slow.local', 22));
      ws.push(const OpenFrame(1, 'slow.local', 22)); // duplicate: ignored
      await _until(() => agent.openStreams == 1);
      ws.push(const CloseFrame(1, false));
      await _until(() => agent.openStreams == 0);
      release.complete([InternetAddress('127.0.0.1')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(dials, 0);
      expect(ws.sent.length, 1); // INFO only
      expect(ws.closeCodes, isEmpty);
      await agent.close();
    },
  );

  test('text message → ws closed 1002 and sockets destroyed', () async {
    final s = _FakeSocket();
    final ws = _FakeWs();
    final agent = LanBridgeAgent(
      socket: ws,
      info: const {},
      connect: (a, p, {timeout = const Duration(seconds: 5)}) async => s,
    )..start();
    ws.push(const OpenFrame(1, '10.0.0.5', 22));
    await _until(() => ws.sent.whereType<OpenOkFrame>().isNotEmpty);
    ws.incoming.add('hello');
    await agent.done.timeout(const Duration(seconds: 1));
    expect(ws.closeCodes, [1002]);
    expect(s.destroyed, isTrue);
    expect(agent.openStreams, 0);
    await agent.close(); // idempotent
    expect(ws.closeCodes, [1002]);
    expect(ws.incoming.hasListener, isFalse); // subscription cancelled
  });

  test('real ws: a text message closes it with 1002', () async {
    h = await _Harness.start();
    h!.send(OpenFrame(1, 'pi.local', echo.port));
    await _until(() => h!.of<OpenOkFrame>().isNotEmpty, what: 'OPEN_OK');
    h!.ctl.add('hello');
    await _until(() => h!.closeCode != null, what: 'ws close');
    expect(h!.closeCode, 1002);
    await h!.agent.done.timeout(const Duration(seconds: 2));
    await _until(() => echo.ended == 1, what: 'socket destroyed');
  });

  test(
    'peer ends while a flush is pending → socket destroyed, CLOSE(false), ws resumed',
    () async {
      final s = _FakeSocket(holdFlush: true);
      final ws = _FakeWs();
      final agent = LanBridgeAgent(
        socket: ws,
        info: const {},
        connect: (a, p, {timeout = const Duration(seconds: 5)}) async => s,
      )..start();
      ws.push(const OpenFrame(1, '192.168.1.10', 22));
      await _until(() => ws.sent.whereType<OpenOkFrame>().isNotEmpty);
      ws.push(DataFrame(1, _bytes(1 << 20)));
      await _until(() => s.pendingFlush != null, what: 'flush');
      expect(ws.incoming.isPaused, isTrue);
      await s.incoming.close();
      await _until(() => ws.sent.whereType<CloseFrame>().isNotEmpty);
      expect(ws.sent.whereType<CloseFrame>().single.error, isFalse);
      expect(s.destroyed, isTrue);
      expect(ws.incoming.isPaused, isFalse);
      expect(agent.openStreams, 0);
      await agent.close();
    },
  );

  test('close() is idempotent and closes the ws with 1000', () async {
    final ws = _FakeWs();
    final agent = LanBridgeAgent(socket: ws, info: const {})..start();
    await agent.close();
    await agent.close();
    await agent.done;
    expect(ws.closeCodes, [1000]);
    expect(ws.incoming.hasListener, isFalse);
  });

  test(
    'WS→TCP backpressure: a never-reading sink makes the agent pause the WebSocket subscription until flush completes',
    () async {
      final s = _FakeSocket(holdFlush: true);
      final ws = _FakeWs();
      final agent = LanBridgeAgent(
        socket: ws,
        info: const {},
        connect: (a, p, {timeout = const Duration(seconds: 5)}) async => s,
      )..start();
      ws.push(const OpenFrame(1, '192.168.1.10', 22));
      await _until(() => ws.sent.whereType<OpenOkFrame>().isNotEmpty);

      ws.push(DataFrame(1, _bytes(512 * 1024)));
      await _until(() => s.received == 512 * 1024);
      expect(s.flushes, 0); // below 1 MiB: no flush, not paused
      expect(ws.incoming.isPaused, isFalse);

      ws.push(DataFrame(1, _bytes(512 * 1024))); // reaches 1 MiB
      await _until(() => s.pendingFlush != null, what: 'flush');
      expect(ws.incoming.isPaused, isTrue);

      ws.push(DataFrame(1, _bytes(10)));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(s.received, 1 << 20); // not read while paused

      s.releaseFlush();
      await _until(() => s.received == (1 << 20) + 10, what: 'resume');
      expect(ws.incoming.isPaused, isFalse);
      expect(s.flushes, 1); // counter reset after the flush
      await agent.close();
    },
  );
}
