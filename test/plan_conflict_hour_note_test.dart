import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/pos_entry.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/plan_conflict_dialog.dart';
import 'package:cashier_app/generated/l10n.dart';

class _FakeRemote implements PosAccountRemoteDataSource {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _note = '1 soat tarif puli qaytarilmaydi.';

PosEntryConflict _conflict({
  required String current,
  required String label,
  required String requested,
  required bool switchable,
}) => PosEntryConflict(
  childId: 'child-1',
  currentPlanKey: current,
  currentPlanLabel: label,
  requestedPlanKey: requested,
  isInside: false,
  accruedDueUzs: 0,
  switchable: switchable,
);

Future<void> _open(
  WidgetTester tester,
  PosEntryConflict conflict, {
  required String requestedPlanName,
  int? requestedPlanFlatUzs,
}) async {
  final bloc = PosAccountBloc(PosAccountRepository(_FakeRemote()));
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
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPlanConflictDialog(
                context,
                conflicts: [conflict],
                childNamesById: const {'child-1': 'Aziza'},
                requestedPlanName: requestedPlanName,
                requestedPlanFlatUzs: requestedPlanFlatUzs,
                hourPlanKeys: const {'hour'},
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
}

void main() {
  testWidgets('live 1 soat → VIP says the hour price is not refunded', (
    tester,
  ) async {
    await _open(
      tester,
      _conflict(
        current: 'hour',
        label: '1 soat',
        requested: 'vip',
        switchable: true,
      ),
      requestedPlanName: 'VIP',
      requestedPlanFlatUzs: 75000,
    );

    expect(find.textContaining(_note), findsOneWidget);
    // The VIP prepay question is still there, unchanged.
    expect(find.textContaining("VIP narxi (75 000 so'm)"), findsOneWidget);
  });

  testWidgets('Standart → VIP has no hour note', (tester) async {
    await _open(
      tester,
      _conflict(
        current: 'standard',
        label: 'Standart',
        requested: 'vip',
        switchable: true,
      ),
      requestedPlanName: 'VIP',
      requestedPlanFlatUzs: 75000,
    );

    expect(find.textContaining(_note), findsNothing);
  });

  testWidgets('a refused 1 soat → Standart switch has no hour note', (
    tester,
  ) async {
    await _open(
      tester,
      _conflict(
        current: 'hour',
        label: '1 soat',
        requested: 'standard',
        switchable: false,
      ),
      requestedPlanName: 'Standart',
    );

    expect(find.textContaining(_note), findsNothing);
  });

  testWidgets('a refused Standart → 1 soat switch has no hour note', (
    tester,
  ) async {
    await _open(
      tester,
      _conflict(
        current: 'standard',
        label: 'Standart',
        requested: 'hour',
        switchable: false,
      ),
      requestedPlanName: '1 soat',
    );

    expect(find.textContaining(_note), findsNothing);
  });
}
