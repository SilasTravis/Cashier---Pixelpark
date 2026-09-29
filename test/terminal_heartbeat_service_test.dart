import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/network/connectivity_interceptor.dart';
import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/core/terminal/terminal_heartbeat_service.dart';
import 'package:cashier_app/core/update/update_failure_log.dart';

/// Answers every request with [statusCode] (or throws [error]) and records
/// what was sent.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 204, this.error});

  final int statusCode;
  final Object? error;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (error != null) throw error!;
    return ResponseBody.fromString('', statusCode);
  }

  @override
  void close({bool force = false}) {}
}

/// Every collaborator of [TerminalHeartbeatService] as a plain field a test
/// can flip.
class _Harness {
  _Harness({_RecordingAdapter? adapter})
    : adapter = adapter ?? _RecordingAdapter() {
    api.httpClientAdapter = this.adapter;
  }

  final _RecordingAdapter adapter;
  final Dio api = Dio(BaseOptions(baseUrl: 'https://api.example.test/api'));
  final modes = StreamController<AppModeState>.broadcast();
  final sessions = StreamController<void>.broadcast();
  AppModeState mode = const AppModeState();
  bool hasSession = true;
  int unsynced = 0;
  UpdateFailureRecord? failure;
  String hostname = 'KASSA-1';
  String osVersion = 'Windows 10 Pro 22H2 (build 19045)';

  late final TerminalHeartbeatService service = TerminalHeartbeatService(
    api: api,
    hasSession: () => hasSession,
    sessionChanges: sessions.stream,
    terminalId: () => '0b4f7c52-8c7e-4d0e-9a55-3f7b1e2d9c10',
    appVersion: '1.0.7',
    modeState: () => mode,
    modeStates: modes.stream,
    unsyncedSales: () => unsynced,
    lastUpdateFailure: () => failure,
    hostname: () => hostname,
    osVersion: () => osVersion,
  );

  List<Map<String, dynamic>> get bodies => [
    for (final request in adapter.requests)
      jsonDecode(jsonEncode(request.data)) as Map<String, dynamic>,
  ];

  void emitMode(AppMode value) {
    mode = mode.copyWith(mode: value);
    modes.add(mode);
  }
}

// Inside fakeAsync, `async.elapse(Duration.zero)` rather than
// `flushMicrotasks()`: Dio's request pipeline hops through zero-length
// timers, which only an elapse runs.
void main() {
  test('posts the contract body to the heartbeat path', () async {
    final h = _Harness()
      ..unsynced = 3
      ..failure = UpdateFailureRecord(
        version: '1.0.8',
        code: 'checksumMismatch',
        message: 'bad digest',
        at: DateTime.utc(2026, 9, 29, 12),
      );

    await h.service.beat();

    final request = h.adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/pos/terminal/heartbeat');
    expect(h.bodies.single, {
      'terminalId': '0b4f7c52-8c7e-4d0e-9a55-3f7b1e2d9c10',
      'appVersion': '1.0.7',
      'hostname': 'KASSA-1',
      'osVersion': 'Windows 10 Pro 22H2 (build 19045)',
      'mode': 'online',
      'unsyncedSales': 3,
      'lastUpdateFailure': {
        'version': '1.0.8',
        'code': 'checksumMismatch',
        'message': 'bad digest',
        'at': '2026-09-29T12:00:00.000Z',
      },
    });
  });

  test('no failure is sent as null; syncing reports offline', () async {
    final h = _Harness()..mode = const AppModeState(mode: AppMode.syncing);

    await h.service.beat();

    expect(h.bodies.single['lastUpdateFailure'], isNull);
    expect(h.bodies.single.containsKey('lastUpdateFailure'), isTrue);
    expect(h.bodies.single['mode'], 'offline');
  });

  test('hostname and osVersion are cut to the backend limits', () async {
    final h = _Harness()
      ..hostname = 'h' * 150
      ..osVersion = 'o' * 300;

    await h.service.beat();

    expect((h.bodies.single['hostname'] as String).length, 100);
    expect((h.bodies.single['osVersion'] as String).length, 200);
  });

  test('is marked background so it never raises the offline prompt', () async {
    final h = _Harness();

    await h.service.beat();

    expect(
      h.adapter.requests.single.extra[ConnectivityInterceptor.backgroundKey],
      isTrue,
    );
  });

  test('sends nothing without a session', () async {
    final h = _Harness()..hasSession = false;

    await h.service.beat();

    expect(h.adapter.requests, isEmpty);
  });

  test('swallows transport and HTTP errors', () async {
    final failing = _Harness(
      adapter: _RecordingAdapter(error: StateError('x')),
    );
    final notFound = _Harness(adapter: _RecordingAdapter(statusCode: 404));

    await failing.service.beat();
    await notFound.service.beat();

    expect(failing.adapter.requests, hasLength(1));
    expect(notFound.adapter.requests, hasLength(1));
  });

  test('start beats at once, then every 2 minutes; dispose stops it', () {
    fakeAsync((async) {
      final h = _Harness();

      h.service.start();
      async.elapse(Duration.zero);
      expect(h.adapter.requests, hasLength(1));

      async.elapse(const Duration(minutes: 1, seconds: 59));
      expect(h.adapter.requests, hasLength(1));
      async.elapse(const Duration(seconds: 1));
      expect(h.adapter.requests, hasLength(2));
      async.elapse(const Duration(minutes: 2));
      expect(h.adapter.requests, hasLength(3));

      h.service.dispose();
      async.elapse(const Duration(minutes: 10));
      expect(h.adapter.requests, hasLength(3));
      expect(async.periodicTimerCount, 0);
    });
  });

  test('a mode flip sends a beat; other cubit emits do not', () {
    fakeAsync((async) {
      final h = _Harness();
      h.service.start();
      async.elapse(Duration.zero);

      // A count change or a prompt is not a mode change.
      h.modes.add(
        h.mode.copyWith(pendingCount: 2, prompt: ModePrompt.goOffline),
      );
      async.elapse(Duration.zero);
      expect(h.adapter.requests, hasLength(1));

      h.emitMode(AppMode.offline);
      async.elapse(Duration.zero);
      expect(h.adapter.requests, hasLength(2));
      expect(h.bodies.last['mode'], 'offline');

      // online → syncing → online: syncing already counts as offline.
      h.emitMode(AppMode.syncing);
      async.elapse(Duration.zero);
      expect(h.adapter.requests, hasLength(2));
      h.emitMode(AppMode.online);
      async.elapse(Duration.zero);
      expect(h.adapter.requests, hasLength(3));
      expect(h.bodies.last['mode'], 'online');

      h.service.dispose();
    });
  });

  test('signing in sends a beat right away, a token refresh does not', () {
    fakeAsync((async) {
      final h = _Harness()..hasSession = false;
      h.service.start();
      async.elapse(Duration.zero);
      expect(h.adapter.requests, isEmpty);

      h.hasSession = true;
      h.sessions.add(null);
      async.elapse(Duration.zero);
      expect(h.adapter.requests, hasLength(1));

      // Refresh rewrites the token: still the same session.
      h.sessions.add(null);
      async.elapse(Duration.zero);
      expect(h.adapter.requests, hasLength(1));

      // Logout, then the next cashier signs in.
      h.hasSession = false;
      h.sessions.add(null);
      async.elapse(Duration.zero);
      h.hasSession = true;
      h.sessions.add(null);
      async.elapse(Duration.zero);
      expect(h.adapter.requests, hasLength(2));

      h.service.dispose();
    });
  });
}
