import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _FakeRemote implements PosAccountRemoteDataSource {
  _FakeRemote({
    this.activePasses = const [],
    this.checkoutResult,
    this.extraPlans = const [],
  });

  final List<KidsPlan> extraPlans;

  final List<ActivePass> activePasses;
  final PosEntryResult? checkoutResult;

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
  }) async => checkoutResult!;

  @override
  Future<List<KidsPlan>> listPlans() async => [
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
      flatUzs: 50000,
      durationMinutes: 60,
    ),
    ...extraPlans,
  ];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async =>
      activePasses;

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<PosAccountBloc> _pumpPanel(
  WidgetTester tester, {
  int balance = 0,
  List<ActivePass> activePasses = const [],
  PosEntryResult? checkoutResult,
  List<KidsPlan> extraPlans = const [],
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final bloc =
      PosAccountBloc(
          PosAccountRepository(
            _FakeRemote(
              activePasses: activePasses,
              checkoutResult: checkoutResult,
              extraPlans: extraPlans,
            ),
          ),
        )
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
  return bloc;
}

Future<void> _pickChildAndPlan(WidgetTester tester, String planName) async {
  await tester.tap(find.text('QR'));
  await tester.pump();
  await tester.tap(find.text(planName));
  await tester.pumpAndSettle();
}

// The test MaterialApp resolves to the first supported locale (en), so the
// copy asserted below is the English ARB text.
const _birthday = KidsPlan(
  key: 'c-ab12',
  name: 'Birthday 90 min',
  kind: KidsPlanKind.flatHour,
  firstMinuteUzs: null,
  secondMinuteUzs: null,
  extraMinuteUzs: null,
  flatUzs: 120000,
  durationMinutes: 90,
  isVip: true,
);
const _short = KidsPlan(
  key: 'c-cd34',
  name: 'Quick 30',
  kind: KidsPlanKind.flatHour,
  firstMinuteUzs: null,
  secondMinuteUzs: null,
  extraMinuteUzs: null,
  flatUzs: 30000,
  durationMinutes: 30,
);

const _weekend = KidsPlan(
  key: 'c-ef56',
  name: 'Weekend pass',
  kind: KidsPlanKind.flatDay,
  firstMinuteUzs: null,
  secondMinuteUzs: null,
  extraMinuteUzs: null,
  flatUzs: 150000,
  isVip: true,
);

void _multiDayTests() {
  testWidgets('a custom day plan gets its own pill, name, price and badge', (
    tester,
  ) async {
    await _pumpPanel(tester, extraPlans: [_weekend]);

    expect(find.text('Weekend pass'), findsOneWidget);
    expect(find.text("150 000 so'm / day"), findsOneWidget);
    expect(find.text("75 000 so'm / day"), findsOneWidget);
    // Built-in VIP pill + the custom plan's VIP badge.
    expect(find.text('VIP'), findsNWidgets(2));
  });

  testWidgets('selling a custom day plan charges its price and name', (
    tester,
  ) async {
    await _pumpPanel(tester, extraPlans: [_weekend]);

    await _pickChildAndPlan(tester, 'Weekend pass');

    expect(find.widgetWithText(TextField, '150000'), findsOneWidget);
    expect(
      find.text(
        'The «Weekend pass» tariff is debited from the balance immediately when printed.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'The VIP tariff is debited from the balance immediately when printed.',
      ),
      findsNothing,
    );
  });

  testWidgets('a live custom day pass is not charged again for itself', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      extraPlans: [_weekend],
      activePasses: [_livePass('c-ef56', 'Weekend pass', 150000)],
    );

    await _pickChildAndPlan(tester, 'Weekend pass');

    expect(find.widgetWithText(TextField, '150000'), findsNothing);
    expect(
      find.text(
        '«Aziza» already has an active «Weekend pass» tariff — no second charge.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a live custom day pass covers a 1 soat sale', (tester) async {
    await _pumpPanel(
      tester,
      extraPlans: [_weekend],
      activePasses: [_livePass('c-ef56', 'Weekend pass', 150000)],
    );

    await _pickChildAndPlan(tester, '1 soat');

    expect(find.widgetWithText(TextField, '50000'), findsNothing);
    expect(
      find.text(
        '«Aziza» already has an active «Weekend pass» tariff — no second charge.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a live VIP-flagged hour plan covers a 1 soat sale', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      extraPlans: [_birthday],
      activePasses: [_livePass('c-ab12', 'Birthday 90 min', 120000)],
    );

    await _pickChildAndPlan(tester, '1 soat');

    expect(find.widgetWithText(TextField, '50000'), findsNothing);
  });

  testWidgets('a live non-VIP custom hour pass does not cover a 1 soat sale', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      extraPlans: [_short],
      activePasses: [_livePass('c-cd34', 'Quick 30', 30000)],
    );

    await _pickChildAndPlan(tester, '1 soat');

    expect(find.widgetWithText(TextField, '50000'), findsOneWidget);
  });

  testWidgets('a live built-in VIP is still charged when selling the custom '
      'day plan', (tester) async {
    await _pumpPanel(
      tester,
      extraPlans: [_weekend],
      activePasses: [_livePass('vip', 'VIP', 75000)],
    );

    await _pickChildAndPlan(tester, 'Weekend pass');

    expect(find.widgetWithText(TextField, '150000'), findsOneWidget);
  });
}

void main() {
  _multiDayTests();
  testWidgets('custom plans each get a pill with duration, price, VIP badge', (
    tester,
  ) async {
    await _pumpPanel(tester, extraPlans: [_birthday, _short]);

    expect(find.text('Birthday 90 min'), findsOneWidget);
    expect(find.text("90 min · 120 000 so'm"), findsOneWidget);
    expect(find.text('Quick 30'), findsOneWidget);
    expect(find.text("30 min · 30 000 so'm"), findsOneWidget);
    // Only the VIP-flagged custom plan carries a badge (plus the VIP plan).
    expect(find.text('VIP'), findsNWidgets(2));
    // Built-in pills unchanged.
    expect(find.text("50 000 so'm / hour"), findsOneWidget);
  });

  testWidgets('a custom plan is prepaid and labelled by its own name', (
    tester,
  ) async {
    await _pumpPanel(tester, extraPlans: [_short]);

    await _pickChildAndPlan(tester, 'Quick 30');

    expect(find.widgetWithText(TextField, '30000'), findsOneWidget);
    expect(
      find.text(
        'The «Quick 30» tariff is debited from the balance immediately when printed.',
      ),
      findsOneWidget,
    );
    expect(find.text('1 hour tariff'), findsNothing);
  });

  testWidgets('shows a third "1 soat" pill next to the unchanged two', (
    tester,
  ) async {
    await _pumpPanel(tester);

    expect(find.text('1 soat'), findsOneWidget);
    expect(find.text('Standart'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
  });

  testWidgets('the hour pill shows its flat price per hour', (tester) async {
    await _pumpPanel(tester);

    expect(find.text("50 000 so'm / hour"), findsOneWidget);
    // VIP and Standard price lines are unchanged.
    expect(find.text("75 000 so'm / day"), findsOneWidget);
    expect(find.text("from 1 000 so'm / min"), findsOneWidget);
  });

  testWidgets('the hour plan is prepaid: its price is required up front', (
    tester,
  ) async {
    await _pumpPanel(tester);

    await _pickChildAndPlan(tester, '1 soat');

    expect(find.widgetWithText(TextField, '50000'), findsOneWidget);
    // Prepaid: no "nothing is paid now" Standard note.
    expect(find.text(AppLocalization.current.noPaymentNow), findsNothing);
  });

  testWidgets('the hour total is labelled as the hour tariff, not VIP', (
    tester,
  ) async {
    await _pumpPanel(tester);

    await _pickChildAndPlan(tester, '1 soat');

    expect(
      find.text(
        'The 1 hour tariff is debited from the balance immediately when printed.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'The VIP tariff is debited from the balance immediately when printed.',
      ),
      findsNothing,
    );
  });

  testWidgets('VIP keeps its own wording', (tester) async {
    await _pumpPanel(tester);

    await _pickChildAndPlan(tester, 'VIP');

    expect(
      find.text(
        'The VIP tariff is debited from the balance immediately when printed.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a child with a live hour pass is not charged again', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      activePasses: [
        ActivePass(
          childId: 'child-1',
          planKey: 'hour',
          planLabel: '1 soat',
          expiresAt: DateTime.now().add(const Duration(minutes: 30)),
          dueTodayUzs: 50000,
        ),
      ],
    );

    await _pickChildAndPlan(tester, '1 soat');

    expect(find.widgetWithText(TextField, '50000'), findsNothing);
    expect(
      find.text(
        '«Aziza» already has an active 1 hour tariff — no second charge.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a child on a live VIP pass sold 1 soat is not charged', (
    tester,
  ) async {
    // Spec decision 7: VIP → hour re-prints the VIP sticker, no charge.
    await _pumpPanel(tester, activePasses: [_livePass('vip', 'VIP', 75000)]);

    await _pickChildAndPlan(tester, '1 soat');

    expect(find.widgetWithText(TextField, '50000'), findsNothing);
    expect(
      find.text('«Aziza» already has an active VIP tariff — no second charge.'),
      findsOneWidget,
    );
    expect(
      find.text(
        '«Aziza» already has an active 1 hour tariff — no second charge.',
      ),
      findsNothing,
    );
  });

  testWidgets('a child on a live VIP pass sold VIP keeps today\'s note', (
    tester,
  ) async {
    await _pumpPanel(tester, activePasses: [_livePass('vip', 'VIP', 75000)]);

    await _pickChildAndPlan(tester, 'VIP');

    expect(find.widgetWithText(TextField, '75000'), findsNothing);
    expect(
      find.text('«Aziza» already has an active VIP tariff — no second charge.'),
      findsOneWidget,
    );
  });

  testWidgets('a child on a live 1 soat pass sold VIP is still charged', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      activePasses: [_livePass('hour', '1 soat', 50000)],
    );

    await _pickChildAndPlan(tester, 'VIP');

    expect(find.widgetWithText(TextField, '75000'), findsOneWidget);
  });

  testWidgets('the hour → VIP conflict from the panel says no refund', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      activePasses: [_livePass('hour', '1 soat', 50000)],
      checkoutResult: const PosEntryResult(
        entries: [],
        failures: [],
        conflicts: [
          PosEntryConflict(
            childId: 'child-1',
            currentPlanKey: 'hour',
            currentPlanLabel: '1 soat',
            requestedPlanKey: 'vip',
            isInside: false,
            accruedDueUzs: 0,
            switchable: true,
          ),
        ],
      ),
    );

    await _pickChildAndPlan(tester, 'VIP');
    await tester.tap(find.text('Pay and print'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The 1 hour tariff price is not refunded.'),
      findsOneWidget,
    );
  });

  testWidgets('the Standart → VIP conflict from the panel has no hour note', (
    tester,
  ) async {
    await _pumpPanel(
      tester,
      activePasses: [_livePass('standard', 'Standart', 0)],
      checkoutResult: const PosEntryResult(
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
          ),
        ],
      ),
    );

    await _pickChildAndPlan(tester, 'VIP');
    await tester.tap(find.text('Pay and print'));
    await tester.pumpAndSettle();

    // The dialog is up (VIP prepay question) but without the hour note.
    expect(find.textContaining('75 000'), findsWidgets);
    expect(
      find.textContaining('The 1 hour tariff price is not refunded.'),
      findsNothing,
    );
  });
}

ActivePass _livePass(String planKey, String label, int dueTodayUzs) =>
    ActivePass(
      childId: 'child-1',
      planKey: planKey,
      planLabel: label,
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      dueTodayUzs: dueTodayUzs,
    );
