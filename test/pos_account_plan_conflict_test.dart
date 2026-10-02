import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/domain/pos_entry.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';

/// Canned-response Dio adapter: records the last request and answers every
/// call with [payload].
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.payload);

  final Object payload;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// In-memory remote for bloc tests — every unused member throws.
class _FakeRemote implements PosAccountRemoteDataSource {
  PosEntryResult? planEntryResult;
  bool? lastReplacePlan;
  List<String>? lastChildIds;
  String? lastPlanKey;
  List<ActivePass> activePasses = const [];

  @override
  Future<PosEntryResult> issuePlanEntry({
    required int customerId,
    required String planKey,
    required List<String> childIds,
    bool replacePlan = false,
  }) async {
    lastPlanKey = planKey;
    lastChildIds = childIds;
    lastReplacePlan = replacePlan;
    return planEntryResult!;
  }

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async =>
      activePasses;

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _conflict = PosEntryConflict(
  childId: 'child-1',
  currentPlanKey: 'standard',
  currentPlanLabel: 'Standart',
  requestedPlanKey: 'vip',
  isInside: true,
  accruedDueUzs: 15000,
  switchable: true,
);

Customer _customer() => const Customer(
  id: 7,
  phoneNumber: '+998901234567',
  firstName: 'Dil',
  lastName: null,
  balance: 100000,
  children: [],
);

void main() {
  group('data source', () {
    test('issuePlanEntry sends replacePlan and parses conflicts', () async {
      final adapter = _FakeAdapter({
        'entries': <Object>[],
        'failures': <Object>[],
        'conflicts': [
          {
            'childId': 'child-1',
            'currentPlanKey': 'standard',
            'currentPlanLabel': 'Standart',
            'requestedPlanKey': 'vip',
            'isInside': true,
            'accruedDueUzs': 15000,
            'switchable': true,
          },
        ],
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;
      final source = PosAccountRemoteDataSourceImpl(dio);

      final result = await source.issuePlanEntry(
        customerId: 7,
        planKey: 'vip',
        childIds: const ['child-1'],
        replacePlan: true,
      );

      expect(result.conflicts, const [_conflict]);
      expect(
        (adapter.lastRequest!.data as Map<String, dynamic>)['replacePlan'],
        true,
      );
    });

    test('a response without conflicts parses as an empty list', () async {
      final adapter = _FakeAdapter({
        'entries': <Object>[],
        'failures': <Object>[],
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;
      final source = PosAccountRemoteDataSourceImpl(dio);

      final result = await source.issuePlanEntry(
        customerId: 7,
        planKey: 'standard',
        childIds: const ['child-1'],
      );

      expect(result.conflicts, isEmpty);
      expect(
        (adapter.lastRequest!.data as Map<String, dynamic>).containsKey(
          'replacePlan',
        ),
        false,
      );
    });

    test('known balance-failure codes are translated to Uzbek', () async {
      final adapter = _FakeAdapter({
        'entries': <Object>[],
        'failures': [
          {
            'childId': 'child-1',
            'code': 'VIP_PREPAYMENT_REQUIRED',
            'message': 'A cashier-issued VIP pass must be paid …',
          },
        ],
        'conflicts': <Object>[],
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;
      final source = PosAccountRemoteDataSourceImpl(dio);

      final result = await source.issuePlanEntry(
        customerId: 7,
        planKey: 'vip',
        childIds: const ['child-1'],
      );

      expect(
        result.failures.single.message,
        "VIP uchun balans yetarli emas — avval to'lov qabul qiling",
      );
    });

    test('listActivePasses parses the badge rows', () async {
      final adapter = _FakeAdapter([
        {
          'childId': 'child-1',
          'planKey': 'standard',
          'planLabel': 'Standart',
          'expiresAt': '2026-08-17T17:00:00.000Z',
          'dueTodayUzs': 25000,
        },
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;
      final source = PosAccountRemoteDataSourceImpl(dio);

      final passes = await source.listActivePasses(7);

      expect(passes, hasLength(1));
      expect(passes.single.childId, 'child-1');
      expect(passes.single.planLabel, 'Standart');
      expect(passes.single.dueTodayUzs, 25000);
      expect(adapter.lastRequest!.path, '/v1/pos/customers/7/active-passes');
    });
  });

  group('bloc', () {
    test('plan entry with conflicts lands them in lastEntryResult', () async {
      final remote = _FakeRemote()
        ..planEntryResult = const PosEntryResult(
          entries: [],
          failures: [],
          conflicts: [_conflict],
        );
      final bloc = PosAccountBloc(PosAccountRepository(remote));
      addTearDown(bloc.close);

      bloc
        ..add(PosAccountCustomerSelected(_customer()))
        ..add(
          const PosAccountPlanEntryRequested(
            planKey: 'vip',
            childIds: ['child-1'],
          ),
        );
      await bloc.stream.firstWhere((s) => s.lastEntryResult != null);

      expect(bloc.state.lastEntryResult!.conflicts, const [_conflict]);
      expect(remote.lastReplacePlan, false);
    });

    test('replacePlan passes through to the repository', () async {
      final remote = _FakeRemote()
        ..planEntryResult = const PosEntryResult(
          entries: [],
          failures: [],
          conflicts: [],
        );
      final bloc = PosAccountBloc(PosAccountRepository(remote));
      addTearDown(bloc.close);

      bloc
        ..add(PosAccountCustomerSelected(_customer()))
        ..add(
          const PosAccountPlanEntryRequested(
            planKey: 'vip',
            childIds: ['child-1'],
            replacePlan: true,
          ),
        );
      await bloc.stream.firstWhere((s) => s.lastEntryResult != null);

      expect(remote.lastReplacePlan, true);
      expect(remote.lastChildIds, ['child-1']);
    });

    test('selecting a customer loads the active-pass badges', () async {
      final remote = _FakeRemote()
        ..activePasses = [
          ActivePass(
            childId: 'child-1',
            planKey: 'standard',
            planLabel: 'Standart',
            expiresAt: DateTime.utc(2026, 8, 17, 17),
            dueTodayUzs: 25000,
          ),
        ];
      final bloc = PosAccountBloc(PosAccountRepository(remote));
      addTearDown(bloc.close);

      bloc.add(PosAccountCustomerSelected(_customer()));
      await bloc.stream.firstWhere((s) => s.activePasses.isNotEmpty);

      expect(bloc.state.activePasses.single.planLabel, 'Standart');
    });
  });
}
