import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/pos_entry.dart';
import 'package:cashier_app/features/pos_account/domain/subscription.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.payload, {this.status = 200});

  final Object payload;
  final int status;
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

PosAccountRemoteDataSourceImpl _source(_FakeAdapter adapter) =>
    PosAccountRemoteDataSourceImpl(
      Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = adapter,
    );

Map<String, dynamic> _subJson({
  String id = 'sub-1',
  String childId = 'child-1',
  bool usableHere = true,
  bool usableToday = true,
  String? blockedReason,
  String? activatedAt = '2026-10-18T05:00:00.000Z',
  String? expiresAt = '2026-11-16T19:00:00.000Z',
}) => {
  'id': id,
  'childId': childId,
  'name': 'VIP 5 kirish',
  'level': 'day',
  'entriesTotal': 5,
  'entriesUsed': 2,
  'entriesLeft': 3,
  'activatedAt': activatedAt,
  'expiresAt': expiresAt,
  'status': activatedAt == null ? 'not_activated' : 'active',
  'limitKind': 'per_day',
  'limitCount': null,
  'usableHere': usableHere,
  'usableToday': usableToday,
  'blockedReason': blockedReason,
  'kidsPlanHere': {'key': 'vip', 'name': 'VIP', 'priceUzs': 90000},
};

void main() {
  group('CustomerSubscription parsing', () {
    test('parses a usable, activated subscription', () {
      final sub = CustomerSubscription.tryFromJson(_subJson())!;
      expect(sub.id, 'sub-1');
      expect(sub.entriesLeft, 3);
      expect(sub.usable, isTrue);
      expect(sub.isActivated, isTrue);
      expect(sub.limitKind, SubscriptionLimitKind.perDay);
      expect(sub.blockedReason, isNull);
      expect(
        sub.kidsPlanHere,
        const SubscriptionKidsPlan(key: 'vip', name: 'VIP', priceUzs: 90000),
      );
      // Exclusive end → the last valid day is the day before.
      expect(sub.lastValidDay!.isBefore(sub.expiresAt!), isTrue);
    });

    test('nulls: not activated, no plan here, blocked reason', () {
      final json = _subJson(
        activatedAt: null,
        expiresAt: null,
        usableHere: false,
        blockedReason: 'NOT_MAPPED_HERE',
      )..['kidsPlanHere'] = null;
      final sub = CustomerSubscription.tryFromJson(json)!;
      expect(sub.activatedAt, isNull);
      expect(sub.expiresAt, isNull);
      expect(sub.lastValidDay, isNull);
      expect(sub.kidsPlanHere, isNull);
      expect(sub.usable, isFalse);
      expect(sub.blockedReason, SubscriptionBlockedReason.notMappedHere);
    });

    test('blocked reasons and limit kinds map, unknown values degrade', () {
      expect(
        SubscriptionBlockedReason.parse('USED_TODAY'),
        SubscriptionBlockedReason.usedToday,
      );
      expect(
        SubscriptionBlockedReason.parse('WEEKLY_LIMIT'),
        SubscriptionBlockedReason.weeklyLimit,
      );
      expect(
        SubscriptionBlockedReason.parse('SOMETHING_NEW'),
        SubscriptionBlockedReason.other,
      );
      expect(
        SubscriptionLimitKind.parse('per_week'),
        SubscriptionLimitKind.perWeek,
      );
      expect(SubscriptionLimitKind.parse('none'), SubscriptionLimitKind.none);
      expect(SubscriptionLimitKind.parse(null), SubscriptionLimitKind.perDay);
    });

    test('a broken item is dropped, the rest of the list survives', () {
      final list = CustomerSubscription.listFromJson([
        _subJson(),
        {'childId': 'no-id'},
        'garbage',
        _subJson(id: 'sub-2', childId: 'child-2'),
      ]);
      expect(list.map((s) => s.id), ['sub-1', 'sub-2']);
      expect(CustomerSubscription.listFromJson(null), isEmpty);
      expect(CustomerSubscription.listFromJson({'items': []}), isEmpty);
    });

    test('entriesLeft falls back to total - used', () {
      final json = _subJson()..remove('entriesLeft');
      expect(CustomerSubscription.tryFromJson(json)!.entriesLeft, 3);
    });
  });

  group('SellableSubscriptionPlan parsing', () {
    test('parses the full shape', () {
      final plan = SellableSubscriptionPlan.tryFromJson({
        'id': 'plan-1',
        'name': 'VIP 5 kirish',
        'level': 'day',
        'entriesCount': 5,
        'validityDays': 30,
        'limitKind': 'per_week',
        'limitCount': 2,
        'priceUzs': 350000,
        'kidsPlan': {'key': 'vip', 'name': 'VIP', 'priceUzs': 90000},
        'perEntryUzs': 70000,
        'savingsPercent': 22,
      })!;
      expect(plan.priceUzs, 350000);
      expect(plan.limitKind, SubscriptionLimitKind.perWeek);
      expect(plan.limitCount, 2);
      expect(plan.kidsPlan!.name, 'VIP');
      expect(plan.perEntryUzs, 70000);
      expect(plan.savingsPercent, 22.0);
    });

    test('optional fields null; per-entry derived; no price → dropped', () {
      final plan = SellableSubscriptionPlan.tryFromJson({
        'id': 'p',
        'name': 'X',
        'level': 'hour',
        'entriesCount': 8,
        'validityDays': 30,
        'limitKind': 'per_day',
        'limitCount': null,
        'priceUzs': 440000,
        'kidsPlan': null,
        'perEntryUzs': null,
        'savingsPercent': null,
      })!;
      expect(plan.kidsPlan, isNull);
      expect(plan.perEntryUzs, 55000);
      expect(plan.savingsPercent, isNull);
      expect(
        SellableSubscriptionPlan.tryFromJson({'id': 'p', 'priceUzs': null}),
        isNull,
      );
    });
  });

  group('PosEntry.subscription', () {
    test('parsed when present, null when absent or null', () {
      final withSub = PosEntry.fromJson({
        'childId': 'child-1',
        'token': 'T',
        'expiresAt': null,
        'priceUzs': 0,
        'subscription': {
          'id': 'sub-1',
          'name': 'VIP 5 kirish',
          'entriesTotal': 5,
          'entriesLeft': 2,
          'expiresAt': null,
        },
      });
      expect(withSub.subscription!.entriesLeft, 2);
      expect(withSub.subscription!.expiresAt, isNull);
      expect(
        PosEntry.fromJson({'childId': 'c', 'token': 'T'}).subscription,
        isNull,
      );
      expect(
        PosEntry.fromJson({
          'childId': 'c',
          'token': 'T',
          'subscription': null,
        }).subscription,
        isNull,
      );
    });
  });

  group('data source', () {
    test('GET customer subscriptions hits the contract path', () async {
      final adapter = _FakeAdapter([_subJson()]);
      final list = await _source(adapter).listCustomerSubscriptions(7);
      expect(adapter.requests.single.path, '/v1/pos/customers/7/subscriptions');
      expect(adapter.requests.single.method, 'GET');
      expect(list.single.id, 'sub-1');
    });

    test('GET sellable subscriptions', () async {
      final adapter = _FakeAdapter([
        {'id': 'p', 'name': 'VIP', 'priceUzs': 350000, 'entriesCount': 5},
      ]);
      final list = await _source(adapter).listSellableSubscriptions();
      expect(adapter.requests.single.path, '/v1/pos/subscriptions');
      expect(list.single.priceUzs, 350000);
    });

    test(
      'checkout sends subscriptionChildIds and allows a null plan',
      () async {
        final adapter = _FakeAdapter({
          'entries': [
            {
              'childId': 'child-1',
              'token': 'T1',
              'priceUzs': 0,
              'subscription': {
                'id': 'sub-1',
                'name': 'VIP 5 kirish',
                'entriesTotal': 5,
                'entriesLeft': 2,
                'expiresAt': '2026-11-16T19:00:00.000Z',
              },
            },
          ],
          'failures': [],
        });
        final result = await _source(adapter).planEntryCheckout(
          customerId: 7,
          planKey: null,
          childIds: const ['child-1'],
          products: const [],
          cashUzs: 0,
          cardUzs: 0,
          subscriptionChildIds: const ['child-1'],
        );
        final body = adapter.requests.single.data as Map<String, dynamic>;
        expect(body.containsKey('planKey'), isFalse);
        expect(body['childIds'], ['child-1']);
        expect(body['subscriptionChildIds'], ['child-1']);
        expect(result.entries.single.subscription!.id, 'sub-1');
      },
    );

    test('checkout without subscriptions never sends the field', () async {
      final adapter = _FakeAdapter({'entries': [], 'failures': []});
      await _source(adapter).planEntryCheckout(
        customerId: 7,
        planKey: 'vip',
        childIds: const ['child-1'],
        products: const [],
        cashUzs: 0,
        cardUzs: 0,
      );
      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body.containsKey('subscriptionChildIds'), isFalse);
    });

    test('SUBSCRIPTION_NOT_USABLE failure gets an Uzbek message', () async {
      final adapter = _FakeAdapter({
        'entries': [],
        'failures': [
          {
            'childId': 'child-1',
            'code': 'SUBSCRIPTION_NOT_USABLE',
            'message': 'Subscription is not usable',
          },
        ],
      });
      final result = await _source(adapter).planEntryCheckout(
        customerId: 7,
        planKey: null,
        childIds: const ['child-1'],
        products: const [],
        cashUzs: 0,
        cardUzs: 0,
        subscriptionChildIds: const ['child-1'],
      );
      expect(result.failures.single.message, contains('Obuna'));
    });

    test('sell posts the contract body and parses the full answer', () async {
      final adapter = _FakeAdapter({
        'subscription': _subJson(),
        'pass': {
          'childId': 'child-1',
          'token': 'PASS1',
          'expiresAt': '2026-10-18T17:00:00.000Z',
          'priceUzs': 0,
        },
        'passFailure': null,
        'balance': 0,
        'receipt': {
          'saleId': 'sale-73291045',
          'createdAt': '2026-10-18T10:42:00.000Z',
          'priceUzs': 350000,
          'balanceUzs': 185000,
          'cashUzs': 100000,
          'cardUzs': 65000,
        },
        'cashback': {
          'code': 'ABCD2345EFGH',
          'qrPayload': 'PXCB:ABCD2345EFGH',
          'amountUzs': 4950,
          'percent': 3,
          'expiresAt': '2026-10-25T10:42:00.000Z',
        },
      }, status: 201);
      final sale = await _source(adapter).sellSubscription(
        customerId: 7,
        childId: 'child-1',
        subscriptionPlanId: 'plan-1',
        topupCashUzs: 100000,
        topupCardUzs: 65000,
        useToday: true,
      );
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/v1/pos/customers/7/subscriptions');
      expect(request.data, {
        'childId': 'child-1',
        'subscriptionPlanId': 'plan-1',
        'topupCashUzs': 100000,
        'topupCardUzs': 65000,
        'useToday': true,
      });
      expect(sale.pass!.token, 'PASS1');
      expect(sale.balance, 0);
      expect(sale.receipt.saleId, 'sale-73291045');
      expect(sale.receipt.cashUzs, 100000);
      expect(sale.cashback!.amountUzs, 4950);
      expect(sale.passFailureCode, isNull);
    });

    test('sell answer with nulls: no pass, pass failure, no cashback', () {
      final sale = SubscriptionSaleResult.fromJson({
        'subscription': _subJson(activatedAt: null, expiresAt: null),
        'pass': null,
        'passFailure': {'code': 'GATE_PASS_FAILED', 'message': 'nope'},
        'balance': 10000,
        'receipt': {
          'saleId': null,
          'createdAt': '2026-10-18T10:42:00.000Z',
          'priceUzs': 440000,
          'balanceUzs': 440000,
          'cashUzs': 0,
          'cardUzs': 0,
        },
        'cashback': null,
      });
      expect(sale.pass, isNull);
      expect(sale.passFailureCode, 'GATE_PASS_FAILED');
      expect(sale.receipt.saleId, isNull);
      expect(sale.cashback, isNull);
      final receipt = SubscriptionReceipt.fromSale(sale, childName: 'Doniyor');
      // Receipt id falls back to the subscription id.
      expect(receipt.id, 'sub-1');
      expect(receipt.usedToday, isFalse);
      expect(receipt.priceUzs, 440000);
    });

    test('SUBSCRIPTION_ALREADY_ACTIVE surfaces its code', () async {
      final adapter = _FakeAdapter({
        'statusCode': 409,
        'code': 'SUBSCRIPTION_ALREADY_ACTIVE',
        'message': {'uz': 'Bolada faol obuna bor', 'en': 'already'},
      }, status: 409);
      final result = await PosAccountRepository(_source(adapter))
          .sellSubscription(
            customerId: 7,
            childId: 'child-1',
            subscriptionPlanId: 'plan-1',
            topupCashUzs: 0,
            topupCardUzs: 0,
            useToday: false,
          );
      result.fold(
        (failure) =>
            expect(failure.props, contains('SUBSCRIPTION_ALREADY_ACTIVE')),
        (_) => fail('expected a failure'),
      );
    });
  });

  group('bloc', () {
    PosAccountBloc blocFor(_FakeAdapter adapter) =>
        PosAccountBloc(PosAccountRepository(_source(adapter)));

    final customer = Customer(
      id: 7,
      phoneNumber: '+998901234567',
      firstName: 'Aziza',
      lastName: null,
      balance: 185000,
      children: [
        Child(
          id: 'child-1',
          firstName: 'Samira',
          lastName: null,
          birthDate: DateTime(2020, 1, 1),
        ),
      ],
    );

    test('a backend without subscriptions leaves the list empty', () async {
      final adapter = _FakeAdapter({'message': 'Not Found'}, status: 404);
      final bloc = blocFor(adapter)..add(PosAccountCustomerSelected(customer));
      addTearDown(bloc.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.subscriptions, isEmpty);
      expect(bloc.state.selectedCustomer, customer);
    });

    test('a sale sets the result, the new balance and the chip', () async {
      final adapter = _FakeAdapter({
        'subscription': _subJson(),
        'pass': null,
        'passFailure': null,
        'balance': 0,
        'receipt': {
          'saleId': 's',
          'createdAt': '2026-10-18T10:42:00.000Z',
          'priceUzs': 350000,
          'balanceUzs': 185000,
          'cashUzs': 165000,
          'cardUzs': 0,
        },
        'cashback': null,
      });
      final bloc = blocFor(adapter);
      addTearDown(bloc.close);
      bloc.emit(bloc.state.copyWith(selectedCustomer: customer));
      bloc.add(
        const PosAccountSubscriptionSellRequested(
          childId: 'child-1',
          subscriptionPlanId: 'plan-1',
          topupCashUzs: 165000,
          topupCardUzs: 0,
          useToday: false,
        ),
      );
      await bloc.stream.firstWhere((s) => s.lastSubscriptionSale != null);
      expect(bloc.state.selectedCustomer!.balance, 0);
      expect(bloc.state.subscriptions.single.id, 'sub-1');
      bloc.add(const PosAccountSubscriptionSaleAcknowledged());
      await bloc.stream.firstWhere((s) => s.lastSubscriptionSale == null);
    });
  });
}
