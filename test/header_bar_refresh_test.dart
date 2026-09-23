import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/features/shell/presentation/model/shell_tab.dart';
import 'package:cashier_app/features/shell/presentation/widgets/header_bar.dart';
import 'package:cashier_app/features/shift/data/shift_remote_data_source.dart';
import 'package:cashier_app/features/shift/data/shift_repository_impl.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:cashier_app/features/shift/presentation/bloc/shift_bloc.dart';

class _FakeShiftRemote implements ShiftRemoteDataSource {
  int getCurrentShiftCalls = 0;

  Shift _shift(int topupUzs) => Shift(
    id: 'shift-1',
    openedAt: DateTime(2026, 8, 17, 12, 55),
    closedAt: null,
    status: 'open',
    totals: ShiftTotals(
      salesCount: 1,
      subtotalUzs: 10000,
      cashUzs: 10000 + topupUzs,
      cardUzs: 0,
      topupUzs: topupUzs,
      balanceSalesUzs: 0,
    ),
  );

  @override
  Future<Shift> getCurrentShift() async {
    getCurrentShiftCalls++;
    // Grows on every fetch so a refresh visibly changes the header.
    return _shift(getCurrentShiftCalls * 1000);
  }

  @override
  Future<Shift> openShift({int? openingCashUzs}) async => _shift(0);

  @override
  Future<Shift> closeShift({String? closingNote}) async => _shift(0);
}

void main() {
  testWidgets('header refresh button re-fetches the shift totals', (
    tester,
  ) async {
    // In-memory boxes: `testWidgets` runs inside a FakeAsync zone, so real
    // disk I/O (a temp-dir Hive box) never completes — it needs an
    // `Uint8List` backend, which stays synchronous, instead of a real path.
    final offlineBox = await Hive.openBox<dynamic>(
      OfflineStore.boxName,
      bytes: Uint8List(0),
    );
    final appBox = await Hive.openBox<dynamic>(
      'cashier_app_box_test',
      bytes: Uint8List(0),
    );
    final store = OfflineStore(offlineBox);
    final local = LocalSource(appBox)
      ..setCashier(
        id: 'cashier-1',
        fullName: 'Zaira',
        username: 'zaira',
        branchId: 'branch-1',
        branchName: 'Algoritm',
      );
    addTearDown(() async {
      await Hive.close();
    });

    final remote = _FakeShiftRemote();
    final bloc = ShiftBloc(ShiftRepository(remote, store, local));
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [AppLocalization.delegate],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: BlocBuilder<ShiftBloc, ShiftState>(
              builder: (context, state) =>
                  HeaderBar(tab: ShellTab.posAccount, shift: state.shift),
            ),
          ),
        ),
      ),
    );

    expect(remote.getCurrentShiftCalls, 0);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(remote.getCurrentShiftCalls, 1);
    // The refreshed totals actually reach the header text.
    expect(find.textContaining('11 000'), findsOneWidget);
  });
}
