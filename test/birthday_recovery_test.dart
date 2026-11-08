import 'package:cashier_app/features/birthday_parties/presentation/birthday_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/birthday_fixtures.dart';

const _money = (fromBalanceUzs: 0, cashUzs: 500000, cardUzs: 0);

void main() {
  final before = fixtureParty(
    paid: 500000,
    debt: 1740000,
    payments: [paymentJson(id: 'a', cash: 500000, requestId: 'old')],
  );

  group('paymentReflected', () {
    test('matches a new row by its requestId', () {
      final fresh = fixtureParty(
        payments: [
          paymentJson(id: 'a', cash: 500000, requestId: 'old'),
          paymentJson(id: 'b', cash: 500000, requestId: 'mine'),
        ],
      );
      expect(
        paymentReflected(before, fresh, _money, requestId: 'mine'),
        isTrue,
      );
    });

    test('an identical split under another requestId is not this payment', () {
      final fresh = fixtureParty(
        payments: [
          paymentJson(id: 'a', cash: 500000, requestId: 'old'),
          paymentJson(id: 'b', cash: 500000, requestId: 'someone-else'),
        ],
      );
      expect(
        paymentReflected(before, fresh, _money, requestId: 'mine'),
        isFalse,
      );
      // A stale "before" that lacks the old row changes nothing.
      expect(
        paymentReflected(
          fixtureParty(),
          fixtureParty(
            payments: [paymentJson(id: 'a', cash: 500000, requestId: 'old')],
          ),
          _money,
          requestId: 'mine',
        ),
        isFalse,
      );
    });

    test('rows without a requestId fall back to a new row with the split', () {
      final legacyBefore = fixtureParty(
        payments: [paymentJson(id: 'a', cash: 500000)],
      );
      final fresh = fixtureParty(
        payments: [
          paymentJson(id: 'a', cash: 500000),
          paymentJson(id: 'b', cash: 500000),
        ],
      );
      expect(
        paymentReflected(legacyBefore, fresh, _money, requestId: 'mine'),
        isTrue,
      );
      // The old row alone is not a new payment.
      expect(
        paymentReflected(legacyBefore, legacyBefore, _money, requestId: 'x'),
        isFalse,
      );
    });

    test('refund rows never count as the payment', () {
      final fresh = fixtureParty(
        payments: [
          paymentJson(
            id: 'r',
            kind: 'refund',
            cash: 500000,
            refundTo: 'cash',
            requestId: 'mine',
          ),
        ],
      );
      expect(
        paymentReflected(fixtureParty(), fresh, _money, requestId: 'mine'),
        isFalse,
      );
    });
  });
}
