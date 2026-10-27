import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/features/pos_account/domain/pos_entry.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/plan_entry_printing.dart';

PosEntry _entry(int? price, {int? durationMinutes}) => PosEntry(
  childId: 'child-1',
  token: 'tok',
  expiresAt: null,
  priceUzs: price,
  durationMinutes: durationMinutes,
);

void main() {
  group('reprintTicketPriceUzs', () {
    test('a re-printed VIP ticket shows what the pass cost, not DAQIQABAY', () {
      expect(reprintTicketPriceUzs(_entry(150000), prepaidPlan: true), 150000);
    });

    test('a fully discounted VIP re-prints as free (0 → BEPUL)', () {
      expect(reprintTicketPriceUzs(_entry(0), prepaidPlan: true), 0);
    });

    test('a paid pass is prepaid even when its plan left the till list', () {
      expect(reprintTicketPriceUzs(_entry(75000), prepaidPlan: false), 75000);
    });

    test('a 1 soat pass is prepaid by its hour window', () {
      expect(
        reprintTicketPriceUzs(
          _entry(0, durationMinutes: 60),
          prepaidPlan: false,
        ),
        0,
      );
    });

    test('a Standard pass still prints DAQIQABAY (null)', () {
      expect(reprintTicketPriceUzs(_entry(0), prepaidPlan: false), isNull);
    });
  });
}
