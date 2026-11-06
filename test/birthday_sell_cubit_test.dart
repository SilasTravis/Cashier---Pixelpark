import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/core/widgets/payment_method_selector.dart';
import 'package:cashier_app/features/birthday_parties/data/birthday_parties_repository.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_plan.dart';
import 'package:cashier_app/features/birthday_parties/presentation/bloc/birthday_sell_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/birthday_fixtures.dart';

const _vip = BirthdayPlan(
  id: 'vip',
  name: 'VIP',
  color: '#7C3AED',
  active: true,
  allBranches: true,
  branchIds: [],
  includedItems: [],
  sortOrder: 0,
  sizes: [
    BirthdayPlanSize(childCount: 10, priceUzs: 2000000, extraChildUzs: 120000),
  ],
);

class _Repo implements BirthdayPartiesRepository {
  /// Each sell answers with the next entry (an Object to throw or a party).
  final sellResults = <Object>[];
  Object? getResult;
  final sells = <String>[];
  final gets = <String>[];
  Object? plansError;

  @override
  Future<List<BirthdayPlan>> plans() async {
    if (plansError != null) throw plansError!;
    return [_vip];
  }

  @override
  Future<BirthdayParty> sell({
    required int customerId,
    required String planId,
    required int childCount,
    required int extraChildren,
    required String partyDate,
    required int agreedPriceUzs,
    required BirthdayMoney money,
    required String requestId,
  }) async {
    sells.add(requestId);
    final next = sellResults.removeAt(0);
    if (next is BirthdayParty) return next;
    throw next;
  }

  @override
  Future<BirthdayParty> get(String id) async {
    gets.add(id);
    final r = getResult;
    if (r is BirthdayParty) return r;
    throw r ?? ServerException(message: 'x', code: 'BIRTHDAY_PARTY_NOT_FOUND');
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ServerException get _timeout => ServerException(message: 'timeout');

Future<BirthdaySellCubit> _ready(
  _Repo repo, {
  int balance = 0,
  Future<int?> Function()? lookup,
}) async {
  final cubit = BirthdaySellCubit(
    repo,
    today: DateTime(2026, 11, 6),
    balanceUzs: balance,
    balanceLookup: lookup,
  );
  await cubit.load();
  cubit
    ..selectPlan('vip')
    ..selectSize(10)
    ..setMethod(PaymentMethod.cash)
    ..setPayFromBalance(false);
  return cubit;
}

void main() {
  test(
    'a timed-out sell whose party exists is a success after one sell',
    () async {
      final repo = _Repo();
      final cubit = await _ready(repo);
      repo.sellResults.add(_timeout);
      repo.getResult = fixtureParty();
      await cubit.submit(customerId: 42);
      expect(repo.sells, hasLength(1));
      expect(repo.gets, [cubit.requestId]);
      expect(cubit.state.party, isNotNull);
      expect(cubit.state.unclear, isFalse);
    },
  );

  test('a non-server failure is treated the same way', () async {
    final repo = _Repo();
    final cubit = await _ready(repo);
    repo.sellResults.add(Exception('socket closed'));
    repo.getResult = fixtureParty();
    await cubit.submit(customerId: 42);
    expect(cubit.state.party, isNotNull);
  });

  test('BIRTHDAY_REQUEST_CONFLICT takes the refetch path', () async {
    final repo = _Repo();
    final cubit = await _ready(repo);
    repo.sellResults.add(
      ServerException(message: 'c', code: 'BIRTHDAY_REQUEST_CONFLICT'),
    );
    repo.getResult = fixtureParty();
    await cubit.submit(customerId: 42);
    expect(repo.gets, hasLength(1));
    expect(cubit.state.party, isNotNull);
  });

  test(
    'when the party is not there the sheet locks and retries the same id',
    () async {
      final repo = _Repo();
      final cubit = await _ready(repo);
      repo.sellResults.addAll([_timeout, fixtureParty()]);
      await cubit.submit(customerId: 42);
      expect(cubit.state.party, isNull);
      expect(cubit.state.unclear, isTrue);
      expect(cubit.state.busy, isFalse);
      // Amounts are frozen.
      cubit.addExtraChild();
      cubit.setAgreedPrice(1);
      expect(cubit.state.extraChildren, 0);
      expect(cubit.state.agreedOverrideUzs, isNull);
      // Retry: the very same requestId.
      await cubit.submit(customerId: 42);
      expect(repo.sells, hasLength(2));
      expect(repo.sells[0], repo.sells[1]);
      expect(cubit.state.party, isNotNull);
    },
  );

  test('closing after an unclear failure re-fetches the party', () async {
    final repo = _Repo();
    final cubit = await _ready(repo);
    repo.sellResults.add(_timeout);
    await cubit.submit(customerId: 42);
    expect(cubit.state.unclear, isTrue);
    repo.getResult = fixtureParty();
    final party = await cubit.resolveOnClose();
    expect(party, isNotNull);
  });

  test('a clear refusal is not unclear and does not refetch', () async {
    final repo = _Repo();
    final cubit = await _ready(repo);
    repo.sellResults.add(
      ServerException(message: 'no', code: 'BIRTHDAY_PLAN_NOT_AVAILABLE'),
    );
    await cubit.submit(customerId: 42);
    expect(cubit.state.unclear, isFalse);
    expect(repo.gets, isEmpty);
    expect(cubit.state.errorCode, 'BIRTHDAY_PLAN_NOT_AVAILABLE');
  });

  test('BIRTHDAY_BALANCE_INSUFFICIENT re-reads the customer balance', () async {
    final repo = _Repo();
    final cubit = await _ready(
      repo,
      balance: 600000,
      lookup: () async => 100000,
    );
    cubit.setPayFromBalance(true);
    repo.sellResults.add(
      ServerException(message: 'x', code: 'BIRTHDAY_BALANCE_INSUFFICIENT'),
    );
    await cubit.submit(customerId: 42);
    expect(cubit.state.balanceUzs, 100000);
    expect(cubit.state.payment.fromBalanceUzs, 100000);
  });

  test('load never hangs on an unexpected failure', () async {
    final repo = _Repo()..plansError = StateError('boom');
    final cubit = BirthdaySellCubit(repo);
    await cubit.load();
    expect(cubit.state.loading, isFalse);
    expect(cubit.state.errorCode, 'UNKNOWN');
  });

  test('an emptied Jami is nothing to submit and does not snap back', () async {
    final cubit = await _ready(_Repo());
    expect(cubit.state.canSubmit, isTrue);
    cubit.setAgreedPrice(null);
    expect(cubit.state.agreedUzs, 0);
    expect(cubit.state.agreedOverrideUzs, 0);
    expect(cubit.state.canSubmit, isFalse);
    expect(cubit.state.discountUzs, 0);
  });

  test('extra children stop at 50', () async {
    final cubit = await _ready(_Repo());
    for (var i = 0; i < 60; i++) {
      cubit.addExtraChild();
    }
    expect(cubit.state.extraChildren, 50);
  });
}
