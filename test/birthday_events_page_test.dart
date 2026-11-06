import 'package:cashier_app/core/utils/currency.dart';
import 'package:cashier_app/features/birthday_parties/data/birthday_parties_repository.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:cashier_app/features/birthday_parties/presentation/pages/birthday_events_page.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/injector_container.dart';
import 'package:cashier_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

BirthdayParty _party(String date) => BirthdayParty.fromJson({
  'id': 'p1',
  'status': 'booked',
  'paymentState': 'partial',
  'branchId': 'b1',
  'branchName': 'Megaplanet',
  'customer': {
    'id': 42,
    'fullName': 'Ali Valiyev',
    'phoneNumber': '998901112233',
  },
  'plan': {'id': 'vip', 'name': 'VIP', 'color': '#7C3AED', 'includedItems': []},
  'childCount': 10,
  'extraChildren': 2,
  'packagePriceUzs': 2000000,
  'extraChildUzs': 120000,
  'listPriceUzs': 2240000,
  'agreedPriceUzs': 2240000,
  'discountUzs': 0,
  'paidUzs': 1040000,
  'refundedUzs': 0,
  'debtUzs': 1200000,
  'keptUzs': 0,
  'maxCashRefundUzs': 0,
  'partyDate': date,
  'soldBy': null,
  'createdAt': '2026-11-06T10:00:00.000Z',
  'completedAt': null,
  'cancelledAt': null,
  'cancelReason': null,
  'payments': [
    {
      'id': 'pay1',
      'kind': 'payment',
      'amountUzs': 1040000,
      'fromBalanceUzs': 0,
      'cashUzs': 1040000,
      'cardUzs': 0,
      'refundTo': null,
      'cashier': null,
      'createdAt': '2026-11-06T10:00:00.000Z',
    },
  ],
  'comments': [
    {
      'id': 'c1',
      'text': 'x',
      'author': 'a',
      'createdAt': '2026-11-06T10:00:00.000Z',
    },
  ],
});

class _FakeRepo implements BirthdayPartiesRepository {
  _FakeRepo(this.party);
  final BirthdayParty party;
  final calls = <BirthdayPartyStatus>[];

  @override
  Future<List<BirthdayParty>> list(BirthdayPartyStatus status) async {
    calls.add(status);
    return status == BirthdayPartyStatus.booked ? [party] : [];
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepo> _pump(
  WidgetTester tester,
  String date, {
  void Function(BirthdayParty)? onOpen,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final repo = _FakeRepo(_party(date));
  sl.registerSingleton<BirthdayPartiesRepository>(repo);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalization.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalization.delegate.supportedLocales,
      home: Scaffold(body: BirthdayEventsPage(onOpen: onOpen ?? (_) {})),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  tearDown(() => sl.reset());

  testWidgets('partial party shows debt chip and + To‘lov; segments reload', (
    tester,
  ) async {
    final repo = await _pump(tester, '2999-01-01');
    expect(find.text('Ali Valiyev'), findsOneWidget);
    expect(find.textContaining('Qarz ${groupDigits(1200000)}'), findsOneWidget);
    expect(find.text('+ To‘lov'), findsOneWidget);
    expect(repo.calls, [BirthdayPartyStatus.booked]);

    await tester.tap(find.text('Yakunlangan'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, BirthdayPartyStatus.completed);
  });

  testWidgets('party dated today or earlier offers Yakunlash and opens', (
    tester,
  ) async {
    BirthdayParty? opened;
    await _pump(tester, '2000-01-01', onOpen: (p) => opened = p);
    expect(find.text('Yakunlash'), findsOneWidget);
    expect(find.text('+ To‘lov'), findsNothing);
    await tester.tap(find.text('Yakunlash'));
    expect(opened?.id, 'p1');
  });
}
