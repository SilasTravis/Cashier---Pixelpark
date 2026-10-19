import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/printing/sale_receipt_printer.dart';
import 'package:cashier_app/features/pos_sale/domain/sale_receipt.dart';

Map<String, dynamic> _saleJson({Object? cashback, bool withKey = true}) => {
  'id': '35b4fb47-a84f-483f-b73c-44ff6a04be23',
  'subtotalUzs': 100000,
  'cashUzs': 60000,
  'cardUzs': 40000,
  'createdAt': '2026-10-15T10:30:00.000Z',
  'items': [
    {
      'productId': 'popcorn',
      'nameSnapshot': 'Popkorn',
      'priceSnapshotUzs': 50000,
      'qty': 2,
      'lineTotalUzs': 100000,
    },
  ],
  if (withKey) 'cashback': cashback,
};

Map<String, dynamic> _cashbackJson({Object? amountUzs = 3000}) => {
  'code': 'ABCD2345EFGH',
  'qrPayload': 'PXCB:ABCD2345EFGH',
  'amountUzs': amountUzs,
  'percent': 3,
  'expiresAt': '2026-10-22T10:30:00.000Z',
};

void main() {
  // The receipt fonts and mascot come from the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SaleReceipt.fromJson cashback', () {
    test('parses a full cashback block (amount as number)', () {
      final receipt = SaleReceipt.fromJson(
        _saleJson(cashback: _cashbackJson()),
      );
      expect(
        receipt.cashback,
        SaleCashback(
          code: 'ABCD2345EFGH',
          qrPayload: 'PXCB:ABCD2345EFGH',
          amountUzs: 3000,
          percent: 3,
          expiresAt: DateTime.utc(2026, 10, 22, 10, 30),
        ),
      );
    });

    test('accepts amountUzs as a numeric string', () {
      final receipt = SaleReceipt.fromJson(
        _saleJson(cashback: _cashbackJson(amountUzs: '3000')),
      );
      expect(receipt.cashback?.amountUzs, 3000);
    });

    test('accepts a fractional percent', () {
      final json = _cashbackJson()..['percent'] = 1.5;
      final receipt = SaleReceipt.fromJson(_saleJson(cashback: json));
      expect(receipt.cashback?.percent, 1.5);
    });

    test('null cashback -> null', () {
      expect(SaleReceipt.fromJson(_saleJson()).cashback, isNull);
    });

    test('absent cashback key -> null', () {
      expect(SaleReceipt.fromJson(_saleJson(withKey: false)).cashback, isNull);
    });

    test('a malformed block never breaks the sale, it just has no QR', () {
      for (final bad in <Object>[
        'oops',
        _cashbackJson(amountUzs: 'abc'),
        _cashbackJson(amountUzs: 0),
        _cashbackJson()..remove('code'),
        _cashbackJson()..['expiresAt'] = 'not-a-date',
      ]) {
        final receipt = SaleReceipt.fromJson(_saleJson(cashback: bad));
        expect(receipt.cashback, isNull, reason: '$bad');
        expect(receipt.subtotalUzs, 100000);
      }
    });
  });

  group('SaleReceiptPrinter cashback', () {
    final plain = SaleReceipt.fromJson(_saleJson());
    final withCashback = SaleReceipt.fromJson(
      _saleJson(cashback: _cashbackJson()),
    );

    Future<double> heightMm(SaleReceipt receipt) async =>
        (await SaleReceiptPrinter.render(
          receipt,
          branchName: 'Algoritm',
          cashierName: 'Zaira',
        )).heightMm;

    test(
      'the paper is cut to the measured layout, QR block included',
      () async {
        final plainMm = await heightMm(plain);
        final withQrMm = await heightMm(withCashback);
        // Both QRs with their quiet zones need well over 40 mm.
        expect(withQrMm, greaterThan(plainMm + 40));
        // Sanity bounds of a one-item 80 mm receipt.
        expect(plainMm, inInclusiveRange(100, 200));
      },
    );

    test('a long receipt is never capped and still fits the QR', () async {
      final manyItems = [
        for (var i = 0; i < 40; i++)
          SaleReceiptItem(
            productId: 'p$i',
            nameSnapshot: 'Mahsulot $i',
            priceSnapshotUzs: 1000,
            qty: 1,
            lineTotalUzs: 1000,
          ),
      ];
      final long = SaleReceipt(
        id: 'x',
        subtotalUzs: 40000,
        cashUzs: 40000,
        cardUzs: 0,
        createdAt: DateTime.utc(2026, 10, 15),
        items: manyItems,
      );
      final longWithCashback = SaleReceipt(
        id: long.id,
        subtotalUzs: long.subtotalUzs,
        cashUzs: long.cashUzs,
        cardUzs: 0,
        createdAt: long.createdAt,
        items: manyItems,
        cashback: withCashback.cashback,
      );
      final longMm = await heightMm(long);
      // 40 lines no longer get squeezed into a fixed 280 mm page.
      expect(longMm, greaterThan(280));
      expect(await heightMm(longWithCashback), greaterThan(longMm + 40));
    });

    test('expiry line carries the local date', () {
      final expiry = SaleReceiptPrinter.cashbackExpiryText(
        withCashback.cashback!,
      );
      expect(expiry, matches(RegExp(r'^\d\d\.10\.2026 gacha$')));
    });

    test('buildPdf renders a receipt with the cashback QR', () async {
      expect(SaleReceiptPrinter.hasPrintableProducts(withCashback), isTrue);
      final bytes = await SaleReceiptPrinter.buildPdf(
        withCashback,
        branchName: 'Algoritm',
        cashierName: 'Shohjahon Abduvohidov',
      );
      expect(latin1.decode(bytes), startsWith('%PDF'));
      final plainBytes = await SaleReceiptPrinter.buildPdf(
        plain,
        branchName: 'Algoritm',
        cashierName: 'Shohjahon Abduvohidov',
      );
      expect(bytes.length, greaterThan(plainBytes.length));

      // Opt-in preview for humans: CASHBACK_RECEIPT_PDF=/tmp/x.pdf
      final out = Platform.environment['CASHBACK_RECEIPT_PDF'];
      if (out != null) File(out).writeAsBytesSync(bytes);
    });
  });
}
