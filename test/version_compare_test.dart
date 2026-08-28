import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/version_compare.dart';

void main() {
  test('detects a newer patch, minor and major version', () {
    expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
    expect(isNewerVersion('1.1.0', '1.0.9'), isTrue);
    expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
  });

  test('rejects equal and older versions', () {
    expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
    expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
    expect(isNewerVersion('1.9.9', '2.0.0'), isFalse);
  });

  test('ignores the pubspec +build suffix', () {
    expect(isNewerVersion('1.0.1+7', '1.0.0+99'), isTrue);
    expect(isNewerVersion('1.0.0+9', '1.0.0+1'), isFalse);
  });

  test('treats missing trailing parts as zero', () {
    expect(isNewerVersion('1.1', '1.0.9'), isTrue);
    expect(isNewerVersion('1.0', '1.0.0'), isFalse);
  });

  test('treats non-numeric parts as zero rather than throwing', () {
    expect(isNewerVersion('1.0.x', '1.0.0'), isFalse);
    expect(isNewerVersion('1.2.x', '1.0.0'), isTrue);
  });
}
