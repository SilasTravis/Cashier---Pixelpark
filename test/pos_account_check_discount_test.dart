import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/domain/pos_entry.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';

/// In-memory remote for the "Butun chek" plumbing — every unused member
/// throws.
class _FakeRemote implements PosAccountRemoteDataSource {
  String? lastCheckDiscountId;
  Map<String, String>? lastEntryDiscounts;
  ({String code, String childId})? lastPromoCode;

  /// Every `fetchDiscounts` call's scope, in order.
  final List<DiscountScope> discountFetches = [];

  /// When set, `planEntryCheckout` throws a server error with this code.
  String? checkoutErrorCode;

  @override
  Future<PosEntryResult> planEntryCheckout({
    required int customerId,
    required String? planKey,
    required List<String> childIds,
    required List<CheckoutLine> products,
    required int cashUzs,
    required int cardUzs,
    Map<String, String> entryDiscounts = const {},
    int companions = 0,
    String? discountId,
    ({String code, String childId})? promoCode,
    String? checkDiscountId,
    bool replacePlan = false,
  }) async {
    lastCheckDiscountId = checkDiscountId;
    lastEntryDiscounts = entryDiscounts;
    lastPromoCode = promoCode;
    if (checkoutErrorCode != null) {
      throw ServerException(message: 'refused', code: checkoutErrorCode);
    }
    return const PosEntryResult(entries: [], failures: []);
  }

  @override
  Future<List<Discount>> fetchDiscounts({
    DiscountScope scope = DiscountScope.goods,
  }) async {
    discountFetches.add(scope);
    return scope == DiscountScope.check
        ? const [
            Discount(
              id: 'check-1',
              name: 'Oila',
              kind: DiscountKind.percent,
              value: 10,
              scope: DiscountScope.check,
            ),
          ]
        : const [];
  }

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => const [];

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Canned-response Dio adapter that records the last request.
class _RecordingAdapter implements HttpClientAdapter {
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
      jsonEncode({'entries': <Object>[], 'failures': <Object>[]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

const _customer = Customer(
  id: 7,
  phoneNumber: '+998901112233',
  firstName: 'Dil',
  lastName: null,
  balance: 100000,
  children: [],
);

void main() {
  late _FakeRemote remote;
  late PosAccountBloc bloc;

  /// Opens the customer and waits until the bloc has settled on it.
  Future<void> selectCustomer() async {
    bloc.add(const PosAccountCustomerSelected(_customer));
    await bloc.stream.firstWhere((s) => s.selectedCustomer?.id == _customer.id);
    // Selecting a customer fetches nothing from the discount catalog, but
    // start every assertion from a clean slate anyway.
    remote.discountFetches.clear();
  }

  setUp(() {
    remote = _FakeRemote();
    bloc = PosAccountBloc(PosAccountRepository(remote));
    addTearDown(bloc.close);
  });

  test('fetches the check catalog into state.checkDiscounts', () async {
    bloc.add(const PosAccountDiscountsRequested(scope: DiscountScope.check));
    await pumpEventQueue();
    expect(bloc.state.checkDiscounts.single.id, 'check-1');
    expect(remote.discountFetches, [DiscountScope.check]);
  });

  test('sends checkDiscountId with the checkout', () async {
    await selectCustomer();
    bloc.add(
      const PosAccountCheckoutRequested(
        planKey: 'vip',
        childIds: ['k1', 'k2'],
        products: [],
        cashUzs: 0,
        cardUzs: 0,
        checkDiscountId: 'check-1',
      ),
    );
    await pumpEventQueue();
    expect(remote.lastCheckDiscountId, 'check-1');
    expect(remote.lastEntryDiscounts, isEmpty);
    expect(remote.lastPromoCode, isNull);
  });

  test('DISCOUNT_NOT_AVAILABLE refetches the check catalog', () async {
    await selectCustomer();
    remote.checkoutErrorCode = 'DISCOUNT_NOT_AVAILABLE';
    bloc.add(
      const PosAccountCheckoutRequested(
        planKey: 'vip',
        childIds: ['k1'],
        products: [],
        cashUzs: 0,
        cardUzs: 0,
        checkDiscountId: 'check-1',
      ),
    );
    await pumpEventQueue();
    expect(remote.discountFetches, contains(DiscountScope.check));
  });

  group('data source wire', () {
    Future<Map<String, dynamic>> checkoutBody({String? checkDiscountId}) async {
      final adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;
      await PosAccountRemoteDataSourceImpl(dio).planEntryCheckout(
        customerId: 7,
        planKey: 'vip',
        childIds: const ['k1'],
        products: const [],
        cashUzs: 0,
        cardUzs: 0,
        checkDiscountId: checkDiscountId,
      );
      return adapter.lastRequest!.data as Map<String, dynamic>;
    }

    test('checkDiscountId is sent when set', () async {
      expect(
        (await checkoutBody(checkDiscountId: 'check-1'))['checkDiscountId'],
        'check-1',
      );
    });

    test('checkDiscountId is omitted when null (older backends)', () async {
      expect(await checkoutBody(), isNot(contains('checkDiscountId')));
    });
  });
}
