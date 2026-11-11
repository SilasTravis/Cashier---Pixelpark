import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/features/birthday_parties/data/birthday_parties_repository.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:cashier_app/features/birthday_parties/presentation/birthday_recovery.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/birthday_fixtures.dart';

const _money = (fromBalanceUzs: 0, cashUzs: 500000, cardUzs: 0);

ServerException get _notFound => ServerException(
  message: 'x',
  code: 'BIRTHDAY_PARTY_NOT_FOUND',
  statusCode: 404,
);

/// `get` answers with the next entry (a party, or an Object to throw); the
/// last one repeats.
class _Repo implements BirthdayPartiesRepository {
  _Repo(this.answers);
  final List<Object> answers;
  int gets = 0;

  @override
  Future<BirthdayParty> get(String id) async {
    final next = answers[gets < answers.length ? gets : answers.length - 1];
    gets++;
    if (next is BirthdayParty) return next;
    throw next;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('isUnclearFailure', () {
    test('a 4xx with a server code is a clean refusal', () {
      expect(
        isUnclearFailure(
          ServerException(
            message: 'x',
            code: 'BIRTHDAY_BALANCE_INSUFFICIENT',
            statusCode: 400,
          ),
        ),
        isFalse,
      );
      expect(isUnclearFailure(_notFound), isFalse);
    });

    test('a 5xx is unclear, with or without a code', () {
      expect(
        isUnclearFailure(
          ServerException(
            message: 'x',
            code: 'INTERNAL_ERROR',
            statusCode: 500,
          ),
        ),
        isTrue,
      );
      expect(
        isUnclearFailure(ServerException(message: 'x', statusCode: 502)),
        isTrue,
      );
    });

    test('no code, no status, a conflict or a non-server error is unclear', () {
      expect(isUnclearFailure(ServerException(message: 'timeout')), isTrue);
      expect(
        isUnclearFailure(ServerException(message: 'x', code: 'SOME_CODE')),
        isTrue,
      );
      expect(
        isUnclearFailure(
          ServerException(
            message: 'c',
            code: 'BIRTHDAY_REQUEST_CONFLICT',
            statusCode: 409,
          ),
        ),
        isTrue,
      );
      expect(isUnclearFailure(Exception('socket')), isTrue);
    });
  });

  group('lookupPartySettled', () {
    test('a 404 is re-checked twice, 3 s apart, before it is trusted', () {
      fakeAsync((async) {
        final repo = _Repo([_notFound]);
        PartyLookup? result;
        lookupPartySettled(repo, 'p1').then((r) => result = r);
        async.flushMicrotasks();
        expect(repo.gets, 1);
        async.elapse(const Duration(milliseconds: 2900));
        expect(repo.gets, 1);
        async.elapse(const Duration(milliseconds: 100));
        expect(repo.gets, 2);
        expect(result, isNull);
        async.elapse(const Duration(seconds: 3));
        expect(repo.gets, 3);
        expect(result, isA<PartyMissing>());
        async.elapse(const Duration(seconds: 10));
        expect(repo.gets, 3);
      });
    });

    test('a party that appears on a re-check is found', () {
      fakeAsync((async) {
        final repo = _Repo([_notFound, fixtureParty()]);
        PartyLookup? result;
        lookupPartySettled(repo, 'p1').then((r) => result = r);
        async.elapse(const Duration(seconds: 3));
        expect(repo.gets, 2);
        expect(result, isA<PartyFound>());
      });
    });

    test('found or unreachable answers at once', () async {
      final found = _Repo([fixtureParty()]);
      expect(await lookupPartySettled(found, 'p1'), isA<PartyFound>());
      expect(found.gets, 1);
      final down = _Repo([ServerException(message: 'timeout')]);
      expect(await lookupPartySettled(down, 'p1'), isA<PartyUnreachable>());
      expect(down.gets, 1);
    });
  });

  final before = fixtureParty(
    paid: 500000,
    debt: 1740000,
    payments: [paymentJson(id: 'a', cash: 500000, requestId: 'old')],
  );

  group('paymentReflected', () {
    test('matches a new row by its requestId', () {
      final fresh = fixtureParty(
        payments: [
          paymentJson(id: 'a', cash: 500000, requestId: 'old'),
          paymentJson(id: 'b', cash: 500000, requestId: 'mine'),
        ],
      );
      expect(
        paymentReflected(before, fresh, _money, requestId: 'mine'),
        isTrue,
      );
    });

    test('an identical split under another requestId is not this payment', () {
      final fresh = fixtureParty(
        payments: [
          paymentJson(id: 'a', cash: 500000, requestId: 'old'),
          paymentJson(id: 'b', cash: 500000, requestId: 'someone-else'),
        ],
      );
      expect(
        paymentReflected(before, fresh, _money, requestId: 'mine'),
        isFalse,
      );
      // A stale "before" that lacks the old row changes nothing.
      expect(
        paymentReflected(
          fixtureParty(),
          fixtureParty(
            payments: [paymentJson(id: 'a', cash: 500000, requestId: 'old')],
          ),
          _money,
          requestId: 'mine',
        ),
        isFalse,
      );
    });

    test('rows without a requestId fall back to a new row with the split', () {
      final legacyBefore = fixtureParty(
        payments: [paymentJson(id: 'a', cash: 500000)],
      );
      final fresh = fixtureParty(
        payments: [
          paymentJson(id: 'a', cash: 500000),
          paymentJson(id: 'b', cash: 500000),
        ],
      );
      expect(
        paymentReflected(legacyBefore, fresh, _money, requestId: 'mine'),
        isTrue,
      );
      // The old row alone is not a new payment.
      expect(
        paymentReflected(legacyBefore, legacyBefore, _money, requestId: 'x'),
        isFalse,
      );
    });

    test('refund rows never count as the payment', () {
      final fresh = fixtureParty(
        payments: [
          paymentJson(
            id: 'r',
            kind: 'refund',
            cash: 500000,
            refundTo: 'cash',
            requestId: 'mine',
          ),
        ],
      );
      expect(
        paymentReflected(fixtureParty(), fresh, _money, requestId: 'mine'),
        isFalse,
      );
    });
  });
}
