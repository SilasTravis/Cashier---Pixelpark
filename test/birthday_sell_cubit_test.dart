import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/core/widgets/payment_method_selector.dart';
import 'package:cashier_app/features/birthday_parties/data/birthday_parties_repository.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_plan.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_wallet.dart';
import 'package:cashier_app/features/birthday_parties/presentation/bloc/birthday_sell_cubit.dart';
import 'package:cashier_app/features/birthday_parties/presentation/birthday_recovery.dart';
import 'dart:async';

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

  /// Each wallet read answers with the next entry (a wallet, an Object to
  /// throw, or a Future), then [walletResult].
  final walletQueue = <Object>[];
  BirthdayWallet walletResult = const BirthdayWallet(
    balanceUzs: 0,
    usableUzs: 0,
    bonusUzs: 0,
  );
  int walletReads = 0;

  @override
  Future<BirthdayWallet> wallet(int customerId) async {
    walletReads++;
    final next = walletQueue.isNotEmpty ? walletQueue.removeAt(0) : null;
    if (next == null) return walletResult;
    if (next is Future<BirthdayWallet>) return next;
    if (next is BirthdayWallet) return next;
    throw next;
  }

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

  /// When set, `get` answers with these in turn (then [getResult]).
  final getQueue = <Object>[];

  @override
  Future<BirthdayParty> get(String id) async {
    gets.add(id);
    final r = getQueue.isNotEmpty ? getQueue.removeAt(0) : getResult;
    if (r is BirthdayParty) return r;
    throw r ??
        ServerException(
          message: 'x',
          code: 'BIRTHDAY_PARTY_NOT_FOUND',
          statusCode: 404,
        );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ServerException get _timeout => ServerException(message: 'timeout');

ServerException _refusal(String code) =>
    ServerException(message: 'x', code: code, statusCode: 400);

BirthdayWallet _wallet(int usable, {int bonus = 0}) => BirthdayWallet(
  balanceUzs: usable + bonus,
  usableUzs: usable,
  bonusUzs: bonus,
);

Future<BirthdaySellCubit> _ready(_Repo repo, {BirthdayWallet? wallet}) async {
  if (wallet != null) repo.walletResult = wallet;
  final cubit = BirthdaySellCubit(
    repo,
    customerId: 42,
    today: DateTime(2026, 11, 6),
    recheckDelay: Duration.zero,
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
    final lookup = await cubit.resolveOnClose();
    expect(lookup, isA<PartyFound>());
  });

  test('closing while the server is unreachable is not a release', () async {
    final repo = _Repo();
    final cubit = await _ready(repo);
    repo.sellResults.add(_timeout);
    await cubit.submit(customerId: 42);
    repo.getResult = ServerException(message: 'timeout');
    expect(await cubit.resolveOnClose(), isA<PartyUnreachable>());
    expect(cubit.state.unclear, isTrue);
    expect(cubit.state.busy, isFalse);
    repo.getResult = null; // the default: BIRTHDAY_PARTY_NOT_FOUND
    final getsBefore = repo.gets.length;
    expect(await cubit.resolveOnClose(), isA<PartyMissing>());
    // A 404 is re-checked twice before it is trusted.
    expect(repo.gets.length - getsBefore, 3);
  });

  test('a sale that shows up on a close re-check is found', () async {
    final repo = _Repo();
    final cubit = await _ready(repo);
    repo.sellResults.add(_timeout);
    await cubit.submit(customerId: 42);
    final getsBefore = repo.gets.length;
    // Still committing on the first read, there on the second.
    repo.getQueue.add(
      ServerException(
        message: 'x',
        code: 'BIRTHDAY_PARTY_NOT_FOUND',
        statusCode: 404,
      ),
    );
    repo.getResult = fixtureParty();
    expect(await cubit.resolveOnClose(), isA<PartyFound>());
    expect(repo.gets.length - getsBefore, 2);
  });

  test('a 500 after the sell is unclear: refetch, then lock', () async {
    final repo = _Repo();
    final cubit = await _ready(repo);
    repo.sellResults.add(
      ServerException(message: 'x', code: 'INTERNAL_ERROR', statusCode: 500),
    );
    await cubit.submit(customerId: 42);
    expect(repo.gets, [cubit.requestId]);
    expect(cubit.state.unclear, isTrue);
    expect(cubit.state.party, isNull);
    // Closing must ask the server, not just close.
    repo.getResult = fixtureParty();
    expect(await cubit.resolveOnClose(), isA<PartyFound>());
  });

  test('a 500 whose sale was booked is a success', () async {
    final repo = _Repo();
    final cubit = await _ready(repo);
    repo.sellResults.add(
      ServerException(message: 'x', code: 'INTERNAL_ERROR', statusCode: 500),
    );
    repo.getResult = fixtureParty();
    await cubit.submit(customerId: 42);
    expect(repo.sells, hasLength(1));
    expect(cubit.state.party, isNotNull);
  });

  test('a clean refusal of an unclear retry unlocks the sheet', () async {
    final repo = _Repo();
    final cubit = await _ready(repo);
    repo.sellResults.addAll([
      _timeout,
      _refusal('BIRTHDAY_PLAN_NOT_AVAILABLE'),
    ]);
    await cubit.submit(customerId: 42);
    expect(cubit.state.unclear, isTrue);
    await cubit.submit(customerId: 42);
    expect(cubit.state.unclear, isFalse);
    expect(cubit.state.errorCode, 'BIRTHDAY_PLAN_NOT_AVAILABLE');
    // Editable again.
    cubit.addExtraChild();
    expect(cubit.state.extraChildren, 1);
    expect(await cubit.resolveOnClose(), isNull);
  });

  test('a wallet re-read never recomputes a locked split', () async {
    final repo = _Repo();
    final balance = Completer<BirthdayWallet>();
    final cubit = await _ready(repo, wallet: _wallet(600000));
    repo.walletQueue.add(balance.future);
    cubit.setPayFromBalance(true);
    repo.sellResults.addAll([
      _refusal('BIRTHDAY_BALANCE_INSUFFICIENT'),
      _timeout,
    ]);
    // The refusal starts a balance re-read that is still on its way...
    final refused = cubit.submit(customerId: 42);
    await Future<void>.delayed(Duration.zero);
    // ...when the next submit ends unclear and locks the sheet.
    await cubit.submit(customerId: 42);
    expect(cubit.state.unclear, isTrue);
    final locked = cubit.state.payment;
    balance.complete(_wallet(100000));
    await refused;
    expect(cubit.state.usableUzs, 600000);
    expect(cubit.state.payment.fromBalanceUzs, locked.fromBalanceUzs);
    expect(cubit.state.payment.collectUzs, locked.collectUzs);
  });

  test('a clear refusal is not unclear and does not refetch', () async {
    final repo = _Repo();
    final cubit = await _ready(repo);
    repo.sellResults.add(_refusal('BIRTHDAY_PLAN_NOT_AVAILABLE'));
    await cubit.submit(customerId: 42);
    expect(cubit.state.unclear, isFalse);
    expect(repo.gets, isEmpty);
    expect(cubit.state.errorCode, 'BIRTHDAY_PLAN_NOT_AVAILABLE');
  });

  test('BIRTHDAY_BALANCE_INSUFFICIENT re-reads the birthday wallet', () async {
    final repo = _Repo();
    final cubit = await _ready(repo, wallet: _wallet(600000));
    cubit.setPayFromBalance(true);
    repo.walletQueue.add(_wallet(100000, bonus: 500000));
    repo.sellResults.add(_refusal('BIRTHDAY_BALANCE_INSUFFICIENT'));
    await cubit.submit(customerId: 42);
    expect(repo.walletReads, 2);
    expect(cubit.state.usableUzs, 100000);
    expect(cubit.state.payment.fromBalanceUzs, 100000);
  });

  test('only usable money pays; bonus never does', () async {
    final repo = _Repo();
    final cubit = await _ready(repo, wallet: _wallet(600000, bonus: 300000));
    cubit.setPayFromBalance(true);
    // Jami 2 000 000: 600 000 from the balance (not 900 000).
    expect(cubit.state.payment.fromBalanceUzs, 600000);
    expect(cubit.state.payment.collectUzs, 1400000);
  });

  test('a wallet with only bonus keeps the balance switch off', () async {
    final repo = _Repo();
    final cubit = await _ready(repo, wallet: _wallet(0, bonus: 300000));
    cubit.setPayFromBalance(true);
    expect(cubit.state.payFromBalance, isFalse);
    expect(cubit.state.payment.fromBalanceUzs, 0);
  });

  test('a failed wallet read is not a silent 0 and cash still sells', () async {
    final repo = _Repo()..walletQueue.add(StateError('down'));
    final cubit = await _ready(repo);
    expect(cubit.state.walletFailed, isTrue);
    expect(cubit.state.payFromBalance, isFalse);
    expect(cubit.state.canSubmit, isTrue);
  });

  test('the minus stops at 0 and re-prices', () async {
    final cubit = await _ready(_Repo());
    cubit.removeExtraChild();
    expect(cubit.state.extraChildren, 0);
    cubit
      ..addExtraChild()
      ..addExtraChild();
    expect(cubit.state.listPriceUzs, 2240000);
    cubit.removeExtraChild();
    expect(cubit.state.extraChildren, 1);
    expect(cubit.state.listPriceUzs, 2120000);
  });

  test('load never hangs on an unexpected failure', () async {
    final repo = _Repo()..plansError = StateError('boom');
    final cubit = BirthdaySellCubit(repo, customerId: 42);
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
