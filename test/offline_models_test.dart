import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:cashier_app/features/offline/domain/offline_shift.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:flutter_test/flutter_test.dart';

const _flyer = Discount(
  id: 'disc-1',
  name: 'Flayer',
  kind: DiscountKind.percent,
  value: 10,
);

OfflineSale _sale({
  String? shiftId = 'shift-1',
  String? shiftOfflineRequestId,
  Discount? discount = _flyer,
}) => OfflineSale(
  offlineRequestId: '35b4fb47-a84f-483f-b73c-44ff6a04be23',
  cashierId: 'cashier-1',
  createdAt: DateTime.utc(2026, 9, 23, 10, 15),
  shiftId: shiftId,
  shiftOfflineRequestId: shiftOfflineRequestId,
  lines: const [
    OfflineSaleLine(productId: 'vip', name: 'VIP', priceUzs: 75000, qty: 2),
  ],
  discount: discount,
  cashUzs: 135000,
  cardUzs: 0,
);

void main() {
  group('OfflineSale', () {
    test('totals follow the same discount formula as the server', () {
      final sale = _sale();
      expect(sale.grossUzs, 150000);
      expect(sale.discountUzs, 15000);
      expect(sale.totalUzs, 135000);
    });

    test('survives a JSON round trip, including a failure', () {
      final failed = _sale().markFailed(
        code: 'PRODUCT_NOT_FOUND',
        message: 'Mahsulot topilmadi',
        at: DateTime.utc(2026, 9, 23, 12),
      );
      expect(OfflineSale.fromJson(failed.toJson()), failed);
      expect(failed.isFailed, isTrue);
      expect(failed.attempts, 1);
    });

    test('its support code is the receipt number printed on paper', () {
      expect(_sale().supportCode, '35b4fb47');
    });

    test('builds a printable offline receipt', () {
      final receipt = _sale().toReceipt();
      expect(receipt.isOffline, isTrue);
      expect(receipt.id, '35b4fb47-a84f-483f-b73c-44ff6a04be23');
      expect(receipt.grossUzs, 150000);
      expect(receipt.discountUzs, 15000);
      expect(receipt.subtotalUzs, 135000);
      expect(receipt.discount?.name, 'Flayer');
      expect(receipt.items.single.lineTotalUzs, 150000);
    });

    test('sync payload names the server shift and the printed prices', () {
      expect(_sale().toSyncJson(), {
        'offlineRequestId': '35b4fb47-a84f-483f-b73c-44ff6a04be23',
        'shiftId': 'shift-1',
        'createdAt': '2026-09-23T10:15:00.000Z',
        'lines': [
          {'productId': 'vip', 'qty': 2, 'priceSnapshotUzs': 75000},
        ],
        'discount': {'id': 'disc-1', 'kind': 'percent', 'value': 10},
        'cashUzs': 135000,
        'cardUzs': 0,
      });
    });

    test('sync payload points at an offline shift until it has a server id', () {
      final sale = _sale(shiftId: null, shiftOfflineRequestId: 'off-shift');
      expect(sale.toSyncJson()['shiftOfflineRequestId'], 'off-shift');
      expect(sale.toSyncJson().containsKey('shiftId'), isFalse);

      final resolved = sale.toSyncJson(serverShiftIdForOfflineShift: 'srv-9');
      expect(resolved['shiftId'], 'srv-9');
      expect(resolved.containsKey('shiftOfflineRequestId'), isFalse);
    });

    test('sync payload omits the discount when none was applied', () {
      expect(_sale(discount: null).toSyncJson().containsKey('discount'), isFalse);
    });
  });

  group('OfflineShift', () {
    final shift = OfflineShift(
      offlineRequestId: 'off-shift',
      cashierId: 'cashier-1',
      openedAt: DateTime.utc(2026, 9, 23, 8),
      openingCashUzs: 20000,
    );

    test('shows in the shell as an open shift with a non-server id', () {
      final local = shift.toShift();
      expect(local.id, 'offline:off-shift');
      expect(local.isOpen, isTrue);
    });

    test('round-trips and remembers its server id once synced', () {
      final synced = shift.withServerShiftId('srv-9');
      expect(OfflineShift.fromJson(synced.toJson()), synced);
      expect(synced.isSynced, isTrue);
      expect(shift.isSynced, isFalse);
      expect(shift.toSyncJson(), {
        'offlineRequestId': 'off-shift',
        'openedAt': '2026-09-23T08:00:00.000Z',
        'openingCashUzs': 20000,
      });
    });
  });

  group('cache JSON of existing models', () {
    test('Product keeps offlineOnly, defaulting to false for older backends', () {
      const vip = Product(
        id: 'vip',
        name: 'VIP',
        priceUzs: 75000,
        category: 'Tariflar',
        icon: 'ph-crown',
        offlineOnly: true,
      );
      expect(Product.fromJson(vip.toJson()), vip);
      final legacy = Map<String, dynamic>.from(vip.toJson())..remove('offlineOnly');
      expect(Product.fromJson(legacy).offlineOnly, isFalse);
    });

    test('Discount round-trips', () {
      expect(Discount.fromJson(_flyer.toJson()), _flyer);
    });

    test('Shift round-trips its identity (totals are not cached)', () {
      final shift = Shift(
        id: 'shift-1',
        openedAt: DateTime.utc(2026, 9, 23, 8),
        closedAt: null,
        status: 'open',
        totals: ShiftTotals.zero,
      );
      expect(Shift.fromCacheJson(shift.toCacheJson()), shift);
    });
  });
}
