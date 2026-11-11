import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'lan_only.dart';

/// mDNS (RFC 6762) group and port.
final InternetAddress mdnsGroup = InternetAddress('224.0.0.251');
const int mdnsPort = 5353;

String _norm(String host) {
  var h = host.toLowerCase();
  while (h.endsWith('.')) {
    h = h.substring(0, h.length - 1);
  }
  return h;
}

/// True for `*.local` names (any case, optional trailing dot).
bool isMdnsName(String host) {
  final h = _norm(host);
  return h.endsWith('.local') && h.length > '.local'.length;
}

/// One A/IN question for [name], DNS message id [id]. Sent from an ephemeral
/// port this is a "legacy unicast" query (RFC 6762 §6.7): responders answer
/// straight back to that port, which a host firewall lets through as the
/// reply to our own packet (no inbound 5353 rule needed).
Uint8List encodeMdnsQuery(String name, int id) {
  final b = BytesBuilder();
  b.add([(id >> 8) & 0xff, id & 0xff, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
  for (final label in _norm(name).split('.')) {
    final bytes = label.codeUnits;
    if (bytes.isEmpty || bytes.length > 63 || bytes.any((c) => c > 0x7f)) {
      throw FormatException('bad mDNS label "$label"');
    }
    b.addByte(bytes.length);
    b.add(bytes);
  }
  b.add([0, 0, 1, 0, 1]); // root, QTYPE A, QCLASS IN
  return b.toBytes();
}

/// Reads a (possibly compressed) name at [offset]; returns it and the offset
/// just past it in the record. Throws [RangeError] / [FormatException] on a
/// malformed packet.
(String, int) _readName(Uint8List p, int offset) {
  final labels = <String>[];
  var pos = offset;
  var end = -1;
  for (var jumps = 0; ; jumps++) {
    if (jumps > 32) throw const FormatException('mDNS name loop');
    final len = p[pos];
    if (len == 0) {
      if (end < 0) end = pos + 1;
      break;
    }
    if (len & 0xc0 == 0xc0) {
      if (end < 0) end = pos + 2;
      pos = ((len & 0x3f) << 8) | p[pos + 1];
      continue;
    }
    if (len & 0xc0 != 0) throw const FormatException('bad label type');
    labels.add(String.fromCharCodes(p.sublist(pos + 1, pos + 1 + len)));
    if (pos + 1 + len > p.length) throw RangeError('label past end');
    pos += 1 + len;
  }
  return (labels.join('.').toLowerCase(), end);
}

/// Every IPv4 address an mDNS response gives for [name] (answer, authority
/// and additional sections). Queries and malformed tails yield what was read
/// so far; never throws.
List<InternetAddress> decodeMdnsAnswers(Uint8List p, String name) {
  final want = _norm(name);
  final out = <InternetAddress>[];
  try {
    if (p.length < 12) return out;
    if (p[2] & 0x80 == 0) return out; // not a response
    int u16(int at) {
      if (at + 2 > p.length) throw RangeError('u16 past end');
      return (p[at] << 8) | p[at + 1];
    }

    final qd = u16(4);
    final rr = u16(6) + u16(8) + u16(10);
    var pos = 12;
    for (var i = 0; i < qd; i++) {
      pos = _readName(p, pos).$2 + 4;
    }
    for (var i = 0; i < rr; i++) {
      final (n, after) = _readName(p, pos);
      final type = u16(after);
      final cls = u16(after + 2) & 0x7fff; // drop the cache-flush bit
      final len = u16(after + 8);
      final data = after + 10;
      if (data + len > p.length) break;
      if (type == 1 && cls == 1 && len == 4 && n == want) {
        out.add(InternetAddress.fromRawAddress(p.sublist(data, data + 4)));
      }
      pos = data + len;
    }
  } on Object {
    // Malformed: keep what was read.
  }
  return out;
}

/// The cashier PC's own private IPv4 addresses, one per interface.
Future<List<InternetAddress>> _lanInterfaces() async {
  try {
    final list = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    return [
      for (final i in list)
        for (final a in i.addresses)
          if (isLanAddress(a) && !a.isLoopback) a,
    ];
  } on Object {
    return const [];
  }
}

/// Resolves `*.local` names with our own mDNS query, for PCs whose system
/// resolver does not (Windows tills often fail `.local` lookups). The query
/// leaves through every private IPv4 interface and is resent [attempts]
/// times, [wait] apart; the first non-empty answer wins.
class MdnsResolver {
  MdnsResolver({
    InternetAddress? target,
    this.port = mdnsPort,
    Future<List<InternetAddress>> Function()? interfaces,
    this.wait = const Duration(milliseconds: 700),
    this.attempts = 3,
  }) : target = target ?? mdnsGroup,
       _interfaces = interfaces ?? _lanInterfaces;

  final InternetAddress target;
  final int port;
  final Duration wait;
  final int attempts;
  final Future<List<InternetAddress>> Function() _interfaces;

  Future<List<InternetAddress>> lookup(String host) async {
    final name = _norm(host);
    final id = Random().nextInt(0xffff) + 1;
    final query = encodeMdnsQuery(name, id);
    final found = Completer<List<InternetAddress>>();
    final sockets = <RawDatagramSocket>[];
    try {
      final ifaces = await _interfaces();
      // No interface found: one socket, the OS picks the route.
      for (final iface in ifaces.isEmpty ? <InternetAddress?>[null] : ifaces) {
        final RawDatagramSocket s;
        try {
          s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        } on SocketException {
          continue;
        }
        sockets.add(s);
        if (target.isMulticast) {
          try {
            s.multicastHops = 255;
            if (iface != null) {
              s.setRawOption(
                RawSocketOption(
                  RawSocketOption.levelIPv4,
                  RawSocketOption.IPv4MulticastInterface,
                  iface.rawAddress,
                ),
              );
            }
          } on Object {
            // Best effort: the default route still gets the query.
          }
        }
        s.listen((e) {
          if (e != RawSocketEvent.read) return;
          final d = s.receive();
          if (d == null || found.isCompleted) return;
          final addrs = decodeMdnsAnswers(d.data, name);
          if (addrs.isNotEmpty) found.complete(addrs);
        });
      }
      if (sockets.isEmpty) {
        throw SocketException('mDNS: no socket for $name');
      }
      for (var i = 0; i < attempts && !found.isCompleted; i++) {
        for (final s in sockets) {
          try {
            s.send(query, target, port);
          } on Object {
            // One interface failing must not stop the others.
          }
        }
        await Future.any([found.future, Future<void>.delayed(wait)]);
      }
      if (found.isCompleted) return await found.future;
      throw SocketException('mDNS: no answer for $name');
    } finally {
      for (final s in sockets) {
        s.close();
      }
    }
  }
}

final MdnsResolver _defaultMdns = MdnsResolver();

/// The relay agent's resolver. `*.local` names ask the system resolver and
/// mDNS at the same time and take the first non-empty answer (the system
/// error wins when both fail); every other name uses the system resolver.
Future<List<InternetAddress>> lanBridgeLookup(
  String host, {
  Future<List<InternetAddress>> Function(String host) system =
      InternetAddress.lookup,
  Future<List<InternetAddress>> Function(String host)? mdns,
}) {
  if (!isMdnsName(host)) return system(host);
  final viaMdns = mdns ?? _defaultMdns.lookup;
  final result = Completer<List<InternetAddress>>();
  Object? systemError;
  var pending = 2;

  void settle(List<InternetAddress>? addrs, Object? error, {bool sys = false}) {
    if (result.isCompleted) return;
    if (addrs != null && addrs.isNotEmpty) {
      result.complete(addrs);
      return;
    }
    if (sys) systemError = error ?? SocketException('no address for $host');
    if (--pending == 0) {
      result.completeError(
        systemError ?? error ?? SocketException('no address for $host'),
      );
    }
  }

  Future<void> run(
    Future<List<InternetAddress>> Function(String) f, {
    bool sys = false,
  }) async {
    try {
      settle(await f(host), null, sys: sys);
    } on Object catch (e) {
      settle(null, e, sys: sys);
    }
  }

  unawaited(run(system, sys: true));
  unawaited(run(viaMdns));
  return result.future;
}
