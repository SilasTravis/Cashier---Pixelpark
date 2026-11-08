import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/core/utils/currency.dart';
import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/features/birthday_parties/data/birthday_parties_repository.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_plan.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_wallet.dart';
import 'package:cashier_app/features/birthday_parties/presentation/widgets/birthday_sell_dialog.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/kids_plan.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_detail_panel.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/services_section.dart';
import 'dart:async';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/injector_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
  ServerException? failWith;
  final bool failPlain;

  /// What `get(requestId)` answers (null = not found).
  BirthdayParty? getResult;
  final gets = <String>[];
  Object? getError;
  final calls = <Map<String, Object?>>[];

  /// What the birthday wallet answers: 600 000 real money of a 900 000
  /// balance (300 000 bonus) unless a test says otherwise.
  BirthdayWallet walletResult = const BirthdayWallet(
    balanceUzs: 900000,
    usableUzs: 600000,
    bonusUzs: 300000,
  );
  Object? walletError;
  Completer<void>? walletGate;
  final walletCalls = <int>[];

  @override
  Future<BirthdayWallet> wallet(int customerId) async {
    walletCalls.add(customerId);
    await walletGate?.future;
    if (walletError != null) throw walletError!;
    return walletResult;
  }

  @override
  Future<BirthdayParty> get(String id) async {
    gets.add(id);
    if (getError != null) throw getError!;
    return getResult ??
        (throw ServerException(
          message: 'x',
          code: 'BIRTHDAY_PARTY_NOT_FOUND',
          statusCode: 404,
        ));
  }

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
  balance: 900000,
  children: [],
);

Future<void> _openDialog(
  WidgetTester tester,
  _FakeRepo repo, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  sl.registerSingleton<BirthdayPartiesRepository>(repo);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalization.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
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
          statusCode: 400,
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

  testWidgets('a non-server failure locks the amounts and retries same id', (
    tester,
  ) async {
    final repo = _FakeRepo(failPlain: true);
    await _openDialog(tester, repo);
    await _fillSale(tester);
    await _tap(tester, 'birthday-submit');
    expect(find.byKey(const ValueKey('birthday-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('birthday-unclear-hint')), findsOneWidget);
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

  testWidgets('the minus takes one extra child off and stops at 0', (
    tester,
  ) async {
    await _openDialog(tester, _FakeRepo());
    await _fillSale(tester);
    expect(find.text('+2'), findsOneWidget);
    String total() => tester
        .widget<TextField>(find.byKey(const ValueKey('birthday-total-field')))
        .controller!
        .text;
    IconButton minus() => tester.widget<IconButton>(
      find.byKey(const ValueKey('birthday-extra-minus')),
    );
    expect(total(), '2 240 000');
    await _tap(tester, 'birthday-extra-minus');
    expect(find.text('+1'), findsOneWidget);
    expect(total(), '2 120 000');
    expect(minus().onPressed, isNotNull);
    await _tap(tester, 'birthday-extra-minus');
    expect(total(), '2 000 000');
    // At 0 the minus is disabled: never below the package size.
    expect(minus().onPressed, isNull);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('birthday-extra-count')))
          .data,
      '0',
    );
    await _tap(tester, 'birthday-extra-plus');
    expect(total(), '2 120 000');
    expect(minus().onPressed, isNotNull);
  });

  testWidgets('a fresh size starts with the minus disabled', (tester) async {
    await _openDialog(tester, _FakeRepo());
    await _tap(tester, 'birthday-tier-vip');
    await _tap(tester, 'birthday-size-10');
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('birthday-extra-minus')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('the plus stops at 50 extra children', (tester) async {
    await _openDialog(tester, _FakeRepo());
    await _tap(tester, 'birthday-tier-vip');
    await _tap(tester, 'birthday-size-10');
    for (var i = 0; i < 50; i++) {
      await tester.tap(find.byKey(const ValueKey('birthday-extra-plus')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('birthday-extra-plus')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('Hozir olinadi shows what to take after the balance', (
    tester,
  ) async {
    await _openDialog(tester, _FakeRepo());
    await _fillSale(tester);
    // Jami 2 240 000, balance 600 000 switched on (the default).
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('bd-take-now-amount')))
          .data,
      "1 640 000 so'm",
    );
    expect(find.textContaining('Hozir olinadi'), findsOneWidget);
    expect(find.textContaining('Naqd'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('bd-from-balance')),
        matching: find.text("Balansdan −600 000 so'm"),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a clearing the Jami field disables submit and keeps it empty', (
    tester,
  ) async {
    await _openDialog(tester, _FakeRepo());
    await _fillSale(tester);
    await tester.enterText(
      find.byKey(const ValueKey('birthday-total-field')),
      '',
    );
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('birthday-total-field')),
    );
    expect(field.controller!.text, '');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('birthday-submit')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a lost response whose party exists books once and closes', (
    tester,
  ) async {
    final repo = _FakeRepo(failWith: ServerException(message: 'timeout'))
      ..getResult = _party();
    await _openDialog(tester, repo);
    await _fillSale(tester);
    await _tap(tester, 'birthday-submit');
    expect(repo.calls, hasLength(1));
    expect(repo.gets, hasLength(1));
    expect(find.byKey(const ValueKey('birthday-submit')), findsNothing);
  });

  testWidgets('closing while offline keeps the sell sheet locked', (
    tester,
  ) async {
    final repo = _FakeRepo(failWith: ServerException(message: 'timeout'));
    await _openDialog(tester, repo);
    await _fillSale(tester);
    await _tap(tester, 'birthday-submit');
    repo.getError = ServerException(message: 'timeout');
    await _tap(tester, 'birthday-close');
    expect(find.byKey(const ValueKey('birthday-offline-hint')), findsOneWidget);
    expect(find.byKey(const ValueKey('birthday-submit')), findsOneWidget);
    // Confirmed not booked: released.
    repo.getError = null;
    await _tap(tester, 'birthday-close');
    expect(find.byKey(const ValueKey('birthday-submit')), findsNothing);
  });

  testWidgets('an unclear failure locks the amounts and offers a retry', (
    tester,
  ) async {
    final repo = _FakeRepo(failWith: ServerException(message: 'timeout'));
    await _openDialog(tester, repo);
    await _fillSale(tester);
    await _tap(tester, 'birthday-submit');
    expect(find.byKey(const ValueKey('birthday-unclear-hint')), findsOneWidget);
    expect(find.text('Qayta urinish'), findsOneWidget);
    // Frozen: a tap on + changes nothing.
    await tester.tap(
      find.byKey(const ValueKey('birthday-extra-plus')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('+2'), findsOneWidget);
    // Retry: same requestId.
    repo.getResult = null;
    await _tap(tester, 'birthday-submit');
    expect(repo.calls, hasLength(2));
    expect(repo.calls[0]['requestId'], repo.calls[1]['requestId']);
    // Closing re-fetches the party first; the sale did go through.
    repo.getResult = _party();
    await _tap(tester, 'birthday-close');
    expect(repo.gets.length, greaterThanOrEqualTo(3));
    expect(find.byKey(const ValueKey('birthday-submit')), findsNothing);
  });

  testWidgets('a locked sheet takes the keyboard away from its fields', (
    tester,
  ) async {
    final repo = _FakeRepo(failWith: ServerException(message: 'timeout'));
    await _openDialog(tester, repo);
    await _fillSale(tester);
    final total = find.byKey(const ValueKey('birthday-total-field'));
    FocusNode node() => tester
        .widget<EditableText>(
          find.descendant(of: total, matching: find.byType(EditableText)),
        )
        .focusNode;
    await tester.tap(total);
    await tester.pump();
    expect(node().hasFocus, isTrue);
    await _tap(tester, 'birthday-submit');
    expect(find.byKey(const ValueKey('birthday-unclear-hint')), findsOneWidget);
    expect(node().hasFocus, isFalse);
    expect(node().canRequestFocus, isFalse);
  });

  group('balance = real money only', () {
    testWidgets('only the usable part pays; the bonus is named, not used', (
      tester,
    ) async {
      final repo = _FakeRepo();
      await _openDialog(tester, repo);
      await _fillSale(tester);
      expect(repo.walletCalls, [42]);
      String text(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data!;
      expect(
        text('bd-balance-usable'),
        "Balans: 600 000 so'm ishlatsa bo‘ladi",
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('bd-balance-bonus')),
          matching: find.text('Bonus 300 000 — ishlatib bo‘lmaydi'),
        ),
        findsOneWidget,
      );
      // Jami 2 240 000 − usable 600 000 (not the whole 900 000 balance).
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('bd-take-now-amount')))
            .data,
        "1 640 000 so'm",
      );
      await _tap(tester, 'birthday-submit');
      expect(repo.calls.single['money'], (
        fromBalanceUzs: 600000,
        cashUzs: 1640000,
        cardUzs: 0,
      ));
    });

    testWidgets('no real money disables the balance switch', (tester) async {
      final repo = _FakeRepo()
        ..walletResult = const BirthdayWallet(
          balanceUzs: 300000,
          usableUzs: 0,
          bonusUzs: 300000,
        );
      await _openDialog(tester, repo);
      await _fillSale(tester);
      final row = find.byKey(const ValueKey('bd-balance-row'));
      final sw = tester.widget<Switch>(
        find.descendant(of: row, matching: find.byType(Switch)),
      );
      expect(sw.onChanged, isNull);
      expect(sw.value, isFalse);
      expect(find.byKey(const ValueKey('bd-balance-none')), findsOneWidget);
      expect(find.byKey(const ValueKey('bd-balance-bonus')), findsOneWidget);
      expect(find.byKey(const ValueKey('bd-from-balance')), findsNothing);
      await _tap(tester, 'birthday-submit');
      expect(repo.calls.single['money'], (
        fromBalanceUzs: 0,
        cashUzs: 2240000,
        cardUzs: 0,
      ));
    });

    testWidgets('a failed wallet read disables the switch, cash still sells', (
      tester,
    ) async {
      final repo = _FakeRepo()..walletError = ServerException(message: 'x');
      await _openDialog(tester, repo);
      await _fillSale(tester);
      expect(find.byKey(const ValueKey('bd-balance-failed')), findsOneWidget);
      final sw = tester.widget<Switch>(
        find.descendant(
          of: find.byKey(const ValueKey('bd-balance-row')),
          matching: find.byType(Switch),
        ),
      );
      expect(sw.onChanged, isNull);
      await _tap(tester, 'birthday-submit');
      expect(repo.calls.single['money'], (
        fromBalanceUzs: 0,
        cashUzs: 2240000,
        cardUzs: 0,
      ));
    });

    testWidgets('a skeleton shows and submit waits while the wallet loads', (
      tester,
    ) async {
      final repo = _FakeRepo()..walletGate = Completer<void>();
      await _openDialog(tester, repo, settle: false);
      await _fillSale(tester);
      expect(find.byKey(const ValueKey('bd-balance-skeleton')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('birthday-submit')))
            .onPressed,
        isNull,
      );
      repo.walletGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bd-balance-skeleton')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('birthday-submit')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('BIRTHDAY_BALANCE_INSUFFICIENT re-reads the wallet', (
      tester,
    ) async {
      final repo = _FakeRepo(
        failWith: ServerException(
          message: 'x',
          code: 'BIRTHDAY_BALANCE_INSUFFICIENT',
          statusCode: 400,
        ),
      );
      await _openDialog(tester, repo);
      await _fillSale(tester);
      repo.walletResult = const BirthdayWallet(
        balanceUzs: 400000,
        usableUzs: 100000,
        bonusUzs: 300000,
      );
      await _tap(tester, 'birthday-submit');
      expect(repo.walletCalls, hasLength(2));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('bd-balance-usable')))
            .data,
        "Balans: 100 000 so'm ishlatsa bo‘ladi",
      );
    });
  });

  testWidgets('a narrow window stacks one column with the buttons pinned', (
    tester,
  ) async {
    await _openDialog(tester, _FakeRepo());
    tester.view.physicalSize = const Size(1000, 760);
    await tester.pumpAndSettle();
    await _fillSale(tester);
    await _tap(tester, 'birthday-mode-deposit');
    await _tap(tester, 'birthday-deposit-chip-200000');
    expect(tester.takeException(), isNull);
    // The summary sits under the choices, not beside them.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('birthday-total-field'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('birthday-size-10'))).dy,
      ),
    );
    // The submit button stays on screen.
    final submit = tester.getRect(
      find.byKey(const ValueKey('birthday-submit')),
    );
    expect(submit.bottom, lessThanOrEqualTo(760));
  });

  testWidgets('opens full-window with the parent in the top bar', (
    tester,
  ) async {
    await _openDialog(tester, _FakeRepo());
    final screen = tester.getSize(find.byType(BirthdaySellDialog));
    expect(screen, const Size(1600, 1200));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('birthday-customer'))).data,
      contains('Ali'),
    );
    // The X closes it like Bekor qilish.
    await _tap(tester, 'birthday-close-x');
    expect(find.byType(BirthdaySellDialog), findsNothing);
  });

  group('Xizmatlar on the account page', () {
    Future<PosAccountBloc> pumpPanel(WidgetTester tester) async {
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
      return bloc;
    }

    testWidgets(
      'a sale that resolves after the panel is gone still prints, no throw',
      (tester) async {
        final repo = _FakeRepo(failWith: ServerException(message: 'timeout'));
        sl.registerSingleton<BirthdayPartiesRepository>(repo);
        final bloc = await pumpPanel(tester);
        await _tap(tester, 'service-birthday-card');
        await _fillSale(tester);
        // A lost response: the sheet locks.
        await _tap(tester, 'birthday-submit');
        expect(
          find.byKey(const ValueKey('birthday-unclear-hint')),
          findsOneWidget,
        );
        // The shell swaps the tab (offline switch): the panel and its bloc
        // are disposed; the sheet on the root navigator stays.
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [AppLocalization.delegate],
            supportedLocales: AppLocalization.delegate.supportedLocales,
            home: const Scaffold(body: SizedBox()),
          ),
        );
        await tester.runAsync(bloc.close);
        expect(bloc.isClosed, isTrue);
        await tester.pumpAndSettle();
        expect(find.byType(CustomerDetailPanel), findsNothing);
        expect(find.byKey(const ValueKey('birthday-submit')), findsOneWidget);
        // Back online, the retry replays the booked sale and the sheet pops.
        repo.failWith = null;
        await _tap(tester, 'birthday-submit');
        expect(find.byKey(const ValueKey('birthday-submit')), findsNothing);
        // The receipt was still attempted (no printer here: it reports the
        // failure through the app's messenger) and nothing threw.
        expect(
          find.text('Receipt could not be printed. Check the printer.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the birthday card sits under Amallar tarixi and opens the '
        'full-window sale', (tester) async {
      sl.registerSingleton<BirthdayPartiesRepository>(_FakeRepo());
      await pumpPanel(tester);
      expect(find.text('Services'), findsOneWidget);
      final card = find.byKey(const ValueKey('service-birthday-card'));
      expect(tester.widget<ServiceCard>(card).onTap, isNotNull);
      // Below the history accordion.
      expect(
        tester.getTopLeft(card).dy,
        greaterThan(tester.getTopLeft(find.text('Transaction history')).dy),
      );
      // The old header button is gone.
      expect(find.byKey(const ValueKey('sell-birthday-button')), findsNothing);
      await _tap(tester, 'service-birthday-card');
      expect(find.byType(BirthdaySellDialog), findsOneWidget);
      expect(
        tester.getSize(find.byType(BirthdaySellDialog)),
        const Size(1600, 1200),
      );
    });

    testWidgets('the birthday card is disabled while the till is offline', (
      tester,
    ) async {
      sl.registerSingleton<AppModeCubit>(_OfflineMode());
      await pumpPanel(tester);
      final card = find.byKey(const ValueKey('service-birthday-card'));
      expect(tester.widget<ServiceCard>(card).onTap, isNull);
      expect(
        find.descendant(
          of: card,
          matching: find.text('Birthday sales need an internet connection'),
        ),
        findsOneWidget,
      );
      await tester.tap(card, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(BirthdaySellDialog), findsNothing);
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
