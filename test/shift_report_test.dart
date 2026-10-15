import 'package:cashier_app/core/printing/shift_report_printer.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const entries = ShiftEntrySummary(
    tariffs: [
      ShiftTariffLine(label: 'VIP', isVip: true, count: 38),
      ShiftTariffLine(label: '1 soat', isVip: false, count: 23),
    ],
    ticketsCount: 61,
    vipCount: 38,
    uniqueChildren: 60,
    enteredChildren: 59,
  );

  Shift shift({ShiftEntrySummary? entries}) => Shift(
    id: '11111111-2222-3333-4444-555555555555',
    openedAt: DateTime.utc(2026, 10, 14, 5),
    closedAt: DateTime.utc(2026, 10, 14, 17),
    status: 'closed',
    totals: ShiftTotals(
      salesCount: 70,
      subtotalUzs: 5000000,
      cashUzs: 3000000,
      cardUzs: 2000000,
      topupUzs: 400000,
      balanceSalesUzs: 100000,
      entries: entries,
    ),
  );

  test('entry summary survives the offline cache round trip', () {
    final totals = shift(entries: entries).totals;
    expect(ShiftTotals.fromCacheJson(totals.toCacheJson()), totals);
  });

  test('older cache entries without entries parse to null', () {
    final json = shift().totals.toCacheJson();
    expect(json.containsKey('entries'), isFalse);
    expect(ShiftTotals.fromCacheJson(json).entries, isNull);
  });

  test('the check lists each tariff, VIP and children', () {
    final lines = ShiftReportPrinter.lines(shift(entries: entries));
    expect(
      lines,
      containsAllInOrder([
        ('BILETLAR', null),
        ('VIP', '38 ta'),
        ('1 soat', '23 ta'),
        ('Jami biletlar', '61 ta'),
        ('Shundan VIP', '38 ta'),
        ('BOLALAR', null),
        ('Takrorlanmas bolalar', '60 ta'),
        ('Ichkariga kirgan', '59 ta'),
      ]),
    );
    expect(lines, contains(('Naqd', "3 000 000 so'm")));
  });

  test('without entries from the server the check keeps only money', () {
    final lines = ShiftReportPrinter.lines(shift());
    expect(lines.where((line) => line.$2 == null), isEmpty);
  });

  test('builds a pdf that grows with the tariffs', () async {
    final pdf = await ShiftReportPrinter.buildPdf(
      shift(entries: entries),
      branchName: 'Chilonzor',
      cashierName: 'Kassir',
    );
    expect(pdf, isNotEmpty);
    expect(
      ShiftReportPrinter.heightMm(shift(entries: entries)),
      greaterThan(ShiftReportPrinter.heightMm(shift())),
    );
  });
}
