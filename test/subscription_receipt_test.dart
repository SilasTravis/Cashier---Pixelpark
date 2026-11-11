import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/printing/sale_receipt_printer.dart';
import 'package:cashier_app/features/pos_account/domain/subscription.dart';
import 'package:cashier_app/features/pos_sale/domain/sale_receipt.dart';

final _cashback = SaleCashback(
  code: 'ABCD2345EFGH',
  qrPayload: 'PXCB:ABCD2345EFGH',
  amountUzs: 4950,
  percent: 3,
  expiresAt: DateTime(2026, 10, 25, 15, 42),
);

/// Mockup 1: VIP 5 kirish, today's entry taken, balance + cash + card.
final _vipWithCashback = SubscriptionReceipt(
  id: '73291045-aaaa-bbbb',
  createdAt: DateTime(2026, 10, 18, 15, 42),
  planName: 'VIP - 5 kirish',
  priceUzs: 350000,
  childName: 'Samira',
  entriesTotal: 5,
  entriesLeft: 4,
  limitKind: SubscriptionLimitKind.perDay,
  usedToday: true,
  activatedAt: DateTime(2026, 10, 18),
  // Exclusive end: valid through 16.11.2026.
  expiresAt: DateTime(2026, 11, 17),
  validityDays: 30,
  balanceUzs: 185000,
  cashUzs: 100000,
  cardUzs: 65000,
  cashback: _cashback,
);

/// Mockup 2: 1 soat 8 kirish, not used today, paid fully from balance.
final _hourFromBalance = SubscriptionReceipt(
  id: '73291102-cccc',
  createdAt: DateTime(2026, 10, 18, 16, 5),
  planName: '1 soat - 8 kirish',
  priceUzs: 440000,
  childName: 'Doniyor',
  entriesTotal: 8,
  entriesLeft: 8,
  limitKind: SubscriptionLimitKind.perWeek,
  limitCount: 2,
  validityDays: 30,
  balanceUzs: 440000,
);

void main() {
  group('subscription receipt texts', () {
    test('entries mention today\'s entry only when it was taken', () {
      expect(
        SaleReceiptPrinter.subscriptionEntriesText(_vipWithCashback),
        '5 ta (bugun 1)',
      );
      expect(
        SaleReceiptPrinter.subscriptionEntriesText(_hourFromBalance),
        '8 ta',
      );
    });

    test('validity prints real dates once activated, else from 1st entry', () {
      expect(
        SaleReceiptPrinter.subscriptionValidityText(_vipWithCashback),
        '18.10 - 16.11.2026',
      );
      expect(
        SaleReceiptPrinter.subscriptionValidityText(_hourFromBalance),
        '1-kirishdan 30 kun',
      );
    });

    test('limit and rules lines', () {
      expect(
        SaleReceiptPrinter.subscriptionLimitText(_hourFromBalance),
        'haftasiga 2',
      );
      expect(
        SaleReceiptPrinter.subscriptionLimitText(_vipWithCashback),
        'kuniga 1',
      );
      final rules = SaleReceiptPrinter.subscriptionRulesText(_vipWithCashback);
      expect(rules, startsWith('Faqat Samira uchun'));
      expect(rules, contains('kuyadi'));
      expect(rules, contains('Pul qaytarilmaydi'));
    });
  });

  group('subscription receipt layout', () {
    test('cashback block adds room for the QR', () {
      final plain = SaleReceiptPrinter.subscriptionReceiptHeightMm(
        _hourFromBalance,
      );
      final withQr = SaleReceiptPrinter.subscriptionReceiptHeightMm(
        _vipWithCashback,
      );
      expect(withQr, greaterThan(plain + 40));
      // Each extra payment line gets its own room.
      expect(withQr - plain, greaterThan(50));
    });

    test('buildSubscriptionPdf renders with and without cashback', () async {
      final withQr = await SaleReceiptPrinter.buildSubscriptionPdf(
        _vipWithCashback,
        branchName: 'Chilonzor Atlas',
        cashierName: 'Barno',
      );
      final plain = await SaleReceiptPrinter.buildSubscriptionPdf(
        _hourFromBalance,
        branchName: 'Chilonzor Atlas',
        cashierName: 'Barno',
      );
      expect(latin1.decode(withQr), startsWith('%PDF'));
      expect(latin1.decode(plain), startsWith('%PDF'));
      // The QR image makes the cashback receipt clearly bigger.
      expect(withQr.length, greaterThan(plain.length));

      // Opt-in preview for humans: SUBSCRIPTION_RECEIPT_PDF_DIR=/tmp/out
      final dir = Platform.environment['SUBSCRIPTION_RECEIPT_PDF_DIR'];
      if (dir != null) {
        File('$dir/obuna_keshbek.pdf').writeAsBytesSync(withQr);
        File('$dir/obuna_balans.pdf').writeAsBytesSync(plain);
      }
    });
  });
}
