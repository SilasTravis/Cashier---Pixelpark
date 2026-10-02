import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';

const _snapshot = Customer(
  id: 7,
  phoneNumber: '+998901234567',
  firstName: 'Aziza',
  lastName: null,
  balance: 100,
  children: [],
);

const _fresh = Customer(
  id: 7,
  phoneNumber: '+998901234567',
  firstName: 'Aziza',
  lastName: null,
  balance: 900,
  children: [],
);

class _Remote implements PosAccountRemoteDataSource {
  @override
  Future<List<Customer>> searchCustomers(String query, {int page = 1}) async {
    if (query.isEmpty) return const [];
    return const [_fresh];
  }

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory temp;
  late Box<dynamic> box;
  late LocalSource local;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_history_test');
    Hive.init(temp.path);
    box = await Hive.openBox<dynamic>(
      'history-${DateTime.now().microsecondsSinceEpoch}',
    );
    local = LocalSource(box)
      ..setCashier(
        id: 'cashier-1',
        fullName: 'Cashier',
        username: 'cashier',
        branchId: 'branch-1',
        branchName: 'Branch',
      );
  });

  tearDown(() async {
    await box.close();
    await temp.delete(recursive: true);
  });

  test(
    'selection survives bloc recreation and refreshes from backend',
    () async {
      final repository = PosAccountRepository(_Remote());
      final first = PosAccountBloc(repository, local);
      final selected = first.stream.firstWhere(
        (state) => state.customerHistory.isNotEmpty,
      );
      first.add(const PosAccountCustomerSelected(_snapshot));
      await selected;

      for (var attempt = 0; attempt < 20; attempt++) {
        if (local.getCustomerSearchHistory().isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(local.getCustomerSearchHistory(), isNotEmpty);
      await first.close();

      final restored = PosAccountBloc(repository, local);
      final refreshed = restored.stream.firstWhere(
        (state) =>
            state.customerHistory.isNotEmpty &&
            state.customerHistory.first.balance == _fresh.balance,
      );
      restored.add(const PosAccountRecentCustomersRequested());

      expect((await refreshed).customerHistory.first, _fresh);
      await restored.close();
    },
  );

  test('history is isolated by cashier and branch', () async {
    await local.setCustomerSearchHistory(const [
      {
        'id': 7,
        'phoneNumber': '+998901234567',
        'firstName': 'Aziza',
        'lastName': null,
        'balance': 100,
        'children': <Map<String, dynamic>>[],
      },
    ]);
    expect(local.getCustomerSearchHistory(), hasLength(1));

    local.setCashier(
      id: 'cashier-2',
      fullName: 'Other',
      username: 'other',
      branchId: 'branch-1',
      branchName: 'Branch',
    );
    expect(local.getCustomerSearchHistory(), isEmpty);
  });
}
