import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/printing/sale_receipt_printer.dart';
import 'package:cashier_app/features/pos_account/domain/pos_entry.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/plan_entry_printing.dart';
import 'package:cashier_app/features/pos_sale/domain/sale_receipt.dart';

final _cashback = SaleCashback(
  code: 'ABCD2345EFGH',
  qrPayload: 'PXCB:ABCD2345EFGH',
  amountUzs: 4500,
  percent: 3,
  expiresAt: DateTime.utc(2026, 10, 26),
);

PosEntry _entry(String childId, int? price, {bool upgrade = false}) => PosEntry(
  childId: childId,
  token: 'tok-$childId',
  expiresAt: null,
  priceUzs: price,
  upgrade: upgrade,
);

PosEntryResult _result({
  List<PosEntry> entries = const [],
  int companions = 0,
  SaleCashback? cashback,
  EntrySalePayment? sale = const EntrySalePayment(
    id: 'topup-sale-1',
    cashUzs: 100000,
    cardUzs: 50000,
  ),
}) => PosEntryResult(
  entries: entries,
  failures: const [],
  companionPasses: [
    for (var i = 0; i < companions; i++)
      CompanionPass(code: 'h$i', expiresAt: null),
  ],
  cashback: cashback,
  entrySale: sale,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const names = {'c1': 'Ali', 'c2': 'Vali'};
  final now = DateTime.utc(2026, 10, 19, 10);

  test('no cashback, no receipt — entries alone print nothing new', () {
    expect(
      entryCashbackReceipt(_result(entries: [_entry('c1', 75000)]), names),
      isNull,
    );
    expect(
      entryCashbackReceipt(
        _result(
          entries: [_entry('c1', 75000)],
          cashback: _cashback,
          sale: null,
        ),
        names,
      ),
      isNull,
    );
  });

  test('itemizes passes + HAMROH when the prices add up to the payment', () {
    final receipt = entryCashbackReceipt(
      _result(
        entries: [_entry('c1', 75000), _entry('c2', 60000)],
        companions: 1,
        cashback: _cashback,
      ),
      names,
      planName: 'VIP',
      companionPriceUzs: 15000,
      now: now,
    )!;
    expect(receipt.id, 'topup-sale-1');
    expect(receipt.items.map((i) => i.nameSnapshot), [
      'VIP - Ali',
      'VIP - Vali',
      'HAMROH',
    ]);
    expect(receipt.subtotalUzs, 150000);
    expect(receipt.cashUzs, 100000);
    expect(receipt.cardUzs, 50000);
    expect(receipt.cashback, _cashback);
  });

  test('falls back to one Kirish line when per-pass prices are unknown', () {
    // A Standard pass bills per exit — no fixed price at entry.
    final receipt = entryCashbackReceipt(
      _result(entries: [_entry('c1', null)], cashback: _cashback),
      names,
      planName: 'Standart',
      now: now,
    )!;
    expect(receipt.items, hasLength(1));
    expect(receipt.items.single.nameSnapshot, 'Kirish - Standart');
    expect(receipt.items.single.lineTotalUzs, 150000);
  });

  test('the entry receipt renders with its cashback QR', () async {
    final receipt = entryCashbackReceipt(
      _result(entries: [_entry('c1', 150000)], cashback: _cashback),
      names,
      planName: 'VIP',
      now: now,
    )!;
    expect(SaleReceiptPrinter.hasPrintableProducts(receipt), isTrue);
    final rendered = await SaleReceiptPrinter.render(
      receipt,
      branchName: 'Algoritm',
      cashierName: 'Zaira',
    );
    expect(rendered.heightMm, greaterThan(180));
  });

  test('entrySale parses defensively', () {
    expect(
      EntrySalePayment.tryFromJson({'id': 's', 'cashUzs': 1, 'cardUzs': 2}),
      const EntrySalePayment(id: 's', cashUzs: 1, cardUzs: 2),
    );
    expect(EntrySalePayment.tryFromJson(null), isNull);
    expect(EntrySalePayment.tryFromJson({'id': 's'}), isNull);
  });
}
