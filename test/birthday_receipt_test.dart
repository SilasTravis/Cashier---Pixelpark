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

BirthdayParty _party({int discount = 0}) => BirthdayParty(
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
  refundedUzs: 0,
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
