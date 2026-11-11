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

  test('items print like product lines: package and extra children', () {
    final r = BirthdayReceipt.fromParty(_party(), payment: _pay(cash: 400000));
    expect(r.lines, const [
      BirthdayReceiptLine('VIP · 10 bola', 1, 1500000),
      BirthdayReceiptLine("Qo'shimcha bola", 2, 100000),
    ]);
    expect(r.lines.last.totalUzs, 200000);
    expect(r.totalUzs, 1600000);
    expect(r.title, isNull);
    expect(r.isRefund, isFalse);
  });

  test('this payment split, paid and left; no zero rows', () {
    final r = BirthdayReceipt.fromParty(
      _party(),
      payment: _pay(cash: 300000, balance: 100000),
    );
    expect(r.paymentRows, [('Naqd', 300000), ('Balans', 100000)]);
    expect(r.paymentRows.any((e) => e.$1 == 'Karta'), isFalse);
    expect(r.paidUzs, 400000);
    expect(r.debtUzs, 1200000);
    expect(r.partyDate, '20.11.2026');
    expect(r.parent, contains('Ali Valiyev'));
    expect(r.discountUzs, 0);
    expect(r.items, isEmpty);
  });

  test('discount and items only when asked', () {
    final r = BirthdayReceipt.fromParty(
      _party(discount: 40000),
      payment: _pay(cash: 400000),
      withItems: true,
    );
    expect(r.discountUzs, 40000);
    expect(r.items, ['Tort', 'Animator']);
  });

  test('a refunded party shows the net paid total', () {
    final r = BirthdayReceipt.fromParty(_party(refunded: 100000));
    expect(r.refundedUzs, 100000);
    expect(r.paidUzs, 300000);
    expect(r.paymentRows, isEmpty);
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
      expect(r.isRefund, isTrue);
      expect(r.paymentRows, [
        ('Qaytarildi: balansga', 200000),
        ('Qaytarildi: naqd', 100000),
      ]);
      expect(r.createdAt, DateTime.utc(2026, 11, 7, 9));
      expect(r.receiptId, 'r-cash');
      // A normal payment receipt has no title.
      expect(
        BirthdayReceipt.fromParty(_party(), payment: _pay(cash: 1)).title,
        isNull,
      );
    },
  );

  test('renders the sale and the refund receipt', () async {
    final receipt = BirthdayReceipt.fromParty(
      _party(discount: 40000),
      payment: _pay(cash: 1),
      withItems: true,
    );
    final out = await SaleReceiptPrinter.renderBirthday(
      receipt,
      branchName: 'Megaplanet',
      cashierName: 'kassa',
    );
    expect(out.bytes, isNotEmpty);
    expect(out.heightMm, greaterThan(50));
    final refund = await SaleReceiptPrinter.renderBirthday(
      BirthdayReceipt.fromParty(
        _party(refunded: 100000),
        payment: BirthdayPartyPayment(
          id: 'r1',
          kind: BirthdayPaymentKind.refund,
          amountUzs: 100000,
          fromBalanceUzs: 0,
          cashUzs: 0,
          cardUzs: 0,
          refundTo: 'cash',
          cashierUsername: 'kassa',
          createdAt: DateTime.utc(2026, 11, 7),
        ),
      ),
      branchName: 'Megaplanet',
      cashierName: 'kassa',
    );
    expect(refund.bytes, isNotEmpty);
  });
}
