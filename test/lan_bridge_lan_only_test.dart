import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_app/core/lan_bridge/lan_only.dart';

void main() {
  const rows = <String, bool>{
    '10.0.0.1': true,
    '172.31.255.255': true,
    '172.32.0.1': false,
    '172.15.255.255': false,
    '192.168.1.9': true,
    '100.64.0.1': true,
    '100.127.255.255': true,
    '100.128.0.1': false,
    '169.254.1.1': true,
    '8.8.8.8': false,
    '1.1.1.1': false,
    '127.0.0.1': true,
    '::1': true,
    'fe80::1': true,
    'fd00::1': true,
    'fec0::1': false,
    'fe00::1': false,
    '2001:db8::1': false,
    '::ffff:8.8.8.8': false,
    '::ffff:192.168.1.1': true,
  };
  rows.forEach((ip, expected) {
    test('isLanAddress($ip) == $expected', () {
      expect(isLanAddress(InternetAddress(ip)), expected);
    });
  });

  test('allLan empty is false', () {
    expect(allLan(const []), isFalse);
  });
  test('allLan mixed LAN is true', () {
    expect(
        allLan([InternetAddress('fe80::1'), InternetAddress('192.168.1.9')]),
        isTrue);
  });
  test('allLan with one public is false', () {
    expect(
        allLan([InternetAddress('192.168.1.9'), InternetAddress('8.8.8.8')]),
        isFalse);
  });
}
