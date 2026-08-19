import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/printing/sale_receipt_printer.dart';
import 'package:cashier_app/core/utils/receipt_id.dart';
import 'package:cashier_app/features/pos_sale/domain/sale_receipt.dart';

void main() {
  test('receipt id matches the 8-character cashier app id', () {
    expect(formatReceiptId('35b4fb47-a84f-483f-b73c-44ff6a04be23'), '35b4fb47');
    expect(formatReceiptId('abc123'), 'abc123');
  });

  test('gate tickets alone do not produce a product receipt', () {
    final ticketOnly = SaleReceipt(
      id: 'sale-id',
      subtotalUzs: 25000,
      cashUzs: 25000,
      cardUzs: 0,
      createdAt: DateTime.utc(2026, 8, 19),
      items: const [
        SaleReceiptItem(
          productId: 'ticket',
          nameSnapshot: 'Kirish chiptasi - Standart',
          priceSnapshotUzs: 25000,
          qty: 1,
          lineTotalUzs: 25000,
        ),
      ],
    );
    expect(SaleReceiptPrinter.hasPrintableProducts(ticketOnly), isFalse);

    final withProduct = SaleReceipt(
      id: ticketOnly.id,
      subtotalUzs: 37000,
      cashUzs: 37000,
      cardUzs: 0,
      createdAt: ticketOnly.createdAt,
      items: [
        ...ticketOnly.items,
        const SaleReceiptItem(
          productId: 'popcorn',
          nameSnapshot: 'Popkorn',
          priceSnapshotUzs: 12000,
          qty: 1,
          lineTotalUzs: 12000,
        ),
      ],
    );
    expect(SaleReceiptPrinter.hasPrintableProducts(withProduct), isTrue);
  });

  test('buildPdf creates an 80mm receipt from checkout data', () async {
    final bytes = await SaleReceiptPrinter.buildPdf(
      SaleReceipt(
        id: '35b4fb47-a84f-483f-b73c-44ff6a04be23',
        subtotalUzs: 49000,
        cashUzs: 25000,
        cardUzs: 24000,
        createdAt: DateTime.utc(2026, 8, 19, 10, 30),
        items: const [
          SaleReceiptItem(
            productId: 'product-1',
            nameSnapshot: 'Popkorn',
            priceSnapshotUzs: 12000,
            qty: 2,
            lineTotalUzs: 24000,
          ),
          SaleReceiptItem(
            productId: 'product-2',
            nameSnapshot: 'Kirish chiptasi',
            priceSnapshotUzs: 25000,
            qty: 1,
            lineTotalUzs: 25000,
          ),
        ],
      ),
      branchName: 'Algoritm',
      cashierName: 'Shohjahon Abduvohidov',
    );

    expect(latin1.decode(bytes), startsWith('%PDF'));
    expect(bytes.length, greaterThan(1000));
  });
}
