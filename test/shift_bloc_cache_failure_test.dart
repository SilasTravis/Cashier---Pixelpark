import 'dart:io';

import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/shift/data/shift_remote_data_source.dart';
import 'package:cashier_app/features/shift/data/shift_repository_impl.dart';
import 'package:cashier_app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// Never exercised: the repository stays offline for this test.
class _UnusedShiftsRemote extends ShiftRemoteDataSourceImpl {
  _UnusedShiftsRemote() : super(Dio());
}

void main() {
  late Directory temp;
  late Box<dynamic> offlineBox;
  late Box<dynamic> appBox;
  late OfflineStore store;
  late LocalSource local;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_shift_cache_failure');
    Hive.init(temp.path);
    offlineBox = await Hive.openBox<dynamic>(OfflineStore.boxName);
    appBox = await Hive.openBox<dynamic>('cashier_app_box_test');
    store = OfflineStore(offlineBox);
    local = LocalSource(appBox)
      ..setCashier(
        id: 'cashier-1',
        fullName: 'Zaira',
        username: 'zaira',
        branchId: 'branch-1',
        branchName: 'Algoritm',
      );
  });

  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test(
    "a CacheFailure's message reaches the bloc state, not the generic fallback",
    () async {
      await store.setOfflineMode(true);
      final bloc = ShiftBloc(
        ShiftRepository(_UnusedShiftsRemote(), store, local),
      );
      addTearDown(bloc.close);

      bloc.add(const ShiftOpenRequested(openingCashUzs: -1));
      final state = await bloc.stream.firstWhere((state) => !state.isLoading);

      expect(state.errorMessage, "Boshlang'ich naqd summa noto'g'ri");
    },
  );
}
