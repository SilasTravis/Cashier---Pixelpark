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
  _FakeRemote({this.activePasses = const [], this.checkoutResult});

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
      flatUzs: 50000,
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

Future<PosAccountBloc> _pumpPanel(
  WidgetTester tester, {
  int balance = 0,
  List<ActivePass> activePasses = const [],
  PosEntryResult? checkoutResult,
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
void main() {
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
