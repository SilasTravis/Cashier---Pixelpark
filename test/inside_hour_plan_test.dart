import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/theme/app_theme.dart';
import 'package:cashier_app/features/inside/data/inside_repository.dart';
import 'package:cashier_app/features/inside/domain/inside_child.dart';
import 'package:cashier_app/features/inside/domain/inside_summary.dart';
import 'package:cashier_app/features/inside/presentation/bloc/inside_cubit.dart';
import 'package:cashier_app/features/inside/presentation/pages/inside_page.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/injector_container.dart';

class _FakeRepo extends InsideRepository {
  _FakeRepo(this.rows, [this.header]) : super(Dio());
  final List<InsideChild> rows;
  final InsideSummary? header;
  @override
  Future<List<InsideChild>> list({bool background = false}) async => rows;
  @override
  Future<InsideSummary> summary({bool background = false}) async =>
      header ?? (throw StateError('no summary endpoint'));
}

InsideChild _child(
  String name, {
  String kind = 'flat_hour',
  String plan = '1 soat',
  int? endsInMinutes,
  int accrued = 0,
}) {
  final now = DateTime.now();
  return InsideChild(
    visitId: name,
    childName: name,
    parentName: 'Ota-ona',
    parentPhone: '998901234567',
    enteredAt: now.subtract(const Duration(minutes: 40)),
    elapsedMinutes: 40,
    accruedUzs: accrued,
    planName: plan,
    planKind: kind,
    hourEndsAt: endsInMinutes == null
        ? null
        : now.add(Duration(minutes: endsInMinutes, seconds: 20)),
    durationMinutes: kind == 'flat_hour' ? 60 : null,
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<InsideChild> rows, [
  InsideSummary? header,
]) async {
  if (sl.isRegistered<InsideCubit>()) sl.unregister<InsideCubit>();
  sl.registerFactory<InsideCubit>(() => InsideCubit(_FakeRepo(rows, header)));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalization.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalization.delegate.supportedLocales,
      home: Scaffold(body: InsidePage(onOpenCustomer: (_) {})),
    ),
  );
  await tester.pump();
  await tester.pump();
}

final _rows = [
  _child(
    'Vali Standart',
    kind: 'per_minute_tiers',
    plan: 'Standart',
    accrued: 25000,
  ),
  _child('Aziza Karimova', endsInMinutes: 25),
  _child('Bobur Aliyev', endsInMinutes: -14),
  _child('Malika VIP', kind: 'flat_day', plan: 'VIP'),
  _child('Sardor Toshev', endsInMinutes: 6),
  _child('Dilnoza Rahimova', endsInMinutes: -3),
];

void main() {
  test('sorts over-time first, then least time left, then the rest', () {
    final sorted = sortInsideChildren(_rows, DateTime.now());
    expect(sorted.map((c) => c.childName).take(4).toList(), [
      'Bobur Aliyev',
      'Dilnoza Rahimova',
      'Sardor Toshev',
      'Aziza Karimova',
    ]);
    expect(sorted.last.childName, 'Malika VIP');
  });

  test('time math', () {
    final now = DateTime.now();
    final over = _child('a', endsInMinutes: -14);
    expect(over.isOvertime(now), isTrue);
    expect(over.overtimeMinutes(now), 13);
    final left = _child('b', endsInMinutes: 25);
    expect(left.isOvertime(now), isFalse);
    expect(left.remainingMinutes(now), 26);
    expect(_child('c', kind: 'flat_day').remainingMinutes(now), isNull);
  });

  testWidgets('banner, filters and over-time cards', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, _rows);

    expect(
      find.text('2 ta bolaning vaqti tugagan — ota-onasini chaqiring'),
      findsOneWidget,
    );
    expect(find.text('Vaqti tugagan · 2'), findsOneWidget);
    expect(find.text('Vaqtli · 4'), findsOneWidget);

    await tester.tap(find.text('Ko‘rsatish'));
    await tester.pump();
    expect(find.text('Bobur Aliyev'), findsOneWidget);
    expect(find.text('Dilnoza Rahimova'), findsOneWidget);
    expect(find.text('Aziza Karimova'), findsNothing);
    expect(find.text('Vali Standart'), findsNothing);
  });

  testWidgets('no hour children: no filters, no banner', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, [_rows.first]);
    expect(find.textContaining('Vaqti tugagan'), findsNothing);
    expect(find.textContaining('vaqti tugagan'), findsNothing);
  });

  testWidgets('no turnstile: sales header and only 1 soat children', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      _rows,
      const InsideSummary(
        hasTurnstile: false,
        vipSoldToday: 115,
        hourSoldToday: 50,
        standardSoldToday: 0,
      ),
    );

    expect(find.text('115'), findsOneWidget);
    expect(find.text('Bugun VIP sotildi'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('Vaqtli ichkarida'), findsOneWidget);
    // Sardor has 6 min left — the only one about to run out.
    expect(find.text('10 daqiqada tugaydi'), findsOneWidget);
    expect(find.text('Vali Standart'), findsNothing);
    expect(find.text('Malika VIP'), findsNothing);
    expect(find.text('Aziza Karimova'), findsOneWidget);
    expect(find.text('Vaqtli · 4'), findsOneWidget);
    expect(find.text('Hammasi · 4'), findsOneWidget);
  });
}
