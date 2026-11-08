import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/printing/birthday_receipt.dart';
import 'package:cashier_app/core/printing/sale_receipt_printer.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';

BirthdayPartyPayment _pay({int cash = 0, int card = 0, int balance = 0}) =>
    BirthdayPartyPayment(
      id: 'p1',
      kind: BirthdayPaymentKind.payment,
      amountUzs: cash + card + balance,
      fromBalanceUzs: balance,
      cashUzs: cash,
      cardUzs: card,
      refundTo: null,
      cashierUsername: 'kassa',
      createdAt: DateTime.utc(2026, 11, 6, 10),
    );

BirthdayParty _party({int discount = 0, int refunded = 0}) => BirthdayParty(
  id: 'b1',
  status: BirthdayPartyStatus.booked,
  paymentState: BirthdayPaymentState.partial,
  branchId: 'br',
  branchName: 'Megaplanet',
  customerId: 1,
  customerName: 'Ali Valiyev',
  customerPhone: '+998900000000',
  planId: 'pl',
  planName: 'VIP',
  planColor: '#7C3AED',
  includedItems: const ['Tort', 'Animator'],
  childCount: 10,
  extraChildren: 2,
  packagePriceUzs: 1500000,
  extraChildUzs: 100000,
  listPriceUzs: 1700000,
  agreedPriceUzs: 1600000,
  discountUzs: discount,
  paidUzs: 400000,
  refundedUzs: refunded,
  debtUzs: 1200000,
  keptUzs: 0,
  maxCashRefundUzs: 0,
  partyDate: '2026-11-20',
  soldByUsername: 'kassa',
  createdAt: DateTime.utc(2026, 11, 6, 10),
  completedAt: null,
  cancelledAt: null,
  cancelReason: null,
  payments: const [],
  comments: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rows carry payment split, debt and no zero Karta row', () {
    final r = BirthdayReceipt.fromParty(_party(), payment: _pay(cash: 400000));
    expect(r.rows, contains(('Qoldi', '1 200 000')));
    expect(r.rows, contains(('Naqd', '400 000')));
    expect(r.rows.any((e) => e.$1 == 'Karta'), isFalse);
    expect(r.rows.any((e) => e.$1 == 'Chegirma'), isFalse);
    expect(r.rows, contains(('Bolalar', '10 + 2')));
    expect(r.rows, contains(('Bayram kuni', '20.11.2026')));
    expect(r.items, isEmpty);
  });

  test('discount row and items only when asked', () {
    final r = BirthdayReceipt.fromParty(
      _party(discount: 40000),
      payment: _pay(cash: 400000),
      withItems: true,
    );
    expect(r.rows, contains(('Chegirma', '40 000')));
    expect(r.items, ['Tort', 'Animator']);
  });

  test('refund shows Qaytarilgan and net paid total', () {
    final r = BirthdayReceipt.fromParty(_party(refunded: 100000));
    expect(r.rows, contains(('Qaytarilgan', '100 000')));
    expect(r.summary.first, ("Jami to'langan", '300 000'));
    expect(
      r.rows.indexWhere((e) => e.$1 == 'Qaytarilgan'),
      lessThan(r.rows.indexWhere((e) => e.$1 == "Jami to'langan")),
    );
  });

  test(
    'a split refund prints one row per destination under a refund title',
    () {
      BirthdayPartyPayment refund(String to, int amount) =>
          BirthdayPartyPayment(
            id: 'r-$to',
            kind: BirthdayPaymentKind.refund,
            amountUzs: amount,
            fromBalanceUzs: 0,
            cashUzs: 0,
            cardUzs: 0,
            refundTo: to,
            cashierUsername: 'kassa',
            createdAt: DateTime.utc(2026, 11, 7, 9),
          );
      final r = BirthdayReceipt.fromParty(
        _party(refunded: 300000),
        refunds: [refund('balance', 200000), refund('cash', 100000)],
      );
      expect(r.title, "Tug'ilgan kun - qaytarish");
      expect(r.rows, contains(('Balansga', '200 000')));
      expect(r.rows, contains(('Naqd', '100 000')));
      expect(r.rows.any((e) => e.$1 == 'Karta'), isFalse);
      expect(r.createdAt, DateTime.utc(2026, 11, 7, 9));
      // A normal payment receipt keeps the plain title.
      expect(
        BirthdayReceipt.fromParty(_party(), payment: _pay(cash: 1)).title,
        "Tug'ilgan kun",
      );
    },
  );

  test('renders a pdf', () async {
    final out = await SaleReceiptPrinter.renderBirthday(
      BirthdayReceipt.fromParty(
        _party(),
        payment: _pay(cash: 1),
        withItems: true,
      ),
      branchName: 'Megaplanet',
      cashierName: 'kassa',
    );
    expect(out.bytes, isNotEmpty);
    expect(out.heightMm, greaterThan(50));
  });
}
