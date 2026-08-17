import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/domain/pos_entry.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/plan_conflict_dialog.dart';

class _FakeRemote implements PosAccountRemoteDataSource {
  final List<({String planKey, List<String> childIds, bool replacePlan})>
  planEntryCalls = [];

  @override
  Future<PosEntryResult> issuePlanEntry({
    required int customerId,
    required String planKey,
    required List<String> childIds,
    bool replacePlan = false,
  }) async {
    planEntryCalls.add((
      planKey: planKey,
      childIds: childIds,
      replacePlan: replacePlan,
    ));
    return const PosEntryResult(entries: [], failures: []);
  }

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => const [];

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _upgrade = PosEntryConflict(
  childId: 'child-1',
  currentPlanKey: 'standard',
  currentPlanLabel: 'Standart',
  requestedPlanKey: 'vip',
  isInside: false,
  accruedDueUzs: 0,
  switchable: true,
);

const _downgrade = PosEntryConflict(
  childId: 'child-1',
  currentPlanKey: 'vip',
  currentPlanLabel: 'VIP',
  requestedPlanKey: 'standard',
  isInside: false,
  accruedDueUzs: 0,
  switchable: false,
);

void main() {
  testWidgets('a VIP switch spells out the register prepayment', (
    tester,
  ) async {
    final remote = _FakeRemote();
    final bloc = PosAccountBloc(PosAccountRepository(remote));
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPlanConflictDialog(
                  context,
                  conflicts: const [_upgrade],
                  childNamesById: const {'child-1': 'asd'},
                  requestedPlanName: 'VIP',
                  requestedPlanFlatUzs: 75000,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("VIP narxi (75 000 so'm)"),
      findsOneWidget,
    );
  });

  testWidgets('blocked downgrade still offers re-printing the current pass', (
    tester,
  ) async {
    final remote = _FakeRemote();
    final bloc = PosAccountBloc(PosAccountRepository(remote))
      ..add(
        const PosAccountCustomerSelected(
          Customer(
            id: 7,
            phoneNumber: '+998901234567',
            firstName: 'Dil',
            lastName: null,
            balance: 0,
            children: [],
          ),
        ),
      );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPlanConflictDialog(
                  context,
                  conflicts: const [_downgrade],
                  childNamesById: const {'child-1': 'asd'},
                  requestedPlanName: 'Standart',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // No switch offered for a downgrade…
    expect(find.text('Almashtirish va chop etish'), findsNothing);
    // …but the lost-sticker case is covered: re-print the CURRENT plan.
    await tester.tap(find.text('Qayta chop etish'));
    await tester.pumpAndSettle();

    expect(remote.planEntryCalls, hasLength(1));
    final call = remote.planEntryCalls.single;
    expect(call.planKey, 'vip');
    expect(call.childIds, ['child-1']);
    expect(call.replacePlan, false);
  });
}
