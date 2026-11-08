import 'dart:convert';
import 'dart:typed_data';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/features/birthday_parties/data/birthday_parties_repository.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.statusCode = 200});
  final Object body;
  final int statusCode;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> partyJson() => {
  'id': 'p1',
  'status': 'booked',
  'paymentState': 'unpaid',
  'branchId': 'b1',
  'branchName': 'Megaplanet',
  'customer': {'id': 42, 'fullName': 'Ali', 'phoneNumber': '998901112233'},
  'plan': {'id': 'pl1', 'name': 'VIP', 'color': '#7C3AED', 'includedItems': []},
  'childCount': 10,
  'extraChildren': 0,
  'packagePriceUzs': 3000000,
  'extraChildUzs': 150000,
  'listPriceUzs': 3000000,
  'agreedPriceUzs': 3000000,
  'discountUzs': 0,
  'paidUzs': 0,
  'refundedUzs': 0,
  'debtUzs': 3000000,
  'keptUzs': 0,
  'maxCashRefundUzs': 0,
  'partyDate': '2026-11-20',
  'soldBy': null,
  'createdAt': '2026-11-06T10:00:00.000Z',
  'completedAt': null,
  'cancelledAt': null,
  'cancelReason': null,
  'payments': [],
  'comments': [],
};

(BirthdayPartiesRepository, _Adapter) make(Object body, {int status = 200}) {
  final adapter = _Adapter(body, statusCode: status);
  final dio = Dio(BaseOptions(baseUrl: 'http://x'))
    ..httpClientAdapter = adapter;
  return (BirthdayPartiesRepository(dio), adapter);
}

void main() {
  test('sell POSTs the exact contract body', () async {
    final (repo, adapter) = make(partyJson());
    final party = await repo.sell(
      customerId: 42,
      planId: 'pl1',
      childCount: 10,
      extraChildren: 2,
      partyDate: '2026-11-20',
      agreedPriceUzs: 3000000,
      money: (fromBalanceUzs: 100, cashUzs: 200, cardUzs: 300),
      requestId: 'r1',
    );
    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/v1/pos/customers/42/birthday-parties');
    expect((req.data as Map).keys.toSet(), {
      'planId',
      'childCount',
      'extraChildren',
      'partyDate',
      'agreedPriceUzs',
      'fromBalanceUzs',
      'cashUzs',
      'cardUzs',
      'requestId',
    });
    expect(req.data['cashUzs'], 200);
    expect(party.id, 'p1');
  });

  test('400 maps to ServerException with code', () async {
    final (repo, _) = make({
      'statusCode': 400,
      'code': 'BIRTHDAY_OVERPAYMENT',
      'message': {'uz': 'Ortiqcha', 'en': 'Over', 'ru': 'Много'},
      'params': {'debtUzs': 400000},
    }, status: 400);
    await expectLater(
      repo.pay('p1', (fromBalanceUzs: 0, cashUzs: 500000, cardUzs: 0), 'r2'),
      throwsA(
        isA<ServerException>()
            .having((e) => e.code, 'code', 'BIRTHDAY_OVERPAYMENT')
            .having((e) => e.statusCode, 'statusCode', 400),
      ),
    );
  });

  test('a body without statusCode still carries the HTTP status', () async {
    final (repo, _) = make({
      'code': 'INTERNAL_ERROR',
      'message': 'boom',
    }, status: 500);
    await expectLater(
      repo.get('p1'),
      throwsA(
        isA<ServerException>()
            .having((e) => e.code, 'code', 'INTERNAL_ERROR')
            .having((e) => e.statusCode, 'statusCode', 500),
      ),
    );
  });

  test('list sends status query and parses list', () async {
    final (repo, adapter) = make([partyJson()]);
    final list = await repo.list(BirthdayPartyStatus.completed);
    expect(adapter.requests.single.path, '/v1/pos/birthday-parties');
    expect(adapter.requests.single.queryParameters, {'status': 'completed'});
    expect(list.single.id, 'p1');
  });

  test('plans, get and the party actions hit the contract paths', () async {
    final (repo, adapter) = make([]);
    expect(await repo.plans(), isEmpty);
    expect(adapter.requests.last.path, '/v1/pos/birthday-plans');

    final (r2, a2) = make(partyJson());
    await r2.get('p1');
    expect(a2.requests.last.path, '/v1/pos/birthday-parties/p1');
    await r2.pay('p1', (fromBalanceUzs: 1, cashUzs: 2, cardUzs: 3), 'rq');
    expect(a2.requests.last.path, '/v1/pos/birthday-parties/p1/payments');
    expect((a2.requests.last.data as Map).keys.toSet(), {
      'fromBalanceUzs',
      'cashUzs',
      'cardUzs',
      'requestId',
    });
    await r2.addExtraChildren('p1', 3);
    expect(a2.requests.last.path, '/v1/pos/birthday-parties/p1/extra-children');
    expect(a2.requests.last.data, {'count': 3});
    await r2.addExtraChildren('p1', 3, expectedExtraChildren: 2);
    expect(a2.requests.last.data, {'count': 3, 'expectedExtraChildren': 2});
    await r2.addExtraChildren(
      'p1',
      3,
      expectedExtraChildren: 2,
      requestId: 'rx-1',
    );
    expect(a2.requests.last.data, {
      'count': 3,
      'expectedExtraChildren': 2,
      'requestId': 'rx-1',
    });
    await r2.changeDate('p1', '2026-12-01');
    expect(a2.requests.last.method, 'PATCH');
    expect(a2.requests.last.path, '/v1/pos/birthday-parties/p1/date');
    expect(a2.requests.last.data, {'partyDate': '2026-12-01'});
    await r2.addComment('p1', 'salom');
    expect(a2.requests.last.path, '/v1/pos/birthday-parties/p1/comments');
    expect(a2.requests.last.data, {'text': 'salom'});
    await r2.addComment('p1', 'salom', requestId: 'rq-1');
    expect(a2.requests.last.data, {'text': 'salom', 'requestId': 'rq-1'});
    await r2.complete('p1');
    expect(a2.requests.last.path, '/v1/pos/birthday-parties/p1/complete');
    await r2.cancel(
      'p1',
      reason: 'sabab bor',
      refundBalanceUzs: 10,
      refundCashUzs: 20,
      requestId: 'rc',
    );
    expect(a2.requests.last.path, '/v1/pos/birthday-parties/p1/cancel');
    expect(a2.requests.last.data, {
      'reason': 'sabab bor',
      'refundBalanceUzs': 10,
      'refundCashUzs': 20,
      'requestId': 'rc',
    });
  });
}
