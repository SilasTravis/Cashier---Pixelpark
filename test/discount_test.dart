import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/features/pos_sale/domain/discount.dart';

void main() {
  group('Discount.appliedDiscountUzs (preview only)', () {
    test('percent rounds half-up, matching the backend formula', () {
      const thirtyPercent = Discount(
        id: 'd1',
        name: 'Flayer 30%',
        kind: DiscountKind.percent,
        value: 30,
      );
      expect(thirtyPercent.appliedDiscountUzs(10000), 3000);

      const thirtyThreePercent = Discount(
        id: 'd2',
        name: 'Flayer 33%',
        kind: DiscountKind.percent,
        value: 33,
      );
      expect(thirtyThreePercent.appliedDiscountUzs(10000), 3300);
      // 33% of 1001 = 330.33 -> rounds to 330.
      expect(thirtyThreePercent.appliedDiscountUzs(1001), 330);

      const hundredPercent = Discount(
        id: 'd3',
        name: "Tug'ilgan kun 100%",
        kind: DiscountKind.percent,
        value: 100,
      );
      expect(hundredPercent.appliedDiscountUzs(15000), 15000);
    });

    test('fixed clamps to the gross so the sale never goes negative', () {
      const fixed = Discount(
        id: 'd4',
        name: "Flayer 20 000 so'm",
        kind: DiscountKind.fixed,
        value: 20000,
      );
      // Bigger than the sale — clamps to 100% off, not a negative total.
      expect(fixed.appliedDiscountUzs(15000), 15000);
      // Smaller than the sale — applies as-is.
      expect(fixed.appliedDiscountUzs(50000), 20000);
    });

    test('zero gross never discounts', () {
      const percent = Discount(
        id: 'd5',
        name: 'Flayer 50%',
        kind: DiscountKind.percent,
        value: 50,
      );
      const fixed = Discount(
        id: 'd6',
        name: "Flayer 10 000 so'm",
        kind: DiscountKind.fixed,
        value: 10000,
      );
      expect(percent.appliedDiscountUzs(0), 0);
      expect(fixed.appliedDiscountUzs(0), 0);
    });

    test('result always stays within 0..grossUzs', () {
      const percent = Discount(
        id: 'd7',
        name: 'Flayer 1%',
        kind: DiscountKind.percent,
        value: 1,
      );
      final discount = percent.appliedDiscountUzs(10);
      expect(discount, greaterThanOrEqualTo(0));
      expect(discount, lessThanOrEqualTo(10));
    });
  });

  group('Discount.fromJson / DiscountSnapshot.fromJson', () {
    test('parses percent and fixed kinds from the wire shape', () {
      final percent = Discount.fromJson(const {
        'id': 'd1',
        'name': 'Flayer 30%',
        'kind': 'percent',
        'value': 30,
        'active': true,
      });
      expect(percent.kind, DiscountKind.percent);
      expect(percent.value, 30);

      final fixed = Discount.fromJson(const {
        'id': 'd2',
        'name': "Flayer 20 000 so'm",
        'kind': 'fixed',
        'value': 20000,
        'active': true,
      });
      expect(fixed.kind, DiscountKind.fixed);
    });

    test('DiscountSnapshot.id is nullable', () {
      final snapshot = DiscountSnapshot.fromJson(const {
        'id': null,
        'name': "Tug'ilgan kun 100%",
        'kind': 'percent',
        'value': 100,
      });
      expect(snapshot.id, isNull);
      expect(snapshot.name, "Tug'ilgan kun 100%");
    });
  });
}
