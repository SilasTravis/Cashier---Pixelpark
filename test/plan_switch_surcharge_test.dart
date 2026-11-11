import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/printing/child_ticket_printer.dart';
import 'package:cashier_app/core/utils/currency.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/kids_plan.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/domain/pos_entry.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_detail_panel.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/plan_conflict_dialog.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/plan_entry_printing.dart';
import 'package:cashier_app/generated/l10n.dart';

typedef _Checkout = ({
  String? planKey,
  List<String> childIds,
  int cashUzs,
  int cardUzs,
  int companions,
  bool replacePlan,
});

/// Records every checkout and answers from [results] in order.
class _FakeRemote implements PosAccountRemoteDataSource {
  _FakeRemote({required this.activePasses, required this.results});

  final List<ActivePass> activePasses;
  final List<PosEntryResult> results;
  final List<_Checkout> checkouts = [];
  int planEntryCalls = 0;

  @override
  Future<PosEntryResult> planEntryCheckout({
    required int customerId,
    required String? planKey,
    required List<String> childIds,
    required List<CheckoutLine> products,
    required int cashUzs,
    required int cardUzs,
    Map<String, String> entryDiscounts = const {},
    int companions = 0,
    String? discountId,
    ({String code, String childId})? promoCode,
    String? checkDiscountId,
    bool replacePlan = false,
    List<String> subscriptionChildIds = const [],
  }) async {
    checkouts.add((
      planKey: planKey,
      childIds: childIds,
      cashUzs: cashUzs,
      cardUzs: cardUzs,
      companions: companions,
      replacePlan: replacePlan,
    ));
    return results[checkouts.length - 1];
  }

  @override
  Future<PosEntryResult> issuePlanEntry({
    required int customerId,
    required String planKey,
    required List<String> childIds,
    bool replacePlan = false,
  }) async {
    planEntryCalls++;
    return const PosEntryResult(entries: [], failures: []);
  }

  @override
  Future<List<KidsPlan>> listPlans() async => const [
    KidsPlan(
      key: 'standard',
      name: 'Standart',
      kind: KidsPlanKind.perMinuteTiers,
      firstMinuteUzs: 1000,
      secondMinuteUzs: 1000,
      extraMinuteUzs: 1000,
      flatUzs: null,
    ),
    KidsPlan(
      key: 'vip',
      name: 'VIP',
      kind: KidsPlanKind.flatDay,
      firstMinuteUzs: null,
      secondMinuteUzs: null,
      extraMinuteUzs: null,
      flatUzs: 75000,
    ),
    KidsPlan(
      key: 'hour',
      name: '1 soat',
      kind: KidsPlanKind.flatHour,
      firstMinuteUzs: null,
      secondMinuteUzs: null,
      extraMinuteUzs: null,
      flatUzs: 60000,
      durationMinutes: 60,
    ),
  ];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async =>
      activePasses;

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _upgradeConflict = PosEntryConflict(
  childId: 'child-1',
  currentPlanKey: 'hour',
  currentPlanLabel: '1 soat',
  requestedPlanKey: 'vip',
  isInside: false,
  accruedDueUzs: 0,
  switchable: true,
  upgradeCreditUzs: 60000,
  upgradeDueUzs: 15000,
);

/// The new backend's answer to a conflicted press: nothing moved.
PosEntryResult _conflicted(int balance) => PosEntryResult(
  entries: const [],
  failures: const [],
  conflicts: const [_upgradeConflict],
  balance: balance,
);

Future<(PosAccountBloc, _FakeRemote)> _pumpPanel(
  WidgetTester tester, {
  required List<PosEntryResult> results,
  bool secondChild = false,
  int balance = 0,
  List<ActivePass>? passes,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final remote = _FakeRemote(
    activePasses: passes ?? [_pass('child-1', 'hour', '1 soat')],
    results: results,
  );
  final bloc = PosAccountBloc(PosAccountRepository(remote))
    ..add(const PosAccountPlansRequested())
    ..add(
      PosAccountCustomerSelected(
        Customer(
          id: 7,
          phoneNumber: '+998901234567',
          firstName: 'Dil',
          lastName: null,
          balance: balance,
          children: [
            Child(
              id: 'child-1',
              firstName: 'Aziza',
              lastName: null,
              birthDate: DateTime(2018, 1, 1),
            ),
            if (secondChild)
              Child(
                id: 'child-2',
                firstName: 'Bobur',
                lastName: null,
                birthDate: DateTime(2019, 1, 1),
              ),
          ],
        ),
      ),
    );
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
  return (bloc, remote);
}

ActivePass _pass(
  String childId,
  String planKey,
  String label, {
  String? discountId,
}) => ActivePass(
  childId: childId,
  planKey: planKey,
  planLabel: label,
  expiresAt: DateTime.now().add(const Duration(minutes: 30)),
  dueTodayUzs: 0,
  discountId: discountId,
  discountName: discountId == null ? null : 'Flayer',
);

Future<void> _selectAll(
  WidgetTester tester, {
  bool secondChild = false,
  String plan = 'VIP',
}) async {
  final rows = find.byKey(const ValueKey('child-select'));
  await tester.tap(rows.first);
  if (secondChild) await tester.tap(rows.at(1));
  await tester.pump();
  await tester.tap(find.text(plan));
  await tester.pumpAndSettle();
}

Finder _due(int uzs) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      w.key == const ValueKey('pay-due') &&
      w.data == formatUzs(uzs),
);

Finder _collect(int uzs) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      w.key == const ValueKey('switch-collect') &&
      w.data == formatUzs(uzs),
);

void main() {
  group('panel: live 1 soat (60 000) → VIP (75 000)', () {
    testWidgets('the first press asks no money and collects nothing', (
      tester,
    ) async {
      final (_, remote) = await _pumpPanel(tester, results: [_conflicted(0)]);
      await _selectAll(tester);

      expect(_due(75000), findsNothing);
      expect(find.text('Pay and print'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(remote.checkouts, hasLength(1));
      final first = remote.checkouts.single;
      expect(first.cashUzs, 0);
      expect(first.cardUzs, 0);
      expect(first.replacePlan, isFalse);
      // The modal is up with only the surcharge to collect.
      expect(_collect(15000), findsOneWidget);
      expect(find.text("Switch and print · 15 000 so'm"), findsOneWidget);
      expect(
        find.textContaining('collected now, in cash or by card'),
        findsOneWidget,
      );
    });

    testWidgets('confirming re-sends the checkout with replacePlan and only '
        'the surcharge, and the balance follows the response', (tester) async {
      final (bloc, remote) = await _pumpPanel(
        tester,
        results: [
          _conflicted(0),
          const PosEntryResult(entries: [], failures: [], balance: 0),
        ],
      );
      await _selectAll(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Card'));
      await tester.pump();
      await tester.tap(find.text("Switch and print · 15 000 so'm"));
      await tester.pumpAndSettle();

      expect(remote.checkouts, hasLength(2));
      final retry = remote.checkouts[1];
      expect(retry.replacePlan, isTrue);
      expect(retry.planKey, 'vip');
      expect(retry.childIds, ['child-1']);
      expect(retry.cashUzs, 0);
      expect(retry.cardUzs, 15000);
      // Never the bare plan-entry for a switch.
      expect(remote.planEntryCalls, 0);
      expect(bloc.state.selectedCustomer!.balance, 0);
    });

    testWidgets('another new child is collected at full price with the '
        'surcharge', (tester) async {
      final (_, remote) = await _pumpPanel(
        tester,
        secondChild: true,
        results: [
          _conflicted(0),
          const PosEntryResult(entries: [], failures: [], balance: 0),
        ],
      );
      await _selectAll(tester, secondChild: true);
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(remote.checkouts.single.cashUzs, 0);

      // 75 000 for the new child + 15 000 surcharge.
      expect(_collect(90000), findsOneWidget);
      await tester.tap(find.text("Switch and print · 90 000 so'm"));
      await tester.pumpAndSettle();

      final retry = remote.checkouts[1];
      expect(retry.replacePlan, isTrue);
      expect(retry.childIds, ['child-1', 'child-2']);
      expect(retry.cashUzs, 90000);
      expect(retry.cardUzs, 0);
    });

    testWidgets('a balance that covers the surcharge collects nothing', (
      tester,
    ) async {
      final (_, remote) = await _pumpPanel(
        tester,
        balance: 20000,
        results: [
          _conflicted(20000),
          const PosEntryResult(entries: [], failures: [], balance: 5000),
        ],
      );
      await _selectAll(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('switch-collect')), findsNothing);
      await tester.tap(find.text('Switch and print'));
      await tester.pumpAndSettle();

      final retry = remote.checkouts[1];
      expect(retry.replacePlan, isTrue);
      expect(retry.cashUzs + retry.cardUzs, 0);
    });

    testWidgets('cancel and re-print move no money', (tester) async {
      final (_, remote) = await _pumpPanel(
        tester,
        results: [_conflicted(0), _conflicted(0)],
      );
      await _selectAll(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(remote.checkouts, hasLength(1));

      await _selectAll(tester);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Reprint'),
        ),
      );
      await tester.pumpAndSettle();

      expect(remote.checkouts, hasLength(2));
      expect(remote.checkouts.every((c) => c.cashUzs + c.cardUzs == 0), true);
      expect(remote.checkouts.every((c) => !c.replacePlan), true);
      expect(remote.planEntryCalls, 1);
    });
  });

  group('panel: only what the backend reports as a conflict', () {
    for (final plan in ['Standart', '1 soat']) {
      testWidgets('a live VIP pass sold $plan is a plain re-print', (
        tester,
      ) async {
        final (_, remote) = await _pumpPanel(
          tester,
          passes: [_pass('child-1', 'vip', 'VIP')],
          results: [
            const PosEntryResult(entries: [], failures: [], balance: 0),
          ],
        );
        await _selectAll(tester, plan: plan);

        expect(find.text('Continue'), findsNothing);
        expect(find.byKey(const ValueKey('pay-due')), findsNothing);
        await tester.tap(find.text('Enter (1)'));
        await tester.pumpAndSettle();
        expect(remote.checkouts.single.cashUzs, 0);
        expect(remote.checkouts.single.replacePlan, isFalse);
      });
    }

    testWidgets('a discounted live Standard pass sold VIP is handed back '
        'as-is and charged nothing', (tester) async {
      final (_, remote) = await _pumpPanel(
        tester,
        passes: [_pass('child-1', 'standard', 'Standart', discountId: 'd-1')],
        results: [const PosEntryResult(entries: [], failures: [], balance: 0)],
      );
      await _selectAll(tester);

      expect(find.text('Continue'), findsNothing);
      expect(_due(75000), findsNothing);
      await tester.tap(find.text('Enter (1)'));
      await tester.pumpAndSettle();
      final checkout = remote.checkouts.single;
      expect(checkout.cashUzs + checkout.cardUzs, 0);
      expect(checkout.replacePlan, isFalse);
    });

    testWidgets('siblings: the modal collects only the switching child\'s '
        'surcharge, never the as-is pass', (tester) async {
      final (_, remote) = await _pumpPanel(
        tester,
        secondChild: true,
        passes: [
          _pass('child-1', 'standard', 'Standart'),
          _pass('child-2', 'standard', 'Standart', discountId: 'd-1'),
        ],
        results: [
          const PosEntryResult(
            entries: [],
            failures: [],
            conflicts: [
              PosEntryConflict(
                childId: 'child-1',
                currentPlanKey: 'standard',
                currentPlanLabel: 'Standart',
                requestedPlanKey: 'vip',
                isInside: false,
                accruedDueUzs: 0,
                switchable: true,
                upgradeCreditUzs: 5000,
                upgradeDueUzs: 70000,
              ),
            ],
            balance: 0,
          ),
          const PosEntryResult(entries: [], failures: [], balance: 0),
        ],
      );
      await _selectAll(tester, secondChild: true);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(remote.checkouts.single.cashUzs, 0);
      expect(_collect(70000), findsOneWidget);

      await tester.tap(find.text("Switch and print · 70 000 so'm"));
      await tester.pumpAndSettle();
      final retry = remote.checkouts[1];
      expect(retry.replacePlan, isTrue);
      expect(retry.childIds, ['child-1', 'child-2']);
      expect(retry.cashUzs, 70000);
      expect(retry.cardUzs, 0);
    });
  });

  group('planSwitchDueUzs', () {
    test('the quoted surcharge plus accrued time', () {
      expect(planSwitchDueUzs(const [_upgradeConflict]), 15000);
      expect(
        planSwitchDueUzs(const [
          PosEntryConflict(
            childId: 'c',
            currentPlanKey: 'standard',
            currentPlanLabel: 'Standart',
            requestedPlanKey: 'vip',
            isInside: true,
            accruedDueUzs: 4000,
            switchable: true,
            upgradeCreditUzs: 10000,
            upgradeDueUzs: 65000,
          ),
        ]),
        69000,
      );
    });

    test('a discounted upgrade is capped at its discounted price − credit', () {
      // VIP 75 000 − 30% = 52 500 < the 60 000 the hour pass paid.
      expect(
        planSwitchDueUzs(
          const [_upgradeConflict],
          netFlatByChild: const {'child-1': 52500},
        ),
        0,
      );
      expect(
        planSwitchDueUzs(
          const [_upgradeConflict],
          netFlatByChild: const {'child-1': 75000},
        ),
        15000,
      );
    });

    test('older backends (no surcharge) charge the whole new price', () {
      const legacy = PosEntryConflict(
        childId: 'child-1',
        currentPlanKey: 'hour',
        currentPlanLabel: '1 soat',
        requestedPlanKey: 'vip',
        isInside: false,
        accruedDueUzs: 0,
        switchable: true,
      );
      expect(
        planSwitchDueUzs(const [legacy], requestedPlanFlatUzs: 75000),
        75000,
      );
    });

    test('a refused downgrade costs nothing', () {
      const downgrade = PosEntryConflict(
        childId: 'child-1',
        currentPlanKey: 'vip',
        currentPlanLabel: 'VIP',
        requestedPlanKey: 'hour',
        isInside: false,
        accruedDueUzs: 0,
        switchable: false,
      );
      expect(planSwitchDueUzs(const [downgrade]), 0);
    });
  });

  test('checkoutCollectUzs mirrors the panel split', () {
    expect(
      checkoutCollectUzs(neededUzs: 15000, balanceUzs: 0, payFromBalance: true),
      15000,
    );
    expect(
      checkoutCollectUzs(
        neededUzs: 15000,
        balanceUzs: 5000,
        payFromBalance: true,
      ),
      10000,
    );
    expect(
      checkoutCollectUzs(
        neededUzs: 15000,
        balanceUzs: 20000,
        payFromBalance: true,
      ),
      0,
    );
    expect(
      checkoutCollectUzs(
        neededUzs: 15000,
        balanceUzs: 20000,
        payFromBalance: false,
      ),
      15000,
    );
    expect(
      checkoutCollectUzs(neededUzs: 0, balanceUzs: 0, payFromBalance: true),
      0,
    );
  });

  group('upgrade ticket', () {
    test('names the new plan with an ASCII-safe separator', () {
      expect(upgradeTicketPlanName('VIP'), 'UPGRADE - VIP');
      expect(upgradeTicketPlanName(null), 'UPGRADE');
      expect(upgradeTicketPlanName(''), 'UPGRADE');
      expect(
        ChildTicketPrinter.asciiText(upgradeTicketPlanName('VIP')),
        'UPGRADE - VIP',
      );
    });
  });
}
