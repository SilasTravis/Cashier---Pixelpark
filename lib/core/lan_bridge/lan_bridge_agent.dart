import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'frame.dart';
import 'lan_only.dart';

/// Dials [address]:[port]; must fail with [SocketException] (or
/// [TimeoutException]) when the connection cannot be made within [timeout].
typedef SocketConnector =
    Future<Socket> Function(
      InternetAddress address,
      int port, {
      Duration timeout,
    });

/// Resolves [host] to every address it has (like `dns.lookup(all: true)`).
typedef AddressLookup = Future<List<InternetAddress>> Function(String host);

/// Version of this agent's wire behaviour, reported in INFO `agent.version`
/// unless the caller's `info['agent']['version']` (the app version) wins.
const String lanBridgeAgentVersion = '1.0.0';

/// DATA payloads sent to the controller are at most this long.
const int lanBridgeMaxChunk = 64 * 1024;

/// Bytes handed to one TCP socket since its last flush that make the agent
/// pause the WebSocket and wait for that flush.
const int lanBridgeFlushAbove = 1024 * 1024;

class _Stream {
  /// null while resolving / connecting.
  Socket? socket;
  StreamSubscription<Uint8List>? sub;
  int unflushed = 0;

  /// True while this stream holds one pause on the WebSocket subscription.
  bool blocked = false;
}

/// Relay agent on the cashier PC: serves the controller's OPEN by dialling
/// LAN-only addresses and pipes bytes as DATA / CLOSE frames over [socket].
/// Mirrors the backend reference `NodeAgent` frame for frame:
///
/// * INFO first: `{...info, agent: {kind: 'dart', version, host, ...info.agent}}`.
/// * OPEN: duplicate live id ignored; streams (resolving and connecting
///   included) ≥ [maxStreams] → `limit`. A literal IP is judged as is,
///   otherwise [AddressLookup]; lookup error → `resolve`; empty or any non-LAN
///   address → `not-lan` (no dial); dial the FIRST address; timeout →
///   `timeout`, any other dial error → `refused`; then OPEN_OK(address).
///   The lookup itself has NO timeout (as in NodeAgent): a hung resolver
///   holds one stream slot until the controller sends CLOSE.
/// * DATA → `socket.add`; once ≥ [lanBridgeFlushAbove] bytes were handed to a
///   socket since its last flush, the WebSocket subscription is paused until
///   `socket.flush()` completes (or the stream is dropped).
/// * TCP data → DATA (≤ 64 KiB each); TCP done → CLOSE(false) (our side is
///   closed gracefully); TCP error → CLOSE(true); at most one CLOSE per stream.
/// * Controller CLOSE → socket destroyed, no CLOSE reply; during
///   resolve/connect it cancels the OPEN silently. Unknown ids are ignored.
/// * Text message or undecodable frame → every socket destroyed, ws 1002.
///   WebSocket done → [close].
///
/// Known limitation: `dart:io` [WebSocket] exposes no `bufferedAmount`, so the
/// TCP → WebSocket direction has no drain signal and is not throttled.
class LanBridgeAgent {
  LanBridgeAgent({
    required WebSocket socket,
    required this._info,
    SocketConnector? connect,
    AddressLookup? lookup,
    this.maxStreams = 64,
    this.connectTimeout = const Duration(seconds: 5),
  }) : _ws = socket,
       _connect = connect ?? _defaultConnect,
       _lookup = lookup ?? InternetAddress.lookup;

  final WebSocket _ws;
  final Map<String, Object?> _info;
  final SocketConnector _connect;
  final AddressLookup _lookup;
  final int maxStreams;
  final Duration connectTimeout;

  final Map<int, _Stream> _streams = {};
  final Completer<void> _done = Completer<void>();
  StreamSubscription<dynamic>? _sub;
  bool _started = false;
  bool _closed = false;

  static Future<Socket> _defaultConnect(
    InternetAddress a,
    int p, {
    Duration timeout = const Duration(seconds: 5),
  }) => Socket.connect(a, p, timeout: timeout);

  /// Streams being opened or open.
  int get openStreams => _streams.length;

  /// Completes after [close] or when the WebSocket ends.
  Future<void> get done => _done.future;

  /// Sends INFO and starts serving the WebSocket. Call once.
  void start() {
    if (_started || _closed) return;
    _started = true;
    final extraAgent = _info['agent'];
    _send(
      InfoFrame({
        ..._info,
        'agent': {
          'kind': 'dart',
          'version': lanBridgeAgentVersion,
          'host': Platform.localHostname,
          if (extraAgent is Map) ...extraAgent.cast<String, Object?>(),
        },
      }),
    );
    _sub = _ws.listen(
      _onMessage,
      onError: (Object _) {}, // done follows
      onDone: () => unawaited(close()),
      cancelOnError: false,
    );
  }

  /// Destroys every TCP socket, then closes the WebSocket with 1000.
  Future<void> close() => _shutdown(1000);

  Future<void> _shutdown(int code) async {
    if (_closed) return _done.future;
    _closed = true;
    for (final e in [..._streams.entries]) {
      _drop(e.key, e.value);
    }
    final sub = _sub;
    _sub = null;
    unawaited(_ws.close(code).then<void>((_) {}, onError: (Object _) {}));
    await sub?.cancel();
    if (!_done.isCompleted) _done.complete();
  }

  void _onMessage(dynamic m) {
    if (_closed) return;
    final Frame frame;
    try {
      if (m is! List<int>) throw const FormatException('text frame');
      frame = decodeFrame(m is Uint8List ? m : Uint8List.fromList(m));
    } catch (_) {
      unawaited(_shutdown(1002));
      return;
    }
    switch (frame) {
      case OpenFrame():
        _onOpen(frame.streamId, frame.host, frame.port);
      case DataFrame():
        _onData(frame.streamId, frame.data);
      case CloseFrame():
        final e = _streams[frame.streamId];
        if (e != null) _drop(frame.streamId, e);
      default:
        break; // agent-bound INFO / OPEN_OK / OPEN_FAIL: nothing to do
    }
  }

  bool _live(int id, _Stream e) => !_closed && identical(_streams[id], e);

  void _onOpen(int id, String host, int port) {
    if (_streams.containsKey(id)) return; // duplicate id: ignored
    if (_streams.length >= maxStreams) {
      _send(OpenFailFrame(id, OpenFailReason.limit));
      return;
    }
    final entry = _Stream();
    _streams[id] = entry;
    unawaited(_open(id, entry, host, port));
  }

  Future<void> _open(int id, _Stream entry, String host, int port) async {
    final resolved = await _resolve(host);
    if (!_live(id, entry)) return; // cancelled while resolving
    if (resolved is OpenFailReason) return _fail(id, resolved);
    final address = resolved as InternetAddress;

    final dial = _connect(address, port, timeout: connectTimeout);
    final Socket socket;
    try {
      socket = await dial.timeout(connectTimeout);
    } on TimeoutException {
      // The dial may still land later: tear it down then.
      unawaited(dial.then((s) => s.destroy(), onError: (Object _) {}));
      if (_live(id, entry)) _fail(id, OpenFailReason.timeout);
      return;
    } catch (e) {
      if (_live(id, entry)) {
        _fail(
          id,
          _isTimeout(e) ? OpenFailReason.timeout : OpenFailReason.refused,
        );
      }
      return;
    }
    if (!_live(id, entry)) {
      socket.destroy(); // cancelled while connecting
      return;
    }
    entry.socket = socket;
    _send(OpenOkFrame(id, address.address));
    _wire(id, entry, socket);
  }

  /// First address for [host], or the failure reason.
  Future<Object> _resolve(String host) async {
    final literal = InternetAddress.tryParse(host);
    final List<InternetAddress> addrs;
    if (literal != null) {
      addrs = [literal];
    } else {
      try {
        addrs = await _lookup(host);
      } catch (_) {
        return OpenFailReason.resolve;
      }
    }
    if (!allLan(addrs)) return OpenFailReason.notLan; // also when empty
    return addrs.first;
  }

  static bool _isTimeout(Object e) =>
      e is SocketException &&
      ('${e.message} ${e.osError?.message ?? ''}').toLowerCase().contains(
        'timed out',
      );

  void _wire(int id, _Stream entry, Socket socket) {
    entry.sub = socket.listen(
      (data) {
        for (var i = 0; i < data.length; i += lanBridgeMaxChunk) {
          final end = i + lanBridgeMaxChunk < data.length
              ? i + lanBridgeMaxChunk
              : data.length;
          _send(DataFrame(id, Uint8List.sublistView(data, i, end)));
        }
      },
      onError: (Object _) => _finish(id, entry, error: true),
      onDone: () => _finish(id, entry, error: false),
      cancelOnError: true,
    );
    // Write errors surface only here.
    socket.done.then<void>(
      (_) {},
      onError: (Object _) => _finish(id, entry, error: true),
    );
  }

  /// The TCP side ended: forget the stream and tell the controller once.
  void _finish(int id, _Stream entry, {required bool error}) {
    if (!_live(id, entry)) return;
    final socket = entry.socket;
    _drop(id, entry, destroy: error);
    if (!error && socket != null) {
      // Peer ended: close our side after pending writes (no half-open).
      socket.close().then<void>((_) {}, onError: (Object _) {});
    }
    _send(CloseFrame(id, error));
  }

  void _onData(int id, Uint8List data) {
    final entry = _streams[id];
    final socket = entry?.socket;
    if (entry == null || socket == null) return; // unknown / not connected
    try {
      socket.add(data);
    } catch (_) {
      _finish(id, entry, error: true);
      return;
    }
    entry.unflushed += data.length;
    if (entry.unflushed >= lanBridgeFlushAbove && !entry.blocked) {
      unawaited(_flush(entry, socket));
    }
  }

  Future<void> _flush(_Stream entry, Socket socket) async {
    entry.blocked = true;
    _sub?.pause();
    try {
      await socket.flush();
    } catch (_) {
      // Reported through socket.done / the read side.
    }
    entry.unflushed = 0;
    _unblock(entry);
  }

  void _unblock(_Stream entry) {
    if (!entry.blocked) return;
    entry.blocked = false;
    _sub?.resume();
  }

  /// Forgets a stream; [destroy] tears its socket down (controller CLOSE).
  void _drop(int id, _Stream entry, {bool destroy = true}) {
    _streams.remove(id);
    unawaited(entry.sub?.cancel());
    entry.sub = null;
    if (destroy) entry.socket?.destroy();
    _unblock(entry);
  }

  void _fail(int id, OpenFailReason reason) {
    _streams.remove(id);
    _send(OpenFailFrame(id, reason));
  }

  void _send(Frame frame) {
    if (_closed) return;
    try {
      _ws.add(encodeFrame(frame));
    } catch (_) {
      // ws already closing: its done event tears everything down.
    }
  }
}
