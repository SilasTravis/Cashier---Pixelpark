import 'dart:async';

import 'package:dio/dio.dart';

import '../network/connectivity_interceptor.dart';
import '../offline/app_mode_cubit.dart';
import '../update/update_failure_log.dart';

/// Tells the backend "this till is alive, runs this version, is in this
/// mode" (`POST /v1/pos/terminal/heartbeat`), so the dashboard's
/// Terminallar page can show which tills are outdated, offline, sitting on
/// unsynced sales or stuck on a failed update.
///
/// A terminal is one installation, not one cashier: [_terminalId] is
/// generated once per install (see `LocalSource.getTerminalId`), and the
/// backend takes the cashier and branch from the token.
///
/// Sent right away on [start], every [_interval] after that, when a session
/// appears (a cashier just signed in), and when the app mode flips between
/// online and offline. Purely diagnostic: every failure is swallowed, the
/// request is marked background so it can never raise the offline prompt,
/// and nothing is sent without a session.
class TerminalHeartbeatService {
  TerminalHeartbeatService({
    required this._api,
    required this._hasSession,
    required this._terminalId,
    required this._appVersion,
    required this._modeState,
    required this._modeStates,
    required this._unsyncedSales,
    required this._lastUpdateFailure,
    required this._hostname,
    required this._osVersion,
    this._sessionChanges,
    this._interval = const Duration(minutes: 2),
  });

  static const String path = '/v1/pos/terminal/heartbeat';

  /// The backend's column limits (`cashier_terminals`).
  static const int maxAppVersionLength = 30;
  static const int maxHostnameLength = 100;
  static const int maxOsVersionLength = 200;

  final Dio _api;

  /// Whether a cashier is signed in. Without a token the heartbeat would
  /// 401, and the app client's refresh-on-401 ends the session — resetting
  /// the login screen under a cashier who is typing into it (the same
  /// guard as `BackendReleaseSource`).
  final bool Function() _hasSession;

  final String Function() _terminalId;
  final String _appVersion;
  final AppModeState Function() _modeState;
  final Stream<AppModeState> _modeStates;

  /// Every sale queued on this till and not yet on the server — all
  /// cashiers, failed ones included: they are this terminal's backlog
  /// whoever rang them up.
  final int Function() _unsyncedSales;

  final UpdateFailureRecord? Function() _lastUpdateFailure;
  final String Function() _hostname;
  final String Function() _osVersion;

  /// Fires whenever the stored session may have changed (e.g. the Hive
  /// access-token key). Only a no-session → session transition sends a
  /// beat, so "just signed in" reaches the dashboard without waiting for
  /// the next tick.
  final Stream<void>? _sessionChanges;

  final Duration _interval;

  Timer? _timer;
  StreamSubscription<AppModeState>? _modeSubscription;
  StreamSubscription<void>? _sessionSubscription;
  String? _lastMode;
  bool _hadSession = false;
  bool _disposed = false;

  /// `syncing` still sells offline (the queue is being replayed), so it
  /// reports as offline; the contract only knows `online` and `offline`.
  static String wireMode(AppModeState state) =>
      state.isOffline ? 'offline' : 'online';

  /// Idempotent: a second call restarts the timer without doubling the
  /// subscriptions.
  void start() {
    if (_disposed) return;
    _timer?.cancel();
    _lastMode = wireMode(_modeState());
    _hadSession = _hasSession();
    _modeSubscription ??= _modeStates.listen(_onModeState);
    _sessionSubscription ??= _sessionChanges?.listen((_) => _onSession());
    unawaited(beat());
    _timer = Timer.periodic(_interval, (_) => unawaited(beat()));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    unawaited(_modeSubscription?.cancel());
    unawaited(_sessionSubscription?.cancel());
  }

  void _onModeState(AppModeState state) {
    final mode = wireMode(state);
    // The cubit also emits for prompts and queue counts; only a real mode
    // flip is worth an extra beat.
    if (mode == _lastMode) return;
    _lastMode = mode;
    unawaited(beat());
  }

  void _onSession() {
    final hasSession = _hasSession();
    final signedIn = hasSession && !_hadSession;
    _hadSession = hasSession;
    if (signedIn) unawaited(beat());
  }

  /// The heartbeat body, per the backend contract.
  Map<String, dynamic> buildBody() => {
    'terminalId': _terminalId(),
    'appVersion': _truncate(_appVersion, maxAppVersionLength),
    'hostname': _truncate(_hostname(), maxHostnameLength),
    'osVersion': _truncate(_osVersion(), maxOsVersionLength),
    'mode': wireMode(_modeState()),
    'unsyncedSales': _unsyncedSales(),
    'lastUpdateFailure': _lastUpdateFailure()?.toJson(),
  };

  /// Sends one heartbeat. Never throws.
  Future<void> beat() async {
    if (_disposed) return;
    try {
      if (!_hasSession()) return;
      _hadSession = true;
      await _api.post<void>(
        path,
        data: buildBody(),
        options: Options(
          // Nobody asked for this request: a failure must never pop the
          // offline prompt.
          extra: {ConnectivityInterceptor.backgroundKey: true},
        ),
      );
    } catch (_) {
      // Diagnostics only — an unreachable or older backend (404) is fine.
    }
  }

  static String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
