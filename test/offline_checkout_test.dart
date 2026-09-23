import 'dart:io';

import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/features/offline/application/offline_checkout.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/domain/offline_shift.dart';
import 'package:cashier_app/features/pos_sale/domain/cart_line.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _vip = Product(
  id: 'vip',
  name: 'VIP',
  priceUzs: 75000,
  category: 'Tariflar',
  icon: 'ph-crown',
  offlineOnly: true,
);

void main() {
  late Directory temp;
  late OfflineStore store;
  late LocalSource local;
  late OfflineCheckout checkout;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_offline_checkout');
    Hive.init(temp.path);
    store = OfflineStore(await Hive.openBox<dynamic>(OfflineStore.boxName));
    local = LocalSource(await Hive.openBox<dynamic>('app_test'))
      ..setCashier(
        id: 'cashier-1',
        fullName: 'Zaira',
        username: 'z',
        branchId: 'b',
        branchName: 'B',
      );
    checkout = OfflineCheckout(
      store,
      local,
      newId: () => '35b4fb47-a84f-483f-b73c-44ff6a04be23',
      clock: () => DateTime.utc(2026, 9, 23, 10, 15),
    );
  });

  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  Future<void> cacheOpenShift() => store.cacheShift(
    'cashier-1',
    Shift(
      id: 'shift-1',
      openedAt: DateTime.utc(2026, 9, 23, 8),
      closedAt: null,
      status: 'open',
      totals: ShiftTotals.zero,
    ),
  );

  test(
    'queues the sale under the cached server shift, at the grid price',
    () async {
      await cacheOpenShift();

      final sale = await checkout.record(
        lines: const [CartLine(product: _vip, qty: 2)],
        discount: null,
        cashUzs: 150000,
        cardUzs: 0,
      );

      expect(sale.shiftId, 'shift-1');
      expect(sale.lines.single.priceUzs, 75000);
      expect(sale.createdAt, DateTime.utc(2026, 9, 23, 10, 15));
      expect(store.sales().single, sale);
    },
  );

  test('uses the offline shift when there is no server shift', () async {
    await store.saveOfflineShift(
      OfflineShift(
        offlineRequestId: 'off-1',
        cashierId: 'cashier-1',
        openedAt: DateTime.utc(2026, 9, 23, 8),
      ),
    );

    final sale = await checkout.record(
      lines: const [CartLine(product: _vip, qty: 1)],
      discount: null,
      cashUzs: 75000,
      cardUzs: 0,
    );

    expect(sale.shiftId, isNull);
    expect(sale.shiftOfflineRequestId, 'off-1');
  });

  test('refuses without any shift, and when underpaid', () async {
    await expectLater(
      checkout.record(
        lines: const [CartLine(product: _vip, qty: 1)],
        discount: null,
        cashUzs: 75000,
        cardUzs: 0,
      ),
      throwsA(isA<NoShiftForOfflineSaleException>()),
    );

    await cacheOpenShift();
    await expectLater(
      checkout.record(
        lines: const [CartLine(product: _vip, qty: 1)],
        discount: null,
        cashUzs: 70000,
        cardUzs: 0,
      ),
      throwsA(isA<OfflinePaymentShortException>()),
    );
    expect(store.sales(), isEmpty);
  });
}
