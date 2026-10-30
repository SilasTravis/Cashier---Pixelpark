import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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

  final List<List<String>> quotes = [];

  @override
  Future<List<PosEntryConflict>> planSwitchQuote({
    required int customerId,
    required String planKey,
    required List<String> childIds,
  }) async {
    quotes.add(childIds);
    return const [_upgradeConflict];
  }

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

void main() {
  group('one-press upgrade: live 1 soat (60 000) → VIP (75 000)', () {
    testWidgets('the panel shows the surcharge and "Upgrade plan"', (
      tester,
    ) async {
      final (_, remote) = await _pumpPanel(tester, results: const []);
      await _selectAll(tester);

      expect(remote.quotes, [
        ['child-1'],
      ]);
      expect(_due(15000), findsOneWidget);
      expect(find.text('Upgrade plan'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(find.textContaining('surcharge: 15 000'), findsOneWidget);
    });

    testWidgets('one press sends replacePlan with the surcharge by card', (
      tester,
    ) async {
      final (_, remote) = await _pumpPanel(
        tester,
        results: [const PosEntryResult(entries: [], failures: [], balance: 0)],
      );
      await _selectAll(tester);

      await tester.tap(find.text('Card'));
      await tester.pump();
      await tester.tap(find.text('Upgrade plan'));
      await tester.pumpAndSettle();

      expect(remote.checkouts, hasLength(1));
      final sent = remote.checkouts.single;
      expect(sent.replacePlan, isTrue);
      expect(sent.planKey, 'vip');
      expect(sent.childIds, ['child-1']);
      expect(sent.cashUzs, 0);
      expect(sent.cardUzs, 15000);
      expect(remote.planEntryCalls, 0);
    });

    testWidgets('another new child pays full price plus the surcharge', (
      tester,
    ) async {
      final (_, remote) = await _pumpPanel(
        tester,
        secondChild: true,
        results: [const PosEntryResult(entries: [], failures: [], balance: 0)],
      );
      await _selectAll(tester, secondChild: true);

      expect(_due(90000), findsOneWidget);
      await tester.tap(find.text('Upgrade plan'));
      await tester.pumpAndSettle();

      final sent = remote.checkouts.single;
      expect(sent.replacePlan, isTrue);
      expect(sent.childIds, ['child-1', 'child-2']);
      expect(sent.cashUzs, 90000);
    });
  });
}
