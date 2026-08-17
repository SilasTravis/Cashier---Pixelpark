import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/kids_plan.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_detail_panel.dart';

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
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'payment amount is prefilled with the required total when balance is off',
    (tester) async {
      // The panel is a desktop two-column layout — give it desktop room.
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final bloc = PosAccountBloc(PosAccountRepository(_FakeRemote()))
        ..add(const PosAccountPlansRequested())
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
          home: BlocProvider.value(
            value: bloc,
            child: const Scaffold(body: CustomerDetailPanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select the child and the VIP tariff: 75 000 is now required, and
      // the zero balance cannot cover it.
      await tester.tap(find.text('QR'));
      await tester.pump();
      await tester.tap(find.text('VIP'));
      await tester.pumpAndSettle();

      // The payment field must arrive prefilled with the required sum.
      expect(find.widgetWithText(TextField, '75000'), findsOneWidget);
    },
  );
}
