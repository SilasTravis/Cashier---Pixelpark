import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _SlowTopupRemote extends PosAccountRemoteDataSourceImpl {
  _SlowTopupRemote() : super(Dio());

  final requestIds = <String>[];
  int calls = 0;

  @override
  Future<TopupResult> topup({
    required int customerId,
    required int amountUzs,
    required int cashUzs,
    required int cardUzs,
    required String requestId,
  }) async {
    calls += 1;
    requestIds.add(requestId);
    // Hold the request open so a second click has a window to slip through.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return TopupResult(balance: 100000 + amountUzs, transactionId: calls);
  }
}

final customer = Customer(
  id: 22,
  phoneNumber: '+998900000000',
  firstName: 'Ota',
  lastName: null,
  balance: 100000,
  children: const [],
);

PosAccountBloc _blocWith(_SlowTopupRemote remote) =>
    PosAccountBloc(PosAccountRepository(remote));

void main() {
  test(
    'a second click while the first top-up is in flight is dropped',
    () async {
      final remote = _SlowTopupRemote();
      final bloc = _blocWith(remote);
      addTearDown(bloc.close);
      bloc.emit(bloc.state.copyWith(selectedCustomer: customer));

      // Two taps in the same frame, before any rebuild could disable the button.
      bloc.add(
        const PosAccountTopupRequested(
          amountUzs: 50000,
          cashUzs: 50000,
          cardUzs: 0,
          requestId: 'req-1',
        ),
      );
      bloc.add(
        const PosAccountTopupRequested(
          amountUzs: 50000,
          cashUzs: 50000,
          cardUzs: 0,
          requestId: 'req-2',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(remote.calls, 1);
      expect(remote.requestIds, ['req-1']);
    },
  );

  test(
    'the key reaches the server, so a retry there cannot charge twice',
    () async {
      final remote = _SlowTopupRemote();
      final bloc = _blocWith(remote);
      addTearDown(bloc.close);
      bloc.emit(bloc.state.copyWith(selectedCustomer: customer));

      bloc.add(
        const PosAccountTopupRequested(
          amountUzs: 30000,
          cashUzs: 0,
          cardUzs: 30000,
          requestId: 'req-abc',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(remote.requestIds.single, 'req-abc');
    },
  );

  test('a top-up is accepted again once the first one has settled', () async {
    final remote = _SlowTopupRemote();
    final bloc = _blocWith(remote);
    addTearDown(bloc.close);
    bloc.emit(bloc.state.copyWith(selectedCustomer: customer));

    bloc.add(
      const PosAccountTopupRequested(
        amountUzs: 10000,
        cashUzs: 10000,
        cardUzs: 0,
        requestId: 'req-1',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    bloc.add(
      const PosAccountTopupRequested(
        amountUzs: 10000,
        cashUzs: 10000,
        cardUzs: 0,
        requestId: 'req-2',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(remote.requestIds, ['req-1', 'req-2']);
  });
}
