import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cashier_app/core/lan_bridge/mdns_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an mDNS response for [name] with the given A records. The first
/// answer spells the name out; later ones point back at it (compression).
Uint8List _response(
  String name,
  List<List<int>> ips, {
  int id = 0,
  int aClass = 0x8001, // cache-flush + IN
  bool withQuestion = false,
  List<int> extraBefore = const [],
}) {
  final b = BytesBuilder();
  void u16(int v) => b.add([(v >> 8) & 0xff, v & 0xff]);
  u16(id);
  u16(0x8400); // QR + AA
  u16(withQuestion ? 1 : 0);
  u16(ips.length + (extraBefore.isEmpty ? 0 : 1));
  u16(0);
  u16(0);
  final nameAt = 12;
  for (final l in name.split('.')) {
    b.addByte(l.length);
    b.add(l.codeUnits);
  }
  b.addByte(0);
  var first = true;
  if (withQuestion) {
    u16(1);
    u16(1);
    first = false;
  }
  if (extraBefore.isNotEmpty) {
    // An AAAA record for the same name, which must be ignored.
    if (!first) b.add([0xc0, nameAt]);
    u16(28);
    u16(0x8001);
    b.add([0, 0, 0, 120]);
    u16(extraBefore.length);
    b.add(extraBefore);
    first = false;
  }
  for (final ip in ips) {
    if (!first) b.add([0xc0, nameAt]);
    first = false;
    u16(1);
    u16(aClass);
    b.add([0, 0, 0, 120]);
    u16(4);
    b.add(ip);
  }
  return b.toBytes();
}

void main() {
  group('isMdnsName', () {
    test('.local names (any case, trailing dot) are mDNS names', () {
      expect(isMdnsName('pg-megaplanet-exit.local'), isTrue);
      expect(isMdnsName('PG-Megaplanet-Exit.LOCAL.'), isTrue);
      expect(isMdnsName('local'), isFalse);
      expect(isMdnsName('pi.lan'), isFalse);
      expect(isMdnsName('192.168.1.5'), isFalse);
    });
  });

  group('encodeMdnsQuery', () {
    test('one A/IN question with the given id', () {
      final q = encodeMdnsQuery('pi.local', 0x1234);
      expect(q.sublist(0, 12), [0x12, 0x34, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
      expect(q.sublist(12), [
        2, 0x70, 0x69, // pi
        5, 0x6c, 0x6f, 0x63, 0x61, 0x6c, // local
        0,
        0, 1, // A
        0, 1, // IN
      ]);
    });

    test('rejects a label longer than 63 bytes', () {
      expect(
        () => encodeMdnsQuery('${'a' * 64}.local', 1),
        throwsFormatException,
      );
    });
  });

  group('decodeMdnsAnswers', () {
    test('reads every A record for the name, compressed or not', () {
      final p = _response('pg-x.local', [
        [192, 168, 50, 7],
        [10, 0, 0, 9],
      ]);
      expect(decodeMdnsAnswers(p, 'pg-x.local').map((a) => a.address), [
        '192.168.50.7',
        '10.0.0.9',
      ]);
    });

    test('matches names case-insensitively and skips the question', () {
      final p = _response('PG-X.Local', [
        [192, 168, 1, 2],
      ], withQuestion: true);
      expect(decodeMdnsAnswers(p, 'pg-x.local.').single.address, '192.168.1.2');
    });

    test('ignores other names, AAAA records and queries', () {
      final other = _response('other.local', [
        [192, 168, 1, 3],
      ]);
      expect(decodeMdnsAnswers(other, 'pg-x.local'), isEmpty);

      final aaaa = _response('pg-x.local', [
        [192, 168, 1, 4],
      ], extraBefore: List.filled(16, 1));
      expect(
        decodeMdnsAnswers(aaaa, 'pg-x.local').single.address,
        '192.168.1.4',
      );

      final query = encodeMdnsQuery('pg-x.local', 7);
      expect(decodeMdnsAnswers(query, 'pg-x.local'), isEmpty);
    });

    test(
      'a truncated or looping packet yields what was read, never throws',
      () {
        final p = _response('pg-x.local', [
          [192, 168, 1, 5],
          [192, 168, 1, 6],
        ]);
        final cut = p.sublist(0, p.length - 3);
        expect(decodeMdnsAnswers(cut, 'pg-x.local').map((a) => a.address), [
          '192.168.1.5',
        ]);
        expect(decodeMdnsAnswers(Uint8List(5), 'pg-x.local'), isEmpty);

        // Header with one answer whose name is a pointer to itself.
        final loop = Uint8List.fromList([
          0, 0, 0x84, 0, 0, 0, 0, 1, 0, 0, 0, 0, //
          0xc0, 12, 0, 1, 0, 1, 0, 0, 0, 1, 0, 4, 1, 2, 3, 4,
        ]);
        expect(decodeMdnsAnswers(loop, 'pg-x.local'), isEmpty);
      },
    );
  });

  group('MdnsResolver over real UDP (loopback responder)', () {
    late RawDatagramSocket responder;
    final seen = <Uint8List>[];
    var answerAfter = 1; // reply to the n-th query received

    setUp(() async {
      seen.clear();
      answerAfter = 1;
      responder = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      responder.listen((e) {
        if (e != RawSocketEvent.read) return;
        final d = responder.receive();
        if (d == null) return;
        seen.add(d.data);
        if (seen.length < answerAfter) return; // drop: forces a resend
        final id = (d.data[0] << 8) | d.data[1];
        // Legacy unicast: answer goes straight back to the source port.
        responder.send(
          _response('pg-x.local', [
            [192, 168, 50, 53],
          ], id: id),
          d.address,
          d.port,
        );
      });
    });

    tearDown(() => responder.close());

    MdnsResolver resolver() => MdnsResolver(
      target: InternetAddress.loopbackIPv4,
      port: responder.port,
      interfaces: () async => [InternetAddress.loopbackIPv4],
      wait: const Duration(milliseconds: 400),
      attempts: 3,
    );

    test('answer on the first query', () async {
      final r = await resolver().lookup('PG-X.local');
      expect(r.single.address, '192.168.50.53');
      expect(seen, hasLength(1));
      // The name goes out lower-cased (mDNS names are case-insensitive).
      expect(seen.single.sublist(12, 17), [4, 0x70, 0x67, 0x2d, 0x78]);
    });

    test('a lost query is resent', () async {
      answerAfter = 2;
      final r = await resolver().lookup('pg-x.local');
      expect(r.single.address, '192.168.50.53');
      expect(seen, hasLength(2));
    });

    test('no answer → SocketException after every attempt', () async {
      answerAfter = 99;
      final sw = Stopwatch()..start();
      await expectLater(
        resolver().lookup('pg-x.local'),
        throwsA(isA<SocketException>()),
      );
      expect(seen, hasLength(3));
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    });
  });

  group('lanBridgeLookup', () {
    final ip = InternetAddress('192.168.50.53');
    final sysIp = InternetAddress('192.168.14.47');

    test('non-.local names use the system resolver only', () async {
      var mdnsCalls = 0;
      final r = await lanBridgeLookup(
        'pi.lan',
        system: (_) async => [sysIp],
        mdns: (_) async {
          mdnsCalls++;
          return [ip];
        },
      );
      expect(r, [sysIp]);
      expect(mdnsCalls, 0);
    });

    test('.local: system fails (Windows) → mDNS answer wins', () async {
      final r = await lanBridgeLookup(
        'pg-x.local',
        system: (h) async => throw SocketException('Failed host lookup: $h'),
        mdns: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return [ip];
        },
      );
      expect(r, [ip]);
    });

    test('.local: whichever answers first wins', () async {
      final slow = Completer<List<InternetAddress>>();
      final r = await lanBridgeLookup(
        'pg-x.local',
        system: (_) async => [sysIp],
        mdns: (_) => slow.future,
      );
      expect(r, [sysIp]);
      slow.complete([ip]); // late answer is ignored
    });

    test('.local: an empty system answer does not hide the mDNS one', () async {
      final r = await lanBridgeLookup(
        'pg-x.local',
        system: (_) async => const [],
        mdns: (_) async => [ip],
      );
      expect(r, [ip]);
    });

    test('.local: both fail → the system error is rethrown', () async {
      await expectLater(
        lanBridgeLookup(
          'pg-x.local',
          system: (h) async => throw SocketException('sys: $h'),
          mdns: (h) async => throw SocketException('mdns: $h'),
        ),
        throwsA(
          isA<SocketException>().having((e) => e.message, 'm', contains('sys')),
        ),
      );
    });
  });
}
