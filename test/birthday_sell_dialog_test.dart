import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/core/utils/currency.dart';
import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/features/birthday_parties/data/birthday_parties_repository.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_plan.dart';
import 'package:cashier_app/features/birthday_parties/presentation/widgets/birthday_sell_dialog.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/kids_plan.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_detail_panel.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/injector_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _vip = BirthdayPlan(
  id: 'vip',
  name: 'VIP',
  color: '#7C3AED',
  active: true,
  allBranches: true,
  branchIds: [],
  includedItems: ['3 hours whole park', 'Animators and show'],
  sortOrder: 0,
  sizes: [
    BirthdayPlanSize(childCount: 5, priceUzs: 1200000, extraChildUzs: 150000),
    BirthdayPlanSize(childCount: 10, priceUzs: 2000000, extraChildUzs: 120000),
    BirthdayPlanSize(childCount: 15, priceUzs: 2700000, extraChildUzs: 100000),
  ],
);

BirthdayParty _party() => BirthdayParty.fromJson({
  'id': 'p1',
  'status': 'booked',
  'paymentState': 'partial',
  'branchId': 'b1',
  'branchName': 'Megaplanet',
  'customer': {'id': 42, 'fullName': 'Ali', 'phoneNumber': '998901112233'},
  'plan': {'id': 'vip', 'name': 'VIP', 'color': '#7C3AED', 'includedItems': []},
  'childCount': 10,
  'extraChildren': 2,
  'packagePriceUzs': 2000000,
  'extraChildUzs': 120000,
  'listPriceUzs': 2240000,
  'agreedPriceUzs': 2200000,
  'discountUzs': 40000,
  'paidUzs': 200000,
  'refundedUzs': 0,
  'debtUzs': 2000000,
  'keptUzs': 0,
  'maxCashRefundUzs': 200000,
  'partyDate': '2026-11-20',
  'soldBy': null,
  'createdAt': '2026-11-06T10:00:00.000Z',
  'completedAt': null,
  'cancelledAt': null,
  'cancelReason': null,
  'payments': [],
  'comments': [],
});

class _FakeRepo implements BirthdayPartiesRepository {
  _FakeRepo({this.failWith, this.failPlain = false});
  final ServerException? failWith;
  final bool failPlain;
  final calls = <Map<String, Object?>>[];

  @override
  Future<List<BirthdayPlan>> plans() async => [_vip];

  @override
  Future<BirthdayParty> sell({
    required int customerId,
    required String planId,
    required int childCount,
    required int extraChildren,
    required String partyDate,
    required int agreedPriceUzs,
    required BirthdayMoney money,
    required String requestId,
  }) async {
    calls.add({
      'customerId': customerId,
      'planId': planId,
      'childCount': childCount,
      'extraChildren': extraChildren,
      'agreedPriceUzs': agreedPriceUzs,
      'money': money,
      'requestId': requestId,
    });
    if (failWith != null) throw failWith!;
    if (failPlain) throw Exception('bad body');
    return _party();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfflineMode implements AppModeCubit {
  @override
  AppModeState get state => const AppModeState(mode: AppMode.offline);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _customer = Customer(
  id: 42,
  phoneNumber: '998901112233',
  firstName: 'Ali',
  lastName: null,
  balance: 600000,
  children: [],
);

Future<void> _openDialog(WidgetTester tester, _FakeRepo repo) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  sl.registerSingleton<BirthdayPartiesRepository>(repo);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalization.delegate],
      supportedLocales: AppLocalization.delegate.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('open'),
            onPressed: () =>
                showBirthdaySellDialog(context, customer: _customer),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _fillSale(WidgetTester tester) async {
  await _tap(tester, 'birthday-tier-vip');
  await _tap(tester, 'birthday-size-10');
  await _tap(tester, 'birthday-extra-plus');
  await _tap(tester, 'birthday-extra-plus');
}

void main() {
  tearDown(() async => sl.reset());

  testWidgets('tapping a tier shows what it includes', (tester) async {
    await _openDialog(tester, _FakeRepo());
    expect(find.text('3 hours whole park'), findsNothing);
    await _tap(tester, 'birthday-tier-vip');
    expect(find.text('3 hours whole park'), findsOneWidget);
    expect(find.text('Animators and show'), findsOneWidget);
  });

  testWidgets('size 10 + two extra children totals 2 240 000', (tester) async {
    await _openDialog(tester, _FakeRepo());
    await _fillSale(tester);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('birthday-total-field')),
    );
    expect(field.controller!.text, '2 240 000');
  });

  testWidgets('overriding the total strikes the list price', (tester) async {
    await _openDialog(tester, _FakeRepo());
    await _fillSale(tester);
    expect(find.byKey(const ValueKey('birthday-list-struck')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('birthday-total-field')),
      '2200000',
    );
    await tester.pumpAndSettle();
    final struck = find.byKey(const ValueKey('birthday-list-struck'));
    expect(struck, findsOneWidget);
    expect(tester.widget<Text>(struck).data, "2 240 000 so'm");
  });

  testWidgets('deposit sells with the chosen money split', (tester) async {
    final repo = _FakeRepo();
    await _openDialog(tester, repo);
    await _fillSale(tester);
    await tester.enterText(
      find.byKey(const ValueKey('birthday-total-field')),
      '2200000',
    );
    await _tap(tester, 'birthday-mode-deposit');
    await _tap(tester, 'birthday-deposit-chip-200000');

    final remaining = find.byKey(const ValueKey('birthday-remaining'));
    expect(
      find.descendant(of: remaining, matching: find.text("2 000 000 so'm")),
      findsOneWidget,
    );

    await _tap(tester, 'birthday-submit');

    expect(repo.calls, hasLength(1));
    final call = repo.calls.single;
    expect(call['customerId'], 42);
    expect(call['planId'], 'vip');
    expect(call['childCount'], 10);
    expect(call['extraChildren'], 2);
    expect(call['agreedPriceUzs'], 2200000);
    expect(call['money'], (fromBalanceUzs: 0, cashUzs: 200000, cardUzs: 0));
    // The dialog closed with the created party.
    expect(find.byKey(const ValueKey('birthday-submit')), findsNothing);
  });

  testWidgets(
    'a refused sale keeps the dialog and retries the same requestId',
    (tester) async {
      final repo = _FakeRepo(
        failWith: ServerException(
          message: 'Balans yetarli emas: 100 000',
          code: 'BIRTHDAY_BALANCE_INSUFFICIENT',
        ),
      );
      await _openDialog(tester, repo);
      await _fillSale(tester);

      await _tap(tester, 'birthday-submit');
      expect(find.text('Balans yetarli emas: 100 000'), findsOneWidget);
      expect(find.byKey(const ValueKey('birthday-submit')), findsOneWidget);

      await _tap(tester, 'birthday-submit');
      expect(repo.calls, hasLength(2));
      expect(repo.calls[0]['requestId'], repo.calls[1]['requestId']);
      expect((repo.calls[0]['requestId'] as String).length, 36);
    },
  );

  testWidgets('re-tapping the same size keeps Jami and the sale price equal', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await _openDialog(tester, repo);
    await _fillSale(tester);
    await tester.enterText(
      find.byKey(const ValueKey('birthday-total-field')),
      '2200000',
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'birthday-size-10');
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('birthday-total-field')),
    );
    await _tap(tester, 'birthday-submit');
    expect(
      repo.calls.single['agreedPriceUzs'],
      parseUzs(field.controller!.text),
    );
  });

  testWidgets('Zaklad with no amount books with no money now', (tester) async {
    final repo = _FakeRepo();
    await _openDialog(tester, repo);
    await _fillSale(tester);
    await _tap(tester, 'birthday-mode-deposit');
    final remaining = find.byKey(const ValueKey('birthday-remaining'));
    expect(
      find.descendant(of: remaining, matching: find.text("2 240 000 so'm")),
      findsOneWidget,
    );
    await _tap(tester, 'birthday-submit');
    expect(repo.calls.single['money'], (
      fromBalanceUzs: 0,
      cashUzs: 0,
      cardUzs: 0,
    ));
  });

  testWidgets('a non-server failure unlocks the sheet and retries same id', (
    tester,
  ) async {
    final repo = _FakeRepo(failPlain: true);
    await _openDialog(tester, repo);
    await _fillSale(tester);
    await _tap(tester, 'birthday-submit');
    expect(find.byKey(const ValueKey('birthday-error')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('birthday-submit')))
          .onPressed,
      isNotNull,
    );
    await _tap(tester, 'birthday-submit');
    expect(repo.calls, hasLength(2));
    expect(repo.calls[0]['requestId'], repo.calls[1]['requestId']);
  });

  group('sell button on the account page', () {
    Future<void> pumpPanel(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final bloc = PosAccountBloc(PosAccountRepository(_PanelRemote()))
        ..add(const PosAccountCustomerSelected(_customer));
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalization.delegate],
          supportedLocales: AppLocalization.delegate.supportedLocales,
          home: BlocProvider.value(
            value: bloc,
            child: const Scaffold(body: CustomerDetailPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is enabled online', (tester) async {
      await pumpPanel(tester);
      final button = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('sell-birthday-button')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('is disabled while the till is offline', (tester) async {
      sl.registerSingleton<AppModeCubit>(_OfflineMode());
      await pumpPanel(tester);
      final button = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('sell-birthday-button')),
      );
      expect(button.onPressed, isNull);
    });
  });
}

class _PanelRemote implements PosAccountRemoteDataSource {
  @override
  Future<List<KidsPlan>> listPlans() async => [];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => [];

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
