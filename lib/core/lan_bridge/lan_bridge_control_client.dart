import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'lan_bridge_agent.dart';
import 'lan_bridge_state.dart';

export 'lan_bridge_state.dart';

/// Opens a WebSocket to [url] with [headers] (the upgrade request's).
typedef WebSocketConnector =
    Future<WebSocket> Function(Uri url, Map<String, String> headers);

/// Builds a relay agent on an upgraded agent socket (injectable for tests).
typedef LanBridgeAgentFactory =
    LanBridgeAgent Function(WebSocket socket, Map<String, Object?> info);

const String lanBridgeControlPath = '/api/v1/pos/lan-bridge/control';

/// Long-lived control WebSocket telling the backend "this terminal is online";
/// spawns one [LanBridgeAgent] per `session.open`.
///
/// * Dials only while a terminal token exists and [isOnline] is true; re-checks
///   on [tokenChanges] / [onlineChanges]. Going offline closes the control
///   socket but lets a running agent finish on its own.
/// * After the upgrade: `pingInterval` 30 s, then a `hello` text frame.
/// * Retries: one timer at a time, [minBackoff] doubling up to [maxBackoff];
///   reset to [minBackoff] once a connection stayed open longer than
///   [stableAfter] (60 s).
/// * Upgrade refused with HTTP 401/403 → [forgetToken], `disabled`.
///   Any other status (503 kill switch …), a refusal with no status code
///   ([WebSocketException.httpStatusCode] null: a middlebox oddity, not a
///   verdict on the token) and network errors only back off; the token is
///   kept. A dial past [connectTimeout] is retried, and its socket closed if
///   the upgrade lands later.
/// * `terminal.revoked` → agent closed, [forgetToken], `disabled`.
///   While disabled nothing is dialled until [tokenChanges] brings a token
///   other than the rejected one.
/// * Tokens are never logged.
class LanBridgeControlClient {
  LanBridgeControlClient({
    required this._apiBaseUrl,
    required this._terminalToken,
    required this._tokenChanges,
    required this._forgetToken,
    required this._terminalId,
    required this._appVersion,
    required this._hostname,
    required this._isOnline,
    required this._onlineChanges,
    WebSocketConnector? connect,
    LanBridgeAgentFactory? agentFactory,
    void Function(String message)? log,
    this.minBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 60),
    this.stableAfter = const Duration(seconds: 60),
    this.connectTimeout = const Duration(seconds: 20),
  }) : _connect = connect ?? _defaultConnect,
       _agentFactory = agentFactory ?? _defaultAgent,
       _log = log ?? _noLog,
       _backoff = minBackoff;

  final String Function() _apiBaseUrl;
  final String? Function() _terminalToken;
  final Stream<void> _tokenChanges;
  final Future<void> Function() _forgetToken;
  final String Function() _terminalId;
  final String _appVersion;
  final String Function() _hostname;
  final bool Function() _isOnline;
  final Stream<void> _onlineChanges;
  final WebSocketConnector _connect;
  final LanBridgeAgentFactory _agentFactory;
  final void Function(String) _log;
  final Duration minBackoff;
  final Duration maxBackoff;
  final Duration stableAfter;
  final Duration connectTimeout;

  static Future<WebSocket> _defaultConnect(Uri u, Map<String, String> h) =>
      WebSocket.connect(u.toString(), headers: h);
  static LanBridgeAgent _defaultAgent(WebSocket s, Map<String, Object?> i) =>
      LanBridgeAgent(socket: s, info: i);
  static void _noLog(String _) {}

  final StreamController<LanBridgeState> _states =
      StreamController<LanBridgeState>.broadcast();
  LanBridgeState _state = const LanBridgeState();

  final List<StreamSubscription<void>> _subs = [];
  bool _started = false;
  bool _disposed = false;

  /// Bumped whenever the current control attempt/socket is abandoned, so late
  /// callbacks of an older one are ignored.
  int _gen = 0;
  bool _dialling = false;
  WebSocket? _control;
  StreamSubscription<dynamic>? _controlSub;
  Timer? _retry;
  Timer? _stable;
  bool _wasStable = false;
  Duration _backoff;

  String? _lastToken;
  bool _lastOnline = false;

  /// Token the server rejected; never dialled with again.
  String? _rejectedToken;

  LanBridgeAgent? _agent;
  String? _agentSession;

  Stream<LanBridgeState> get states => _states.stream;
  LanBridgeState get state => _state;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _lastToken = _terminalToken();
    _lastOnline = _isOnline();
    _subs
      ..add(_tokenChanges.listen((_) => _onTokenChange()))
      ..add(_onlineChanges.listen((_) => _onOnlineChange()));
    _evaluate();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _dropControl();
    final agent = _agent;
    _agent = null;
    _agentSession = null;
    if (agent != null) unawaited(agent.close());
    unawaited(_states.close());
  }

  // ---- state ---------------------------------------------------------------

  void _emit(LanBridgeState next) {
    if (next == _state) return;
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  void _setControl(ControlStatus s) => _emit(_state.copyWith(control: s));

  String? get _usableToken {
    final t = _terminalToken();
    if (t == null || t.isEmpty || t == _rejectedToken) return null;
    return t;
  }

  // ---- control socket ------------------------------------------------------

  void _onTokenChange() {
    if (_disposed) return;
    final t = _terminalToken();
    if (t == _lastToken) return; // repeated event for the same token
    _lastToken = t;
    if (t != null && t != _rejectedToken) {
      // A fresh token: forget an earlier rejection and dial without waiting.
      _rejectedToken = null;
      _backoff = minBackoff;
      _retry?.cancel();
      _retry = null;
    }
    // The live socket (or dial) uses another token → redial with this one.
    if (_control != null || _dialling) _dropControl();
    _evaluate();
  }

  void _onOnlineChange() {
    if (_disposed) return;
    final online = _isOnline();
    // The connectivity monitor repeats its verdict every tick; only
    // transitions matter (else each tick would cut the backoff short).
    if (online == _lastOnline) return;
    _lastOnline = online;
    if (!online) {
      _dropControl(); // a running agent finishes on its own
    } else {
      _retry?.cancel();
      _retry = null;
      _backoff = minBackoff;
    }
    _evaluate();
  }

  String? _controlToken;

  /// Dials when allowed and nothing is open, dialling or scheduled.
  void _evaluate() {
    if (_disposed || !_started) return;
    final token = _usableToken;
    if (token == null) {
      _dropControl();
      _setControl(ControlStatus.disabled);
      return;
    }
    if (!_isOnline()) {
      _setControl(ControlStatus.connecting);
      return;
    }
    if (_control != null) return;
    _setControl(ControlStatus.connecting);
    if (_dialling || _retry != null) return;
    unawaited(_dial(token));
  }

  Future<void> _dial(String token) async {
    final gen = ++_gen;
    _dialling = true;
    WebSocket ws;
    final dial = _connect(_wsUri(lanBridgeControlPath), {
      HttpHeaders.authorizationHeader: 'Bearer $token',
    });
    try {
      ws = await dial.timeout(connectTimeout);
    } catch (e) {
      if (e is TimeoutException) {
        // The upgrade may still succeed later: close that socket then.
        unawaited(
          dial.then<void>((ws) => ws.close(1000), onError: (Object _) {}),
        );
      }
      if (gen != _gen || _disposed) return;
      _dialling = false;
      _onDialError(e, token);
      return;
    }
    if (gen != _gen || _disposed) {
      unawaited(ws.close(1000));
      return;
    }
    _dialling = false;
    _control = ws;
    _controlToken = token;
    ws.pingInterval = const Duration(seconds: 30);
    _wasStable = false;
    _stable = Timer(stableAfter, () => _wasStable = true);
    _controlSub = ws.listen(
      (m) {
        if (gen == _gen) _onControlMessage(m);
      },
      onError: (Object _) {}, // done follows
      onDone: () {
        if (gen == _gen) _onControlDone();
      },
      cancelOnError: false,
    );
    ws.add(
      jsonEncode({
        'type': 'hello',
        'terminalId': _terminalId(),
        'appVersion': _appVersion,
        'hostname': _hostname(),
      }),
    );
    _setControl(ControlStatus.connected);
  }

  void _onDialError(Object e, String token) {
    if (e is WebSocketException) {
      final code = e.httpStatusCode;
      if (code == 401 || code == 403) {
        _log('lan-bridge: control upgrade refused ($code), token dropped');
        _rejectToken(token);
        return;
      }
      // Any other status, or none (a middlebox answering oddly), is not a
      // verdict on the token: back off and keep it.
      _log('lan-bridge: control upgrade refused (${code ?? 'no status'})');
    } else {
      _log('lan-bridge: control connect failed (${e.runtimeType})');
    }
    _scheduleRetry();
  }

  void _onControlDone() {
    final stable = _wasStable;
    _dropControl();
    if (stable) _backoff = minBackoff;
    if (_usableToken == null) {
      _evaluate();
      return;
    }
    _setControl(ControlStatus.connecting);
    if (_isOnline()) _scheduleRetry();
  }

  void _scheduleRetry() {
    _retry?.cancel();
    final wait = _backoff;
    final doubled = _backoff * 2;
    _backoff = doubled > maxBackoff ? maxBackoff : doubled;
    _retry = Timer(wait, () {
      _retry = null;
      _evaluate();
    });
  }

  /// Abandons the control socket, any dial in flight and the retry timer.
  void _dropControl() {
    _gen++;
    _dialling = false;
    _retry?.cancel();
    _retry = null;
    _stable?.cancel();
    _stable = null;
    final sub = _controlSub;
    final ws = _control;
    _controlSub = null;
    _control = null;
    _controlToken = null;
    if (sub != null) unawaited(sub.cancel());
    if (ws != null) unawaited(ws.close(1000).catchError((Object _) {}));
  }

  void _rejectToken(String? token) {
    _rejectedToken = token;
    _dropControl();
    _setControl(ControlStatus.disabled);
    unawaited(_forgetToken().catchError((Object _) {}));
  }

  // ---- messages / agent ----------------------------------------------------

  void _onControlMessage(dynamic raw) {
    if (raw is! String) return;
    Object? msg;
    try {
      msg = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (msg is! Map) return;
    switch (msg['type']) {
      case 'session.open':
        final id = msg['sessionId'];
        final agentToken = msg['agentToken'];
        final path = msg['wsPath'];
        if (id is! String || agentToken is! String || path is! String) return;
        if (!path.startsWith('/')) return;
        if (_agentSession != null) {
          _log('lan-bridge: session.open $id ignored, $_agentSession active');
          return;
        }
        unawaited(_startAgent(id, agentToken, path));
      case 'session.close':
        final id = msg['sessionId'];
        if (id is String && id == _agentSession) _endAgent();
      case 'terminal.revoked':
        _log('lan-bridge: terminal revoked');
        _endAgent();
        _rejectToken(_controlToken ?? _terminalToken());
    }
  }

  Future<void> _startAgent(String id, String agentToken, String path) async {
    _agentSession = id;
    _emit(_state.withSession(id, DateTime.now()));
    WebSocket ws;
    try {
      ws = await _connect(_wsUri(path), {
        HttpHeaders.authorizationHeader: 'Bearer $agentToken',
      }).timeout(connectTimeout);
    } catch (e) {
      _log('lan-bridge: agent connect for $id failed (${e.runtimeType})');
      if (_agentSession == id && _agent == null) _clearSession();
      return;
    }
    if (_disposed || _agentSession != id) {
      unawaited(ws.close(1000).catchError((Object _) {})); // closed meanwhile
      return;
    }
    final agent = _agentFactory(ws, {
      'agent': {'version': _appVersion, 'host': _hostname()},
    });
    _agent = agent;
    agent.start();
    unawaited(
      agent.done.whenComplete(() {
        if (identical(_agent, agent)) _clearSession();
      }),
    );
  }

  /// Closes the running agent (or cancels one still dialling).
  void _endAgent() {
    final agent = _agent;
    if (agent != null) {
      unawaited(agent.close()); // done → _clearSession
    } else if (_agentSession != null) {
      _clearSession();
    }
  }

  void _clearSession() {
    _agent = null;
    _agentSession = null;
    if (!_disposed) _emit(_state.withoutSession());
  }

  /// [apiBaseUrl]'s origin with ws/wss and [path] (path replaced, not appended).
  Uri _wsUri(String path) {
    final base = Uri.parse(_apiBaseUrl());
    return Uri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
    );
  }
}
