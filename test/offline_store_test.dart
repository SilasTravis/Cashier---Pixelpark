import 'dart:io';

import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:cashier_app/features/offline/domain/offline_shift.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

OfflineSale _sale(String id, {String cashierId = 'cashier-1', int minute = 0}) =>
    OfflineSale(
      offlineRequestId: id,
      cashierId: cashierId,
      createdAt: DateTime.utc(2026, 9, 23, 10, minute),
      shiftId: 'shift-1',
      lines: const [
        OfflineSaleLine(productId: 'vip', name: 'VIP', priceUzs: 75000, qty: 1),
      ],
      cashUzs: 75000,
      cardUzs: 0,
    );

void main() {
  late Directory temp;
  late Box<dynamic> box;
  late OfflineStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_offline_store');
    Hive.init(temp.path);
    box = await Hive.openBox<dynamic>(OfflineStore.boxName);
    store = OfflineStore(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('offline mode persists and defaults to online', () async {
    expect(store.isOfflineMode, isFalse);
    await store.setOfflineMode(true);
    expect(OfflineStore(box).isOfflineMode, isTrue);
  });

  test('queues sales oldest first, per cashier, and removes synced ones', () async {
    await store.putSale(_sale('b', minute: 5));
    await store.putSale(_sale('a', minute: 1));
    await store.putSale(_sale('c', cashierId: 'cashier-2'));

    expect(store.sales(cashierId: 'cashier-1').map((s) => s.offlineRequestId), ['a', 'b']);
    expect(store.sales().length, 3);

    await store.removeSales(['a', 'c']);
    expect(store.sales().map((s) => s.offlineRequestId), ['b']);
  });

  test('putSale replaces the same sale, e.g. when it is marked failed', () async {
    await store.putSale(_sale('a'));
    await store.putSale(
      _sale('a').markFailed(code: 'X', message: 'bad', at: DateTime.utc(2026)),
    );
    expect(store.sales().single.isFailed, isTrue);
  });

  test('keeps the offline shift and the cached server shift per cashier', () async {
    final offline = OfflineShift(
      offlineRequestId: 'off-1',
      cashierId: 'cashier-1',
      openedAt: DateTime.utc(2026, 9, 23, 8),
    );
    await store.saveOfflineShift(offline);
    expect(store.offlineShift('cashier-1'), offline);
    expect(store.offlineShift('cashier-2'), isNull);
    await store.clearOfflineShift('cashier-1');
    expect(store.offlineShift('cashier-1'), isNull);

    final shift = Shift(
      id: 'shift-1',
      openedAt: DateTime.utc(2026, 9, 23, 8),
      closedAt: null,
      status: 'open',
      totals: ShiftTotals.zero,
    );
    await store.cacheShift('cashier-1', shift);
    expect(store.cachedShift('cashier-1'), shift);
    await store.clearCachedShift('cashier-1');
    expect(store.cachedShift('cashier-1'), isNull);
  });

  test('caches the catalog per branch and the discount list', () async {
    const vip = Product(
      id: 'vip',
      name: 'VIP',
      priceUzs: 75000,
      category: 'Tariflar',
      icon: 'ph-crown',
      offlineOnly: true,
    );
    const flyer = Discount(id: 'd', name: 'Flayer', kind: DiscountKind.percent, value: 10);

    expect(store.cachedProducts('branch-1'), isNull);
    await store.cacheProducts('branch-1', const [vip]);
    await store.cacheDiscounts(const [flyer]);

    expect(store.cachedProducts('branch-1'), const [vip]);
    expect(store.cachedProducts('branch-2'), isNull);
    expect(store.cachedDiscounts(), const [flyer]);
  });

  test('notifies listeners on every write', () async {
    var notified = 0;
    store.addListener(() => notified++);
    await store.putSale(_sale('a'));
    await store.removeSales(['a']);
    await store.setOfflineMode(true);
    expect(notified, 3);
  });
}
