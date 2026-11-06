import 'dart:convert';
import 'dart:typed_data';

import 'package:cashier_app/core/printing/shift_report_printer.dart';
import 'package:cashier_app/features/shift/data/shift_remote_data_source.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [body] as JSON — no network involved.
class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _shiftJson(Map<String, dynamic> totals) => {
  'id': '11111111-2222-3333-4444-555555555555',
  'openedAt': '2026-10-14T05:00:00Z',
  'closedAt': null,
  'status': 'open',
  'totals': {
    'salesCount': 70,
    'subtotalUzs': 5000000,
    'cashUzs': 3000000,
    'cardUzs': 2000000,
    'topupUzs': 400000,
    'balanceSalesUzs': 100000,
    ...totals,
  },
};

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

  Shift shift({
    ShiftEntrySummary? entries,
    int birthdayUzs = 0,
    int birthdayRefundedUzs = 0,
  }) => Shift(
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
      birthdayUzs: birthdayUzs,
      birthdayRefundedUzs: birthdayRefundedUzs,
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

  test('birthday money survives the cache round trip', () {
    final totals = shift(birthdayUzs: 400000).totals;
    expect(ShiftTotals.fromCacheJson(totals.toCacheJson()).birthdayUzs, 400000);
  });

  test('older cache entries without birthdayUzs parse to 0', () {
    final json = shift().totals.toCacheJson()..remove('birthdayUzs');
    expect(ShiftTotals.fromCacheJson(json).birthdayUzs, 0);
  });

  test('server totals with birthdayUzs are read into the model', () async {
    final dio = Dio()
      ..httpClientAdapter = _JsonAdapter(_shiftJson({'birthdayUzs': 400000}));
    final current = await ShiftRemoteDataSourceImpl(dio).getCurrentShift();
    expect(current.totals.birthdayUzs, 400000);
  });

  test('an older backend without birthdayUzs reads as 0', () async {
    final dio = Dio()..httpClientAdapter = _JsonAdapter(_shiftJson({}));
    final current = await ShiftRemoteDataSourceImpl(dio).getCurrentShift();
    expect(current.totals.birthdayUzs, 0);
  });

  test('birthday refunds survive the cache round trip', () {
    final totals = shift(birthdayRefundedUzs: 250000).totals;
    expect(
      ShiftTotals.fromCacheJson(totals.toCacheJson()).birthdayRefundedUzs,
      250000,
    );
  });

  test('older cache entries without birthdayRefundedUzs parse to 0', () {
    final json = shift(birthdayRefundedUzs: 250000).totals.toCacheJson()
      ..remove('birthdayRefundedUzs');
    expect(ShiftTotals.fromCacheJson(json).birthdayRefundedUzs, 0);
  });

  test(
    'server totals with birthdayRefundedUzs are read; old ones read 0',
    () async {
      final dio = Dio()
        ..httpClientAdapter = _JsonAdapter(
          _shiftJson({'birthdayRefundedUzs': 250000}),
        );
      final current = await ShiftRemoteDataSourceImpl(dio).getCurrentShift();
      expect(current.totals.birthdayRefundedUzs, 250000);
      final old = Dio()..httpClientAdapter = _JsonAdapter(_shiftJson({}));
      expect(
        (await ShiftRemoteDataSourceImpl(
          old,
        ).getCurrentShift()).totals.birthdayRefundedUzs,
        0,
      );
    },
  );

  test('the check shows the birthday refund row only when there is one', () {
    final lines = ShiftReportPrinter.lines(
      shift(birthdayUzs: 400000, birthdayRefundedUzs: 250000),
    );
    expect(lines, contains(("Tug'ilgan kun qaytarildi", "-250 000 so'm")));
    expect(
      ShiftReportPrinter.lines(
        shift(birthdayUzs: 400000),
      ).any((l) => l.$1 == "Tug'ilgan kun qaytarildi"),
      isFalse,
    );
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

  test('the check shows birthday money as a line when there is some', () {
    final lines = ShiftReportPrinter.lines(shift(birthdayUzs: 400000));
    expect(lines, contains(("Shundan tug'ilgan kun", "400 000 so'm")));
  });

  test('the check has no birthday line without birthday money', () {
    final lines = ShiftReportPrinter.lines(shift());
    expect(lines.any((line) => line.$1.contains('tug\'ilgan kun')), isFalse);
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
