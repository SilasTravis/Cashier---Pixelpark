import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/core/utils/currency.dart';
import 'package:cashier_app/core/widgets/payment_method_selector.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/kids_plan.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/domain/pos_entry.dart';
import 'package:cashier_app/features/pos_account/domain/subscription.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_detail_panel.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/subscription_sell_dialog.dart';

typedef _Checkout = ({
  String? planKey,
  List<String> childIds,
  List<String> subscriptionChildIds,
  int cashUzs,
  int cardUzs,
});

typedef _Sell = ({
  String childId,
  String planId,
  int cash,
  int card,
  bool useToday,
});

Customer _customer({int balance = 0}) => Customer(
  id: 7,
  phoneNumber: '+998901234567',
  firstName: 'Aziza',
  lastName: null,
  balance: balance,
  children: [
    Child(
      id: 'c-samira',
      firstName: 'Samira',
      lastName: null,
      birthDate: DateTime(2020, 1, 1),
    ),
    Child(
      id: 'c-amir',
      firstName: 'Amir',
      lastName: null,
      birthDate: DateTime(2016, 1, 1),
    ),
  ],
);

CustomerSubscription _sub({
  String childId = 'c-samira',
  bool usableToday = true,
  SubscriptionBlockedReason? blocked,
}) => CustomerSubscription(
  id: 'sub-$childId',
  childId: childId,
  name: 'VIP 5 kirish',
  level: 'day',
  entriesTotal: 5,
  entriesUsed: 2,
  entriesLeft: 3,
  status: 'active',
  limitKind: SubscriptionLimitKind.perDay,
  usableHere: true,
  usableToday: usableToday,
  blockedReason: blocked,
  activatedAt: DateTime(2026, 10, 18),
  expiresAt: DateTime(2026, 11, 17),
  kidsPlanHere: const SubscriptionKidsPlan(
    key: 'vip',
    name: 'VIP',
    priceUzs: 75000,
  ),
);

const _sellable = SellableSubscriptionPlan(
  id: 'plan-vip5',
  name: 'VIP · 5 kirish',
  level: 'day',
  entriesCount: 5,
  validityDays: 30,
  limitKind: SubscriptionLimitKind.perDay,
  priceUzs: 350000,
  kidsPlan: SubscriptionKidsPlan(key: 'vip', name: 'VIP', priceUzs: 90000),
  perEntryUzs: 70000,
  savingsPercent: 22,
);

class _FakeRemote implements PosAccountRemoteDataSource {
  _FakeRemote({this.subscriptions = const [], this.sellError});

  List<CustomerSubscription> subscriptions;
  final ServerException? sellError;
  final checkouts = <_Checkout>[];
  final sells = <_Sell>[];

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
  ];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => const [];

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  Future<List<Customer>> searchCustomers(String query, {int page = 1}) async =>
      [_customer()];

  @override
  Future<List<CustomerSubscription>> listCustomerSubscriptions(
    int customerId,
  ) async => subscriptions;

  @override
  Future<List<SellableSubscriptionPlan>> listSellableSubscriptions() async =>
      const [_sellable];

  @override
  Future<SubscriptionSaleResult> sellSubscription({
    required int customerId,
    required String childId,
    required String subscriptionPlanId,
    required int topupCashUzs,
    required int topupCardUzs,
    required bool useToday,
  }) async {
    sells.add((
      childId: childId,
      planId: subscriptionPlanId,
      cash: topupCashUzs,
      card: topupCardUzs,
      useToday: useToday,
    ));
    if (sellError != null) throw sellError!;
    final sold = _sub(childId: childId);
    subscriptions = [...subscriptions, sold];
    return SubscriptionSaleResult(
      subscription: sold,
      balance: 0,
      receipt: SubscriptionSaleReceipt(
        createdAt: DateTime(2026, 10, 18, 15, 42),
        priceUzs: 350000,
        balanceUzs: 185000,
        cashUzs: topupCashUzs,
        cardUzs: topupCardUzs,
      ),
    );
  }

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
      subscriptionChildIds: subscriptionChildIds,
      cashUzs: cashUzs,
      cardUzs: cardUzs,
    ));
    return const PosEntryResult(entries: [], failures: []);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRemote> _pump(
  WidgetTester tester, {
  List<CustomerSubscription> subscriptions = const [],
  int balance = 0,
  ServerException? sellError,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final remote = _FakeRemote(
    subscriptions: subscriptions,
    sellError: sellError,
  );
  final bloc = PosAccountBloc(PosAccountRepository(remote))
    ..add(const PosAccountPlansRequested())
    ..add(PosAccountCustomerSelected(_customer(balance: balance)));
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
  return remote;
}

Future<void> _tapChild(WidgetTester tester, String name) async {
  // The name itself is tap-to-rename; the tile's checkbox selects.
  final index = name == 'Samira' ? 0 : 1;
  await tester.tap(find.byKey(const ValueKey('child-select')).at(index));
  await tester.pump();
}

Future<void> _submitCheckout(WidgetTester tester) async {
  final button = find.ancestor(
    of: find.textContaining('Enter ('),
    matching: find.byType(FilledButton),
  );
  final pay = find.ancestor(
    of: find.text('Pay and print'),
    matching: find.byType(FilledButton),
  );
  await tester.tap(button.evaluate().isNotEmpty ? button : pay);
  await tester.pumpAndSettle();
}

void main() {
  group('SubscriptionPayment (same split as the checkout)', () {
    test('balance first, shortfall collected, split over cash/card', () {
      final p = SubscriptionPayment.compute(
        priceUzs: 350000,
        balanceUzs: 185000,
        payFromBalance: true,
        method: PaymentMethod.split,
        cashInput: '100 000',
        cardInput: '65 000',
      );
      expect(p.collectUzs, 165000);
      expect(p.fromBalanceUzs, 185000);
      expect(p.topupCashUzs, 100000);
      expect(p.topupCardUzs, 65000);
      expect(p.isValid, isTrue);
    });

    test('a split that does not add up is not submittable', () {
      final p = SubscriptionPayment.compute(
        priceUzs: 350000,
        balanceUzs: 185000,
        payFromBalance: true,
        method: PaymentMethod.split,
        cashInput: '100 000',
        cardInput: '10 000',
      );
      expect(p.isValid, isFalse);
    });

    test('balance covers it: nothing collected', () {
      final p = SubscriptionPayment.compute(
        priceUzs: 350000,
        balanceUzs: 400000,
        payFromBalance: true,
        method: PaymentMethod.card,
      );
      expect(p.collectUzs, 0);
      expect(p.topupCashUzs + p.topupCardUzs, 0);
      expect(p.fromBalanceUzs, 350000);
      expect(p.isValid, isTrue);
    });

    test('"Balansdan yechish" off collects the whole price', () {
      final p = SubscriptionPayment.compute(
        priceUzs: 350000,
        balanceUzs: 400000,
        payFromBalance: false,
        method: PaymentMethod.card,
      );
      expect(p.collectUzs, 350000);
      expect(p.topupCardUzs, 350000);
      expect(p.fromBalanceUzs, 0);
    });

    test('no balance: everything in cash', () {
      final p = SubscriptionPayment.compute(
        priceUzs: 350000,
        balanceUzs: 0,
        payFromBalance: true,
        method: PaymentMethod.cash,
      );
      expect(p.topupCashUzs, 350000);
      expect(p.isValid, isTrue);
    });
  });

  group('customer page', () {
    testWidgets('a regular customer gets only the top-bar button', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Sell subscription'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('subscription-badge-c-samira')),
        findsNothing,
      );
      await _tapChild(tester, 'Samira');
      expect(
        find.byKey(const ValueKey('subscription-tariff-hint')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('subscription-checkout-block')),
        findsNothing,
      );
    });

    testWidgets('subscription-only entry: no tariff, 0 so\'m, ids sent', (
      tester,
    ) async {
      final remote = await _pump(tester, subscriptions: [_sub()]);
      expect(find.text('VIP 5 kirish · 3/5 left'), findsOneWidget);
      expect(find.text('until 16.11.2026 · free today'), findsOneWidget);

      await _tapChild(tester, 'Samira');
      expect(
        find.text("Samira — on subscription (0 so'm). No tariff needed."),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('subscription-checkout-block')),
        findsOneWidget,
      );
      expect(find.textContaining('Samira 3 → 2 left'), findsOneWidget);

      await _submitCheckout(tester);
      final sent = remote.checkouts.single;
      expect(sent.planKey, isNull);
      expect(sent.childIds, ['c-samira']);
      expect(sent.subscriptionChildIds, ['c-samira']);
      expect(sent.cashUzs, 0);
    });

    testWidgets('mixed: the tariff and the price are only for the others', (
      tester,
    ) async {
      final remote = await _pump(tester, subscriptions: [_sub()]);
      await _tapChild(tester, 'Samira');
      await _tapChild(tester, 'Amir');
      expect(
        find.text("Samira — on subscription (0 so'm). Tariff only for: Amir."),
        findsOneWidget,
      );
      await tester.tap(find.text('VIP').last);
      await tester.pumpAndSettle();
      // Only Amir's VIP is collected.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.key == const ValueKey('pay-due') &&
              w.data == formatUzs(75000),
        ),
        findsOneWidget,
      );
      await _submitCheckout(tester);
      final sent = remote.checkouts.single;
      expect(sent.planKey, 'vip');
      expect(sent.childIds, ['c-amir', 'c-samira']);
      expect(sent.subscriptionChildIds, ['c-samira']);
      expect(sent.cashUzs, 75000);
    });

    testWidgets('"Sell without subscription" turns it off for the stop', (
      tester,
    ) async {
      final remote = await _pump(tester, subscriptions: [_sub()]);
      await _tapChild(tester, 'Samira');
      await tester.tap(find.byKey(const ValueKey('subscription-skip-toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('subscription-checkout-block')),
        findsNothing,
      );
      await tester.tap(find.text('VIP').last);
      await tester.pumpAndSettle();
      await _submitCheckout(tester);
      final sent = remote.checkouts.single;
      expect(sent.planKey, 'vip');
      expect(sent.subscriptionChildIds, isEmpty);
    });

    testWidgets('a subscription used today is greyed with its reason', (
      tester,
    ) async {
      final remote = await _pump(
        tester,
        subscriptions: [
          _sub(
            usableToday: false,
            blocked: SubscriptionBlockedReason.usedToday,
          ),
        ],
      );
      expect(find.text('used today'), findsOneWidget);
      await _tapChild(tester, 'Samira');
      expect(
        find.byKey(const ValueKey('subscription-checkout-block')),
        findsNothing,
      );
      await tester.tap(find.text('VIP').last);
      await tester.pumpAndSettle();
      await _submitCheckout(tester);
      expect(remote.checkouts.single.subscriptionChildIds, isEmpty);
    });
  });

  group('sell modal', () {
    testWidgets('balance + split payment posts the computed top-up', (
      tester,
    ) async {
      final remote = await _pump(
        tester,
        balance: 185000,
        subscriptions: [_sub(childId: 'c-amir')],
      );
      await tester.tap(find.text('Sell subscription'));
      await tester.pumpAndSettle();

      // Amir already has one: disabled with "has · 3/5".
      expect(find.text('has · 3/5'), findsOneWidget);
      expect(find.text('VIP · 5 kirish'), findsOneWidget);
      expect(find.text('1 entry 70 000 · −22%'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.key == const ValueKey('subscription-collect') &&
              w.data == formatUzs(165000),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Split'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.first, '100000');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('subscription-sell-submit')));
      await tester.pumpAndSettle();

      expect(remote.sells.single, (
        childId: 'c-samira',
        planId: 'plan-vip5',
        cash: 100000,
        card: 65000,
        useToday: true,
      ));
      // Closed; the receipt print was attempted (no printer in tests).
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('SUBSCRIPTION_ALREADY_ACTIVE stays in the modal', (
      tester,
    ) async {
      await _pump(
        tester,
        balance: 400000,
        sellError: ServerException(
          message: 'already',
          code: 'SUBSCRIPTION_ALREADY_ACTIVE',
          statusCode: 409,
        ),
      );
      await tester.tap(find.text('Sell subscription'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('subscription-use-today')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('subscription-sell-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.text('This child already has a live subscription'),
        findsOneWidget,
      );
    });
  });
}
