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

/// Only what selecting a customer touches; anything else is a test bug.
class _EmptyRemote implements PosAccountRemoteDataSource {
  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => [];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => [
    ActivePass(
      childId: 'c1',
      planKey: 'vip',
      planLabel: 'VIP',
      expiresAt: DateTime.now().add(const Duration(hours: 3)),
      dueTodayUzs: 75000,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  // The cashier screens this app runs on go as small as ~800px wide
  // (AppConstants.minWindowWidth). On the account tab the detail panel is
  // squeezed beside the sidebar and the fixed keypad card, leaving it
  // roughly 300px — this pins the panel to that worst case so the
  // side-by-side cards stack instead of overflowing (the "broken UI on
  // the small cashier monitor" bug).
  testWidgets('customer detail panel fits the narrow 800px-window column', (
    tester,
  ) async {
    final customer = Customer(
      id: 1,
      phoneNumber: '+998901234567',
      firstName: 'Dilfuzaxon',
      lastName: 'Abdurahmonova',
      balance: 1234500,
      children: [
        Child(
          id: 'c1',
          firstName: 'Muhammadali',
          lastName: 'Abdurahmonov',
          birthDate: DateTime(2019, 5, 12),
        ),
        Child(
          id: 'c2',
          firstName: 'Zaynab',
          lastName: 'Abdurahmonova',
          birthDate: DateTime(2021, 9, 3),
        ),
      ],
    );

    final bloc = PosAccountBloc(PosAccountRepository(_EmptyRemote()));
    addTearDown(bloc.close);
    bloc
      ..emit(
        bloc.state.copyWith(
          plans: const [
            KidsPlan(
              key: 'standard',
              name: 'Standard',
              kind: KidsPlanKind.perMinuteTiers,
              firstMinuteUzs: 1000,
              secondMinuteUzs: 500,
              extraMinuteUzs: 100,
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
          ],
        ),
      )
      ..add(PosAccountCustomerSelected(customer));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: Align(
              alignment: Alignment.topLeft,
              // The panel's real width on an 800px window after the
              // sidebar, paddings, and the 240px keypad card.
              child: SizedBox(width: 300, child: const CustomerDetailPanel()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The panel rendered the selected customer...
    expect(find.text('Dilfuzaxon Abdurahmonova'), findsOneWidget);
    // ...without any layout overflow (an overflow would surface here and
    // also fail the test via FlutterError at teardown).
    expect(tester.takeException(), isNull);
  });
}
