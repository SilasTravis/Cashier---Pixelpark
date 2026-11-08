import 'dart:io';

/// True when [a] is a private/LAN address. Mirrors the backend rule so a
/// cashier PC can never be used as an internet proxy. Pure byte checks, no DNS.
bool isLanAddress(InternetAddress a) {
  final b = a.rawAddress;
  if (b.length == 4) return _lanV4(b[0], b[1]);
  if (b.length != 16) return false;

  // IPv4-mapped (::ffff:a.b.c.d): judge the embedded IPv4.
  var zeros = true;
  for (var i = 0; i < 10; i++) {
    if (b[i] != 0) {
      zeros = false;
      break;
    }
  }
  if (zeros && b[10] == 0xff && b[11] == 0xff) return _lanV4(b[12], b[13]);

  // ::1 loopback.
  var loop = b[15] == 1;
  for (var i = 0; i < 15 && loop; i++) {
    if (b[i] != 0) loop = false;
  }
  if (loop) return true;

  // fe80::/10 link-local.
  if (b[0] == 0xfe && (b[1] & 0xc0) == 0x80) return true;
  // fc00::/7 unique local.
  if ((b[0] & 0xfe) == 0xfc) return true;
  return false;
}

bool _lanV4(int a, int b) {
  if (a == 10) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  if (a == 192 && b == 168) return true;
  if (a == 100 && b >= 64 && b <= 127) return true;
  if (a == 169 && b == 254) return true;
  if (a == 127) return true;
  return false;
}

/// False for an empty list; otherwise every address must be LAN.
bool allLan(Iterable<InternetAddress> addrs) =>
    addrs.isNotEmpty && addrs.every(isLanAddress);
