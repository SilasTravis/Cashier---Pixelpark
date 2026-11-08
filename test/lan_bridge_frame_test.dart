import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_app/core/lan_bridge/frame.dart';

Frame roundTrip(Frame f) => decodeFrame(encodeFrame(f));

FrameErrorCode? codeOf(Uint8List bytes) {
  try {
    decodeFrame(bytes);
  } on FrameError catch (e) {
    return e.code;
  }
  return null;
}

void main() {
  test('OPEN round-trips', () {
    final f =
        roundTrip(const OpenFrame(7, 'pg-megaplanet-exit.local', 22))
            as OpenFrame;
    expect(f.streamId, 7);
    expect(f.host, 'pg-megaplanet-exit.local');
    expect(f.port, 22);
  });

  test('CLOSE header bytes and round-trip', () {
    final bytes = encodeFrame(const CloseFrame(0x01020304, true));
    expect(bytes.sublist(0, 5), [5, 1, 2, 3, 4]);
    final f = decodeFrame(bytes) as CloseFrame;
    expect(f.streamId, 0x01020304);
    expect(f.error, isTrue);
    expect(
      (roundTrip(const CloseFrame(1, false)) as CloseFrame).error,
      isFalse,
    );
  });

  test('streamId 0xFFFFFFFF is read unsigned', () {
    final f = roundTrip(const CloseFrame(0xFFFFFFFF, false));
    expect(f.streamId, 0xFFFFFFFF);
  });

  test('DATA round-trips and is copied', () {
    final f =
        roundTrip(DataFrame(3, Uint8List.fromList([1, 2, 3, 255])))
            as DataFrame;
    expect(f.data, [1, 2, 3, 255]);
    final buf = Uint8List.fromList([4, 0, 0, 0, 1, 9, 9]);
    final d = decodeFrame(buf) as DataFrame;
    buf[5] = 0;
    expect(d.data, [9, 9]);
  });

  test('OPEN_OK / OPEN_FAIL / INFO round-trip', () {
    expect(
      (roundTrip(const OpenOkFrame(1, '192.168.1.5')) as OpenOkFrame)
          .resolvedIp,
      '192.168.1.5',
    );
    for (final r in OpenFailReason.values) {
      expect((roundTrip(OpenFailFrame(2, r)) as OpenFailFrame).reason, r);
    }
    expect(
      utf8.decode(
        encodeFrame(const OpenFailFrame(2, OpenFailReason.notLan)).sublist(5),
      ),
      'not-lan',
    );
    final i = roundTrip(const InfoFrame({'name': 'till', 'n': 2})) as InfoFrame;
    expect(i.streamId, 0);
    expect(i.info, {'name': 'till', 'n': 2});
  });

  test('decode errors', () {
    expect(codeOf(Uint8List(4)), FrameErrorCode.short);
    expect(codeOf(Uint8List.fromList([9, 0, 0, 0, 1])), FrameErrorCode.badType);
    expect(
      codeOf(Uint8List.fromList([1, 0, 0, 0, 1, 0])),
      FrameErrorCode.badPort,
    );
    expect(
      codeOf(Uint8List.fromList([1, 0, 0, 0, 1, 0, 0, 97])),
      FrameErrorCode.badPort,
    );
    expect(codeOf(Uint8List.fromList([5, 0, 0, 0, 1])), FrameErrorCode.short);
    expect(
      codeOf(Uint8List.fromList([3, 0, 0, 0, 1, ...utf8.encode('nope')])),
      FrameErrorCode.badReason,
    );
    expect(
      codeOf(Uint8List.fromList([6, 0, 0, 0, 0, ...utf8.encode('[1]')])),
      FrameErrorCode.badJson,
    );
    expect(
      codeOf(Uint8List.fromList([6, 0, 0, 0, 0, ...utf8.encode('{x')])),
      FrameErrorCode.badJson,
    );
  });

  test('encode rejects bad ports', () {
    for (final p in [0, 65536]) {
      expect(
        () => encodeFrame(OpenFrame(1, 'h', p)),
        throwsA(
          isA<FrameError>().having(
            (e) => e.code,
            'code',
            FrameErrorCode.badPort,
          ),
        ),
      );
    }
  });

  test('OPEN byte layout', () {
    expect(encodeFrame(const OpenFrame(1, 'h', 22)), [
      1,
      0,
      0,
      0,
      1,
      0,
      22,
      104,
    ]);
  });

  test('empty DATA round-trips', () {
    final f = roundTrip(DataFrame(5, Uint8List(0))) as DataFrame;
    expect(f.data, isEmpty);
    expect(f.streamId, 5);
  });

  test('encode rejects out-of-range streamId', () {
    for (final id in [-1, 0x100000000]) {
      expect(
        () => encodeFrame(CloseFrame(id, false)),
        throwsA(isA<ArgumentError>()),
      );
    }
  });

  test('INFO tolerates malformed UTF-8 in strings', () {
    final bytes = Uint8List.fromList([
      6,
      0,
      0,
      0,
      0,
      ...utf8.encode('{"a":"'),
      0xFF,
      ...utf8.encode('"}'),
    ]);
    final f = decodeFrame(bytes) as InfoFrame;
    expect(f.info['a'], '\uFFFD');
  });
}
