import 'dart:io';

import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory temp;
  late Box<dynamic> box;
  late LocalSource local;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_parent_qr');
    Hive.init(temp.path);
    box = await Hive.openBox<dynamic>('cashier_app_box');
    local = LocalSource(box);
  });

  tearDown(() async {
    await box.close();
    await temp.delete(recursive: true);
  });

  test('"Ota-ona QR" is OFF until the cashier turns it on', () {
    expect(local.getPrintParentQr(), isFalse);
  });

  test('the last choice is remembered, both ways', () async {
    await local.setPrintParentQr(true);
    expect(local.getPrintParentQr(), isTrue);
    await local.setPrintParentQr(false);
    expect(local.getPrintParentQr(), isFalse);
  });

  test('a restart and a logout keep the choice', () async {
    await local.setPrintParentQr(true);
    await local.clearSession();
    await box.close();
    box = await Hive.openBox<dynamic>('cashier_app_box');
    expect(LocalSource(box).getPrintParentQr(), isTrue);
  });
}
