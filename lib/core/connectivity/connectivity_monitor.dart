import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

/// One reachability observation. [fromUserRequest] marks a real request the
/// cashier just made that failed to connect (vs. the background poll): after
/// a declined offline prompt, only those re-offer offline mode.
class ConnectivityEvent extends Equatable {
  const ConnectivityEvent({
    required this.reachable,
    this.fromUserRequest = false,
  });

  final bool reachable;
  final bool fromUserRequest;

  @override
  List<Object?> get props => [reachable, fromUserRequest];
}

typedef HealthProbe = Future<bool> Function();

/// Polls the backend's health endpoint and relays request failures. Two
/// consecutive failed polls count as an outage, so a single dropped packet
/// never interrupts the cashier.
class ConnectivityMonitor {
  ConnectivityMonitor({
    required HealthProbe probe,
    this.interval = const Duration(seconds: 15),
    this.failuresBeforeUnreachable = 2,
    // ignore: prefer_initializing_formals
  }) : _probe = probe;

  final HealthProbe _probe;
  final Duration interval;
  final int failuresBeforeUnreachable;

  final _events = StreamController<ConnectivityEvent>.broadcast();
  Timer? _timer;
  int _failures = 0;
  bool _probing = false;

  Stream<ConnectivityEvent> get events => _events.stream;

  void start() => _timer ??= Timer.periodic(interval, (_) => _tick());

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// The "Onlaynni tekshirish" button: one probe, answered directly. The
  /// caller decides what to do, so nothing is emitted.
  Future<bool> checkNow() async {
    final reachable = await _safeProbe();
    if (reachable) _failures = 0;
    return reachable;
  }

  /// Called by `ConnectivityInterceptor` when a real request can't connect.
  void reportRequestFailure() {
    if (_events.isClosed) return;
    _events.add(
      const ConnectivityEvent(reachable: false, fromUserRequest: true),
    );
  }

  Future<void> _tick() async {
    if (_probing) return;
    _probing = true;
    try {
      final reachable = await _safeProbe();
      // dispose() may have closed the stream while the probe was in flight.
      if (_events.isClosed) return;
      if (reachable) {
        _failures = 0;
        _events.add(const ConnectivityEvent(reachable: true));
      } else if (++_failures >= failuresBeforeUnreachable) {
        _events.add(const ConnectivityEvent(reachable: false));
      }
    } finally {
      _probing = false;
    }
  }

  Future<bool> _safeProbe() async {
    try {
      return await _probe();
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    stop();
    await _events.close();
  }
}

/// `GET {baseUrl}/health` on a bare client — no auth, no retry interceptor,
/// 5 s timeouts — so an outage is noticed in seconds.
HealthProbe httpHealthProbe(String Function() baseUrl, {Dio? dio}) {
  final client =
      dio ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
  return () async {
    final response = await client.get<dynamic>(
      '${baseUrl()}/health',
      options: Options(validateStatus: (_) => true),
    );
    return response.statusCode == 200;
  };
}
