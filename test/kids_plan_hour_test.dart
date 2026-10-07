import 'dart:typed_data';

import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/domain/kids_plan.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/plan_entry_printing.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every request and answers with a fixed JSON body — no network.
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.body);

  final String body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _plansJson = '''
[
  {"key":"standard","name":"Standart","kind":"per_minute_tiers","firstMinuteUzs":1000,"secondMinuteUzs":null,"extraMinuteUzs":null,"maxBillableMinutes":75,"flatUzs":null},
  {"key":"vip","name":"VIP","kind":"flat_day","firstMinuteUzs":null,"secondMinuteUzs":null,"extraMinuteUzs":null,"maxBillableMinutes":null,"flatUzs":75000},
  {"key":"hour","name":"1 soat","kind":"flat_hour","firstMinuteUzs":null,"secondMinuteUzs":null,"extraMinuteUzs":null,"maxBillableMinutes":null,"flatUzs":50000,"durationMinutes":60}
]
''';

void main() {
  test(
    'asks the backend for the hour plan and parses all three kinds',
    () async {
      final adapter = _CapturingAdapter(_plansJson);
      final remote = PosAccountRemoteDataSourceImpl(
        Dio()..httpClientAdapter = adapter,
      );

      final plans = await remote.listPlans();

      expect(adapter.requests.single.path, '/v1/pos/plans');
      expect(adapter.requests.single.queryParameters, {'kinds': 'flat_hour'});
      expect(plans.map((p) => p.kind).toList(), [
        KidsPlanKind.perMinuteTiers,
        KidsPlanKind.flatDay,
        KidsPlanKind.flatHour,
      ]);
      final hour = plans.last;
      expect(hour.durationMinutes, 60);
      expect(hour.flatUzs, 50000);
      expect(hour.isPrepaid, isTrue);
      expect(plans.first.isPrepaid, isFalse);
      expect(plans[1].isPrepaid, isTrue);
      expect(plans.first.durationMinutes, isNull);
    },
  );

  test('parses custom flat_hour plans with isVip defaulting to false', () async {
    final adapter = _CapturingAdapter(
      '[{"key":"c-ab12","name":"Birthday 90 min","kind":"flat_hour","flatUzs":120000,"durationMinutes":90,"isVip":true},'
      '{"key":"c-cd34","name":"Quick 30","kind":"flat_hour","flatUzs":30000,"durationMinutes":30}]',
    );
    final plans = await PosAccountRemoteDataSourceImpl(
      Dio()..httpClientAdapter = adapter,
    ).listPlans();

    expect(plans.map((p) => p.isVip).toList(), [true, false]);
    expect(plans.first.durationMinutes, 90);
    expect(plans.first.kind, KidsPlanKind.flatHour);
    expect(plans.last.name, 'Quick 30');
  });

  test('an unknown kind still falls back to Standard, as before', () async {
    final adapter = _CapturingAdapter(
      '[{"key":"x","name":"X","kind":"something_new","flatUzs":1}]',
    );
    final plans = await PosAccountRemoteDataSourceImpl(
      Dio()..httpClientAdapter = adapter,
    ).listPlans();

    expect(plans.single.kind, KidsPlanKind.perMinuteTiers);
  });

  test(
    'sticker name: hour stickers lead with the duration, others unchanged',
    () {
      expect(stickerNameFor('Aziza Karimova', null), 'Aziza Karimova');
      expect(stickerNameFor('Aziza Karimova', 60), '1 SOAT · Aziza Karimova');
      expect(stickerNameFor('Aziza', 120), '2 SOAT · Aziza');
      expect(stickerNameFor('Aziza', 30), '30 DAQ · Aziza');
      expect(stickerNameFor('', 60), '1 SOAT');
    },
  );

  test(
    'checkout opts in to the hour plan and reads each entry\'s duration',
    () async {
      // The backend refuses a fresh `hour` sale (KIDS_PLAN_NOT_FOUND) unless
      // the checkout carries the same `kinds=flat_hour` opt-in as the plans
      // list. Standard/VIP entries carry no `durationMinutes`.
      final adapter = _CapturingAdapter('''
{
  "entries": [
    {"childId":"c-hour","token":"T1","expiresAt":"2026-10-05T18:59:59.000Z","durationMinutes":60},
    {"childId":"c-vip","token":"T2","expiresAt":"2026-10-05T18:59:59.000Z"}
  ],
  "failures": [],
  "balance": 0
}
''');
      final remote = PosAccountRemoteDataSourceImpl(
        Dio()..httpClientAdapter = adapter,
      );

      final result = await remote.planEntryCheckout(
        customerId: 7,
        planKey: 'hour',
        childIds: const ['c-hour', 'c-vip'],
        products: const [],
        cashUzs: 50000,
        cardUzs: 0,
      );

      final request = adapter.requests.single;
      expect(request.path, '/v1/pos/customers/7/plan-entry-checkout');
      expect(request.queryParameters, {'kinds': 'flat_hour'});
      expect(result.entries.first.durationMinutes, 60);
      expect(result.entries.last.durationMinutes, isNull);
    },
  );
}
