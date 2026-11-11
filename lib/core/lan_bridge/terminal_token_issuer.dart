import 'dart:async';

import 'package:dio/dio.dart';

import '../network/connectivity_interceptor.dart';

/// Mints this till's LAN-bridge terminal token (`POST
/// /v1/pos/lan-bridge/terminal-token`, cashier JWT) right after every
/// cashier login and hands it to [_saveToken]. The token is device config,
/// so the bridge's control socket can stay connected with nobody signed in.
///
/// Minting revokes the previous token server-side. Every failure is
/// swallowed and the stored token is never cleared: an old token keeps
/// working until the backend revokes it. Nothing is sent without a session.
class TerminalTokenIssuer {
  TerminalTokenIssuer({
    required this._api,
    required this._hasSession,
    required this._sessionChanges,
    required this._terminalId,
    required this._saveToken,
  });

  static const String path = '/v1/pos/lan-bridge/terminal-token';

  final Dio _api;
  final bool Function() _hasSession;
  final Stream<void> _sessionChanges;
  final String Function() _terminalId;
  final Future<void> Function(String?) _saveToken;

  StreamSubscription<void>? _subscription;
  bool _hadSession = false;
  bool _disposed = false;

  /// Issues now when signed in, then on every no-session → session
  /// transition. Idempotent.
  void start() {
    if (_disposed) return;
    _hadSession = _hasSession();
    _subscription ??= _sessionChanges.listen((_) => _onSession());
    if (_hadSession) unawaited(issueNow());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _onSession() {
    final hasSession = _hasSession();
    final signedIn = hasSession && !_hadSession;
    _hadSession = hasSession;
    if (signedIn) unawaited(issueNow());
  }

  /// Requests a fresh token and stores it. Never throws.
  Future<void> issueNow() async {
    if (_disposed) return;
    try {
      if (!_hasSession()) return;
      final response = await _api.post<Object?>(
        path,
        data: {'terminalId': _terminalId()},
        options: Options(extra: {ConnectivityInterceptor.backgroundKey: true}),
      );
      final body = response.data;
      final token = body is Map ? body['terminalToken'] : null;
      if (token is String && token.isNotEmpty) await _saveToken(token);
    } catch (_) {
      // The old token (if any) stays valid until revoked.
    }
  }
}
