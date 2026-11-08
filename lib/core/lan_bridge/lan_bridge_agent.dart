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

/// After a graceful controller CLOSE (our FIN sent), how long the agent keeps
/// reading — and discarding — until the peer ends too before destroying the
/// socket. Closing a socket with unread input makes the OS reset it, which
/// can cost the peer bytes it has not read yet.
const Duration lanBridgeCloseLinger = Duration(seconds: 30);

class _Stream {
  /// null while resolving / connecting.
  Socket? socket;
  StreamSubscription<Uint8List>? sub;
  int unflushed = 0;

  /// True while this stream holds one pause on the WebSocket subscription.
  bool blocked = false;

  /// The flush that holds [blocked], while it runs (never throws).
  Future<void>? flushing;

  /// Graceful close after a controller CLOSE(false): our FIN is sent
  /// ([writeDone]) and the peer has ended ([readDone]).
  bool writeDone = false;
  bool readDone = false;
  Timer? linger;
}

/// Lookup + dial ran past the OPEN's connect deadline.
const Object _expired = Object();

/// Relay agent on the cashier PC: serves the controller's OPEN by dialling
/// LAN-only addresses and pipes bytes as DATA / CLOSE frames over [socket].
/// Mirrors the backend reference `NodeAgent` frame for frame:
///
/// * INFO first: `{...info, agent: {kind: 'dart', version, host, ...info.agent}}`.
/// * OPEN: duplicate live id ignored; streams (resolving and connecting
///   included) ≥ [maxStreams] → `limit`. A literal IP is judged as is,
///   otherwise [AddressLookup] (a host over 253 chars → `resolve` without a
///   lookup); lookup error → `resolve`; empty or any non-LAN address →
///   `not-lan` (no dial); dial the FIRST address; then OPEN_OK(address).
///   Lookup + dial share ONE deadline of [connectTimeout] per OPEN: expiry
///   (a hung resolver included) or a timed-out dial → `timeout`; any other
///   dial error (a connector that throws synchronously included) → `refused`.
/// * DATA → `socket.add`; once ≥ [lanBridgeFlushAbove] bytes were handed to a
///   socket since its last flush, the WebSocket subscription is paused until
///   `socket.flush()` completes (or the stream is dropped).
/// * TCP data → DATA (≤ 64 KiB each); TCP done → CLOSE(false) (our side is
///   closed gracefully); TCP error → CLOSE(true); at most one CLOSE per stream.
/// * Controller CLOSE(error=false) → the stream is forgotten (no frames in
///   or out for it, no CLOSE reply), then bytes already handed to the socket
///   are flushed and our side is closed with a FIN (`socket.close()`, after
///   any flush in flight); the socket keeps being read — and the bytes
///   discarded — until the peer ends, at most [lanBridgeCloseLinger], then is
///   destroyed. A failed close destroys it at once. CLOSE(error=true) →
///   socket destroyed. During resolve/connect either one cancels the OPEN
///   silently. Unknown ids are ignored.
/// * Text message or undecodable frame → every socket (closing ones
///   included) destroyed, ws 1002. WebSocket done → [close].
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

  /// Streams forgotten by a graceful CLOSE whose socket is still closing.
  final Set<_Stream> _closing = {};
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
    for (final e in [..._closing]) {
      _release(e);
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
        if (e == null) break;
        if (frame.error || e.socket == null) {
          _drop(frame.streamId, e); // error, or still resolving / connecting
        } else {
          _closeGracefully(frame.streamId, e);
        }
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
    // One deadline for lookup + dial; the Timer is what fakeAsync drives,
    // the Stopwatch only sizes the connector's own timeout hint.
    final deadline = Completer<Object>();
    final timer = Timer(connectTimeout, () => deadline.complete(_expired));
    final watch = Stopwatch()..start();
    try {
      final resolved = await Future.any<Object>([
        _resolve(host),
        deadline.future,
      ]);
      if (!_live(id, entry)) return; // cancelled while resolving
      if (identical(resolved, _expired)) {
        return _fail(id, OpenFailReason.timeout);
      }
      if (resolved is OpenFailReason) return _fail(id, resolved);
      final address = resolved as InternetAddress;

      final remaining = connectTimeout - watch.elapsed;
      // Future.sync: a connector that throws synchronously is a failed dial.
      final dial = Future<Socket>.sync(
        () => _connect(
          address,
          port,
          timeout: remaining > Duration.zero ? remaining : Duration.zero,
        ),
      );
      final Object dialed;
      try {
        dialed = await Future.any<Object>([dial, deadline.future]);
      } catch (e) {
        if (_live(id, entry)) {
          _fail(
            id,
            _isTimeout(e) ? OpenFailReason.timeout : OpenFailReason.refused,
          );
        }
        return;
      }
      if (identical(dialed, _expired)) {
        // The dial may still land later: tear it down then.
        unawaited(dial.then((s) => s.destroy(), onError: (Object _) {}));
        if (_live(id, entry)) _fail(id, OpenFailReason.timeout);
        return;
      }
      final socket = dialed as Socket;
      if (!_live(id, entry)) {
        socket.destroy(); // cancelled while connecting
        return;
      }
      entry.socket = socket;
      _send(OpenOkFrame(id, address.address));
      _wire(id, entry, socket);
    } finally {
      timer.cancel();
    }
  }

  /// First address for [host], or the failure reason.
  Future<Object> _resolve(String host) async {
    final literal = InternetAddress.tryParse(host);
    final List<InternetAddress> addrs;
    if (literal != null) {
      addrs = [literal];
    } else if (host.length > 253) {
      return OpenFailReason.resolve; // longer than any DNS name: no lookup
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
        if (!_live(id, entry)) return; // closing after CLOSE: discarded
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
    if (!_live(id, entry)) {
      if (_closing.contains(entry)) {
        entry.readDone = true;
        if (error || entry.writeDone) _release(entry);
      }
      return;
    }
    final socket = entry.socket;
    _drop(id, entry, destroy: error);
    if (!error && socket != null) {
      // Peer ended: close our side after pending writes (no half-open).
      try {
        socket.close().then<void>((_) {}, onError: (Object _) {});
      } on StateError {
        socket.destroy(); // a flush is still in flight: cannot close
      }
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

  Future<void> _flush(_Stream entry, Socket socket) {
    entry.blocked = true;
    _sub?.pause();
    return entry.flushing = () async {
      try {
        await socket.flush();
      } catch (_) {
        // Reported through socket.done / the read side.
      }
      entry.unflushed = 0;
      entry.flushing = null;
      _unblock(entry);
    }();
  }

  void _unblock(_Stream entry) {
    if (!entry.blocked) return;
    entry.blocked = false;
    _sub?.resume();
  }

  /// Controller CLOSE(false): forget the stream now, then flush and FIN.
  void _closeGracefully(int id, _Stream entry) {
    _streams.remove(id);
    _unblock(entry); // other streams must not wait on this one
    _closing.add(entry);
    final socket = entry.socket!;
    unawaited(() async {
      try {
        final flushing = entry.flushing;
        if (flushing != null) await flushing; // close() throws while bound
        if (!_closing.contains(entry)) return;
        await socket.close();
      } catch (_) {
        _release(entry);
        return;
      }
      if (!_closing.contains(entry)) return;
      entry.writeDone = true;
      if (entry.readDone) {
        _release(entry);
      } else {
        entry.linger = Timer(lanBridgeCloseLinger, () => _release(entry));
      }
    }());
  }

  /// Ends a graceful close: the socket is destroyed (a no-op once both
  /// directions are closed).
  void _release(_Stream entry) {
    if (!_closing.remove(entry)) return;
    entry.linger?.cancel();
    entry.linger = null;
    unawaited(entry.sub?.cancel());
    entry.sub = null;
    entry.socket?.destroy();
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
