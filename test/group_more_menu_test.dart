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

void main() {
  testWidgets(
    "the school group sits behind Ko'proq, not as a tile in the grid",
    (tester) async {
      await _pumpPanel(tester);

      expect(find.text('Guruh (maktab)'), findsNothing);
      expect(find.text("Ko'proq"), findsOneWidget);

      await tester.tap(find.text("Ko'proq"));
      await tester.pumpAndSettle();
      expect(find.text('Guruh (maktab)'), findsOneWidget);

      await tester.tap(find.text('Guruh (maktab)'));
      await tester.pumpAndSettle();
      expect(find.text('Guruh (maktab) — nechta bola?'), findsOneWidget);
    },
  );
}
