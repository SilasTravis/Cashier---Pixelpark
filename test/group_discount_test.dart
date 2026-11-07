import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/kids_plan.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_detail_panel.dart';
import 'package:cashier_app/core/utils/currency.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';

class _FakeRemote implements PosAccountRemoteDataSource {
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
  Future<List<Discount>> fetchDiscounts({
    DiscountScope scope = DiscountScope.goods,
  }) async => scope == DiscountScope.entry
      ? const [
          Discount(
            id: 'disc-free',
            name: 'Nogiron bola',
            kind: DiscountKind.percent,
            value: 100,
            scope: DiscountScope.entry,
          ),
          Discount(
            id: 'disc-partial',
            name: 'Flayer 30%',
            kind: DiscountKind.percent,
            value: 30,
            scope: DiscountScope.entry,
          ),
        ]
      : const [];

  @override
  Future<List<Child>> ensureGroupSeats({
    required int customerId,
    required int count,
  }) async => [
    for (var i = 1; i <= count; i++)
      Child(
        id: 'seat-$i',
        firstName: 'Guruh',
        lastName: '$i',
        birthDate: DateTime(2018, 1, 1),
        groupSeat: i,
      ),
  ];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<PosAccountBloc> _pumpPanel(WidgetTester tester) async {
  // The panel is a desktop two-column layout — give it desktop room.
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final bloc = PosAccountBloc(PosAccountRepository(_FakeRemote()))
    ..add(const PosAccountPlansRequested())
    ..add(const PosAccountDiscountsRequested(scope: DiscountScope.entry))
    ..add(
      PosAccountCustomerSelected(
        Customer(
          id: 7,
          phoneNumber: '+998901234567',
          firstName: 'Dil',
          lastName: null,
          balance: 0,
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

  // The test font (Ahem) is far wider than the real one, so the count
  // dialog's button row overflows here; that is not what is under test.
  final onError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    onError?.call(details);
  };
  addTearDown(() => FlutterError.onError = onError);

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
      home: BlocProvider.value(
        value: bloc,
        child: const Scaffold(
          body: SingleChildScrollView(child: CustomerDetailPanel()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return bloc;
}

Future<void> _pickGroup(WidgetTester tester, int count) async {
  await tester.tap(find.text("Ko'proq"));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Guruh (maktab)'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
    '$count',
  );
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _pickDiscount(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('group-discount-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

String _due(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('pay-due'))).data!;

void main() {
  // VIP is a flat 75 000 so'm per seat; 'Flayer 30%' takes 22 500 off each.
  for (final count in [99, 100, 101]) {
    testWidgets('a group of $count kids takes an entry discount per seat', (
      tester,
    ) async {
      await _pumpPanel(tester);
      await _pickGroup(tester, count);
      await tester.tap(find.text('VIP'));
      await tester.pumpAndSettle();

      expect(_due(tester), formatUzs(count * 75000));

      await _pickDiscount(tester, 'Flayer 30%');
      expect(_due(tester), formatUzs(count * (75000 - 22500)));

      // A new count keeps the group's discount.
      await _pickGroup(tester, count + 1);
      expect(_due(tester), formatUzs((count + 1) * (75000 - 22500)));
    });
  }

  testWidgets('a free group discount leaves nothing to collect', (
    tester,
  ) async {
    await _pumpPanel(tester);
    await _pickGroup(tester, 100);
    await tester.tap(find.text('VIP'));
    await tester.pumpAndSettle();
    await _pickDiscount(tester, 'Nogiron bola');
    // Nothing to collect: no amount-to-pay row at all.
    expect(find.byKey(const ValueKey('pay-due')), findsNothing);
  });
}
