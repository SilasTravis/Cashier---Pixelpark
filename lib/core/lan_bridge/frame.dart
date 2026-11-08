import 'dart:convert';
import 'dart:typed_data';

/// Binary frame codec shared by every leg of the LAN bridge.
/// Header: u8 type + u32 streamId (big-endian), then a type-specific payload.
/// Mirrors backend `lan-bridge/domain/frame.ts` byte for byte.
enum FrameType {
  open(1),
  openOk(2),
  openFail(3),
  data(4),
  close(5),
  info(6);

  const FrameType(this.wire);
  final int wire;

  static FrameType? fromWire(int v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return null;
  }
}

enum OpenFailReason {
  refused('refused'),
  timeout('timeout'),
  notLan('not-lan'),
  resolve('resolve'),
  limit('limit');

  const OpenFailReason(this.wire);
  final String wire;

  static OpenFailReason? fromWire(String v) {
    for (final r in values) {
      if (r.wire == v) return r;
    }
    return null;
  }
}

enum FrameErrorCode { short, badType, badPort, badJson, badReason }

class FrameError implements Exception {
  const FrameError(this.code, this.message);
  final FrameErrorCode code;
  final String message;

  @override
  String toString() => 'FrameError(${code.name}): $message';
}

sealed class Frame {
  const Frame();
  int get streamId;
}

final class OpenFrame extends Frame {
  const OpenFrame(this.streamId, this.host, this.port);
  @override
  final int streamId;
  final String host;
  final int port;
}

final class OpenOkFrame extends Frame {
  const OpenOkFrame(this.streamId, this.resolvedIp);
  @override
  final int streamId;
  final String resolvedIp;
}

final class OpenFailFrame extends Frame {
  const OpenFailFrame(this.streamId, this.reason);
  @override
  final int streamId;
  final OpenFailReason reason;
}

final class DataFrame extends Frame {
  const DataFrame(this.streamId, this.data);
  @override
  final int streamId;
  final Uint8List data;
}

final class CloseFrame extends Frame {
  const CloseFrame(this.streamId, this.error);
  @override
  final int streamId;
  final bool error;
}

final class InfoFrame extends Frame {
  const InfoFrame(this.info);
  @override
  int get streamId => 0;
  final Map<String, Object?> info;
}

const int _headerLength = 5;

void _assertPort(int port) {
  if (port < 1 || port > 65535) {
    throw FrameError(FrameErrorCode.badPort, 'port out of range: $port');
  }
}

Uint8List encodeFrame(Frame f) {
  if (f.streamId < 0 || f.streamId > 0xFFFFFFFF) {
    throw ArgumentError.value(f.streamId, 'streamId', 'must fit in u32');
  }
  final Uint8List payload;
  final FrameType type;
  switch (f) {
    case OpenFrame():
      _assertPort(f.port);
      final host = utf8.encode(f.host);
      payload = Uint8List(2 + host.length)
        ..buffer.asByteData().setUint16(0, f.port, Endian.big)
        ..setRange(2, 2 + host.length, host);
      type = FrameType.open;
    case OpenOkFrame():
      payload = Uint8List.fromList(utf8.encode(f.resolvedIp));
      type = FrameType.openOk;
    case OpenFailFrame():
      payload = Uint8List.fromList(utf8.encode(f.reason.wire));
      type = FrameType.openFail;
    case DataFrame():
      payload = f.data;
      type = FrameType.data;
    case CloseFrame():
      payload = Uint8List.fromList([f.error ? 1 : 0]);
      type = FrameType.close;
    case InfoFrame():
      payload = Uint8List.fromList(utf8.encode(jsonEncode(f.info)));
      type = FrameType.info;
  }
  final out = Uint8List(_headerLength + payload.length);
  final bd = out.buffer.asByteData();
  bd.setUint8(0, type.wire);
  bd.setUint32(1, f.streamId, Endian.big);
  out.setRange(_headerLength, out.length, payload);
  return out;
}

Frame decodeFrame(Uint8List bytes) {
  if (bytes.length < _headerLength) {
    throw FrameError(FrameErrorCode.short, 'frame shorter than header');
  }
  final bd = ByteData.sublistView(bytes);
  final typeWire = bd.getUint8(0);
  final streamId = bd.getUint32(1, Endian.big);
  final payload = Uint8List.sublistView(bytes, _headerLength);

  switch (FrameType.fromWire(typeWire)) {
    case FrameType.open:
      if (payload.length < 2) {
        throw FrameError(FrameErrorCode.badPort, 'OPEN payload too short');
      }
      final port = ByteData.sublistView(payload).getUint16(0, Endian.big);
      _assertPort(port);
      return OpenFrame(
        streamId,
        utf8.decode(Uint8List.sublistView(payload, 2), allowMalformed: true),
        port,
      );
    case FrameType.openOk:
      return OpenOkFrame(streamId, utf8.decode(payload, allowMalformed: true));
    case FrameType.openFail:
      final text = utf8.decode(payload, allowMalformed: true);
      final reason = OpenFailReason.fromWire(text);
      if (reason == null) {
        throw FrameError(FrameErrorCode.badReason, 'unknown reason: $text');
      }
      return OpenFailFrame(streamId, reason);
    case FrameType.data:
      return DataFrame(streamId, Uint8List.fromList(payload));
    case FrameType.close:
      if (payload.isEmpty) {
        throw FrameError(FrameErrorCode.short, 'CLOSE payload empty');
      }
      return CloseFrame(streamId, (payload[0] & 1) == 1);
    case FrameType.info:
      final Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(payload, allowMalformed: true));
      } on FormatException {
        throw FrameError(FrameErrorCode.badJson, 'INFO is not valid JSON');
      }
      if (decoded is! Map<String, dynamic>) {
        throw FrameError(FrameErrorCode.badJson, 'INFO is not a JSON object');
      }
      return InfoFrame(Map<String, Object?>.from(decoded));
    case null:
      throw FrameError(FrameErrorCode.badType, 'unknown type: $typeWire');
  }
}
