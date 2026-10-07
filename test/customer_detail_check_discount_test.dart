import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/utils/currency.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/kids_plan.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/domain/pos_entry.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_detail_panel.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';

class _FakeRemote implements PosAccountRemoteDataSource {
  String? lastCheckDiscountId;
  Map<String, String>? lastEntryDiscounts;
  ({String code, String childId})? lastPromoCode;
  List<String>? lastChildIds;
  int checkoutCalls = 0;

  @override
  Future<PosEntryResult> planEntryCheckout({
    required int customerId,
    required String planKey,
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
    checkoutCalls++;
    lastCheckDiscountId = checkDiscountId;
    lastEntryDiscounts = entryDiscounts;
    lastPromoCode = promoCode;
    lastChildIds = childIds;
    return const PosEntryResult(entries: [], failures: [], conflicts: []);
  }

  @override
  Future<List<Discount>> fetchDiscounts({
    DiscountScope scope = DiscountScope.goods,
  }) async => switch (scope) {
    DiscountScope.check => const [
      Discount(
        id: 'c-fixed',
        name: 'Aksiya',
        kind: DiscountKind.fixed,
        value: 30000,
        scope: DiscountScope.check,
      ),
      Discount(
        id: 'c-pct',
        name: 'Oila',
        kind: DiscountKind.percent,
        value: 10,
        scope: DiscountScope.check,
      ),
    ],
    DiscountScope.entry => const [
      Discount(
        id: 'e-free',
        name: "Tug'ilgan kun",
        kind: DiscountKind.percent,
        value: 100,
        scope: DiscountScope.entry,
      ),
    ],
    DiscountScope.goods => const [],
  };

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
      flatUzs: 100000,
    ),
  ];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => const [];

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late _FakeRemote _remote;

/// Children in render order — `QR` buttons are found by this index.
const _childIds = ['k1', 'k2'];

Future<void> pumpPanel(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  _remote = _FakeRemote();
  final bloc = PosAccountBloc(PosAccountRepository(_remote))
    ..add(const PosAccountPlansRequested())
    ..add(const PosAccountDiscountsRequested(scope: DiscountScope.entry))
    ..add(const PosAccountDiscountsRequested(scope: DiscountScope.check))
    ..add(
      PosAccountCustomerSelected(
        Customer(
          id: 7,
          phoneNumber: '+998901234567',
          firstName: 'Dil',
          lastName: null,
          balance: 1000000,
          children: [
            Child(
              id: 'k1',
              firstName: 'Ali',
              lastName: null,
              birthDate: DateTime(2018, 1, 1),
            ),
            Child(
              id: 'k2',
              firstName: 'Vali',
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
}

Future<void> tapChildRow(WidgetTester tester, String childId) async {
  await tester.tap(find.text('QR').at(_childIds.indexOf(childId)));
  await tester.pump();
}

Future<void> selectChildrenAndPlan(
  WidgetTester tester,
  List<String> childIds,
  String planName,
) async {
  for (final id in childIds) {
    await tapChildRow(tester, id);
  }
  await tester.tap(find.text(planName));
  await tester.pumpAndSettle();
}

// The test MaterialApp resolves to the first supported locale (en), so the
// copy below is the English ARB text ("Chek chegirmasi" → "Check discount",
// "Chegirmasiz" → "No discount").
const _checkDiscount = 'Check discount';
const _noDiscount = 'No discount';
const _locked =
    'Check discount selected — child discounts and promo code are off';
const _payAndPrint = 'Pay and print';

Future<void> pickCheckDiscount(WidgetTester tester, String name) async {
  await tester.tap(find.text(_checkDiscount));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a fixed check discount nets the VIP total and is sent', (
    tester,
  ) async {
    await pumpPanel(tester);
    await selectChildrenAndPlan(tester, ['k1', 'k2'], 'VIP');

    await pickCheckDiscount(tester, 'Aksiya');

    expect(find.textContaining('Aksiya'), findsWidgets);
    expect(find.text(formatUzs(-30000)), findsOneWidget);
    expect(find.text(formatUzs(170000)), findsWidgets);

    await tester.tap(find.text(_payAndPrint));
    await tester.pumpAndSettle();
    expect(_remote.checkoutCalls, 1);
    expect(_remote.lastCheckDiscountId, 'c-fixed');
    expect(_remote.lastEntryDiscounts, isEmpty);
    expect(_remote.lastPromoCode, isNull);
    expect(_remote.lastChildIds, ['k1', 'k2']);
  });

  testWidgets('dropping a child recomputes the shares', (tester) async {
    await pumpPanel(tester);
    await selectChildrenAndPlan(tester, ['k1', 'k2'], 'VIP');
    await pickCheckDiscount(tester, 'Aksiya');

    await tapChildRow(tester, 'k2'); // deselect
    await tester.pumpAndSettle();
    // one child: the whole 30 000 on k1 → 100 000 − 30 000
    expect(find.text(formatUzs(70000)), findsWidgets);
  });

  testWidgets('Chegirmasiz clears the pick', (tester) async {
    await pumpPanel(tester);
    await selectChildrenAndPlan(tester, ['k1'], 'VIP');
    await pickCheckDiscount(tester, 'Oila');
    expect(find.text(formatUzs(-10000)), findsOneWidget);

    await pickCheckDiscount(tester, _noDiscount);

    expect(find.text(formatUzs(-10000)), findsNothing);
    await tester.tap(find.text(_payAndPrint));
    await tester.pumpAndSettle();
    expect(_remote.checkoutCalls, 1);
    expect(_remote.lastCheckDiscountId, isNull);
    expect(_remote.lastChildIds, ['k1']);
  });

  testWidgets('a check discount hides the per-child menu and the promo field', (
    tester,
  ) async {
    await pumpPanel(tester);
    await selectChildrenAndPlan(tester, ['k1'], 'VIP');
    expect(find.byType(PopupMenuButton<Object>), findsWidgets);

    await pickCheckDiscount(tester, 'Oila');

    expect(find.byType(PopupMenuButton<Object>), findsNothing);
    expect(find.text(_locked), findsOneWidget);
  });

  testWidgets('the button stays hidden until a child is selected', (
    tester,
  ) async {
    await pumpPanel(tester);
    expect(find.text(_checkDiscount), findsNothing);

    await tapChildRow(tester, 'k1');
    await tester.pumpAndSettle();
    expect(find.text(_checkDiscount), findsOneWidget);
  });
}
