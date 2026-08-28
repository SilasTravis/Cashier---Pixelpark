import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../../products/domain/product.dart';
import '../../pos_sale/domain/sale_receipt.dart';
import '../domain/active_pass.dart';
import '../domain/customer.dart';
import '../domain/kids_plan.dart';
import '../domain/parent_pass.dart';
import '../domain/playing_child.dart';
import '../domain/pos_entry.dart';

/// One product line of a combined checkout: `qty` pieces of `productId`.
typedef CheckoutLine = ({String productId, int qty});

class TopupResult {
  const TopupResult({required this.balance, required this.transactionId});

  final int balance;
  final int transactionId;
}

abstract class PosAccountRemoteDataSource {
  Future<List<Customer>> searchCustomers(String query, {int page = 1});

  Future<Customer> createCustomer({
    required String phoneNumber,
    required String fullName,
  });

  Future<Child> addChild({
    required int customerId,
    required String firstName,
    String? lastName,
    required String birthDate,
  });

  Future<Customer> updateCustomerName({
    required int customerId,
    required String fullName,
  }) => throw UnsupportedError('Customer name update is not implemented');

  Future<Child> updateChildName({
    required int customerId,
    required String childId,
    required String fullName,
  }) => throw UnsupportedError('Child name update is not implemented');

  Future<TopupResult> topup({
    required int customerId,
    required int amountUzs,
    required int cashUzs,
    required int cardUzs,
  });

  Future<List<KidsPlan>> listPlans();

  /// [replacePlan] is the cashier-confirmed plan switch — sent only after
  /// the conflict modal, never on the first attempt.
  Future<PosEntryResult> issuePlanEntry({
    required int customerId,
    required String planKey,
    required List<String> childIds,
    bool replacePlan = false,
  });

  /// Ticket-type products sold at the plan-entry checkout (socks etc.).
  Future<List<Product>> listProducts();

  /// The customer's currently-inside children with live due-so-far.
  Future<List<PlayingChild>> listPlaying(int customerId);

  /// Each child's still-valid day pass — the children-list plan badge.
  Future<List<ActivePass>> listActivePasses(int customerId);

  /// The customer's free parent QR — idempotent per day, so re-tapping
  /// re-prints the same sticker.
  Future<ParentPass> issueParentPass(int customerId);

  /// The one-stop checkout: collected cash/card top the balance up, the
  /// products are debited FROM the balance, and the day passes are issued —
  /// the plan itself is billed at exit, not here. [freeReasons] maps
  /// childId → free-entry reason key (absent = billed normally);
  /// [companions] mints that many paid HAMROH stickers from the balance.
  Future<PosEntryResult> planEntryCheckout({
    required int customerId,
    required String planKey,
    required List<String> childIds,
    required List<CheckoutLine> products,
    required int cashUzs,
    required int cardUzs,
    Map<String, String> freeReasons = const {},
    int companions = 0,
  });

  /// Server-owned terminal pricing (currently the HAMROH companion price) —
  /// so a price change never needs an app re-release.
  Future<int> fetchCompanionPriceUzs();
}

class PosAccountRemoteDataSourceImpl implements PosAccountRemoteDataSource {
  PosAccountRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<List<Customer>> searchCustomers(String query, {int page = 1}) async {
    final response = await _request(
      () => dio.get(
        '/v1/pos/customers',
        queryParameters: {
          if (query.trim().isNotEmpty) 'query': query.trim(),
          'page': page,
          'limit': 50,
        },
      ),
    );
    return (response as List)
        .map((json) => _customerFromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Customer> createCustomer({
    required String phoneNumber,
    required String fullName,
  }) async {
    final response = await _request(
      () => dio.post(
        '/v1/pos/customers',
        data: {'phoneNumber': phoneNumber, 'fullName': fullName},
      ),
    );
    return _customerFromJson(response as Map<String, dynamic>);
  }

  @override
  Future<Child> addChild({
    required int customerId,
    required String firstName,
    String? lastName,
    required String birthDate,
  }) async {
    final response = await _request(
      () => dio.post(
        '/v1/pos/customers/$customerId/children',
        data: {
          'firstName': firstName,
          if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
          'birthDate': birthDate,
        },
      ),
    );
    return _childFromJson(response as Map<String, dynamic>);
  }

  @override
  Future<Customer> updateCustomerName({
    required int customerId,
    required String fullName,
  }) async {
    final response = await _request(
      () => dio.patch(
        '/v1/pos/customers/$customerId',
        data: {'fullName': fullName.trim()},
      ),
    );
    return _customerFromJson(response as Map<String, dynamic>);
  }

  @override
  Future<Child> updateChildName({
    required int customerId,
    required String childId,
    required String fullName,
  }) async {
    final response = await _request(
      () => dio.patch(
        '/v1/pos/customers/$customerId/children/$childId',
        data: {'fullName': fullName.trim()},
      ),
    );
    return _childFromJson(response as Map<String, dynamic>);
  }

  @override
  Future<TopupResult> topup({
    required int customerId,
    required int amountUzs,
    required int cashUzs,
    required int cardUzs,
  }) async {
    final response = await _request(
      () => dio.post(
        '/v1/pos/customers/$customerId/topup',
        data: {'amountUzs': amountUzs, 'cashUzs': cashUzs, 'cardUzs': cardUzs},
      ),
    );
    final map = response as Map<String, dynamic>;
    return TopupResult(
      balance: map['balance'] as int,
      transactionId: map['transactionId'] as int,
    );
  }

  @override
  Future<List<KidsPlan>> listPlans() async {
    final response = await _request(() => dio.get('/v1/pos/plans'));
    return (response as List)
        .map((json) => _kidsPlanFromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PosEntryResult> issuePlanEntry({
    required int customerId,
    required String planKey,
    required List<String> childIds,
    bool replacePlan = false,
  }) async {
    final response = await _request(
      () => dio.post(
        '/v1/pos/customers/$customerId/plan-entry',
        data: {
          'planKey': planKey,
          'childIds': childIds,
          if (replacePlan) 'replacePlan': true,
        },
      ),
    );
    final map = response as Map<String, dynamic>;
    return PosEntryResult(
      entries: (map['entries'] as List)
          .map((json) => _posEntryFromJson(json as Map<String, dynamic>))
          .toList(),
      conflicts: _conflictsFromJson(map),
      failures: (map['failures'] as List)
          .map((json) => _posEntryFailureFromJson(json as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<List<Product>> listProducts() async {
    final response = await _request(() => dio.get('/v1/pos/products'));
    return (response as List)
        .map((json) => _productFromJson(json as Map<String, dynamic>))
        .toList();
  }

  Product _productFromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      priceUzs: json['priceUzs'] as int,
      category: json['category'] as String,
      icon: json['icon'] as String,
    );
  }

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async {
    final response = await _request(
      () => dio.get('/v1/pos/customers/$customerId/playing'),
    );
    return (response as List)
        .map((json) => _playingChildFromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async {
    final response = await _request(
      () => dio.get('/v1/pos/customers/$customerId/active-passes'),
    );
    return (response as List)
        .map((json) => _activePassFromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ParentPass> issueParentPass(int customerId) async {
    final response = await _request(
      () => dio.post('/v1/pos/customers/$customerId/parent-pass'),
    );
    final map = response as Map<String, dynamic>;
    return ParentPass(
      code: map['code'] as String,
      expiresAt: DateTime.parse(map['expiresAt'] as String).toLocal(),
      customerName: map['customerName'] as String,
    );
  }

  ActivePass _activePassFromJson(Map<String, dynamic> json) {
    return ActivePass(
      childId: json['childId'] as String,
      planKey: json['planKey'] as String?,
      planLabel: json['planLabel'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
      // Absent on older backends — badge simply shows 0 until redeploy.
      dueTodayUzs: json['dueTodayUzs'] as int? ?? 0,
      freeReason: json['freeReason'] as String?,
    );
  }

  PlayingChild _playingChildFromJson(Map<String, dynamic> json) {
    return PlayingChild(
      childId: json['childId'] as String,
      childName: json['childName'] as String,
      planName: json['planName'] as String,
      planKind: json['planKind'] as String,
      enteredAt: DateTime.parse(json['enteredAt'] as String).toLocal(),
      minutes: json['minutes'] as int,
      dueUzs: json['dueUzs'] as int,
    );
  }

  @override
  Future<PosEntryResult> planEntryCheckout({
    required int customerId,
    required String planKey,
    required List<String> childIds,
    required List<CheckoutLine> products,
    required int cashUzs,
    required int cardUzs,
    Map<String, String> freeReasons = const {},
    int companions = 0,
  }) async {
    final response = await _request(
      () => dio.post(
        '/v1/pos/customers/$customerId/plan-entry-checkout',
        data: {
          'planKey': planKey,
          'childIds': childIds,
          'products': [
            for (final line in products)
              {'productId': line.productId, 'qty': line.qty},
          ],
          'cashUzs': cashUzs,
          'cardUzs': cardUzs,
          // Omitted when unused so older backends never see the fields.
          if (freeReasons.isNotEmpty)
            'freeReasons': [
              for (final entry in freeReasons.entries)
                {'childId': entry.key, 'reason': entry.value},
            ],
          if (companions > 0) 'companions': companions,
        },
      ),
    );
    final map = response as Map<String, dynamic>;
    return PosEntryResult(
      entries: (map['entries'] as List)
          .map((json) => _posEntryFromJson(json as Map<String, dynamic>))
          .toList(),
      conflicts: _conflictsFromJson(map),
      failures: (map['failures'] as List)
          .map((json) => _posEntryFailureFromJson(json as Map<String, dynamic>))
          .toList(),
      // Absent on older backends — parsed defensively as "none".
      companionPasses: ((map['companionPasses'] as List?) ?? const [])
          .map((json) => _companionPassFromJson(json as Map<String, dynamic>))
          .toList(),
      balance: map['balance'] as int?,
      productSale: map['productSale'] == null
          ? null
          : _saleReceiptFromJson(map['productSale'] as Map<String, dynamic>),
      productsTotalUzs: (map['productsTotalUzs'] as int?) ?? 0,
    );
  }

  CompanionPass _companionPassFromJson(Map<String, dynamic> json) {
    return CompanionPass(
      code: json['code'] as String,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String).toLocal(),
    );
  }

  @override
  Future<int> fetchCompanionPriceUzs() async {
    final response = await _request(() => dio.get('/v1/pos/config'));
    return (response as Map<String, dynamic>)['companionPriceUzs'] as int;
  }

  SaleReceipt _saleReceiptFromJson(Map<String, dynamic> json) => SaleReceipt(
    id: json['id'] as String,
    subtotalUzs: json['subtotalUzs'] as int,
    cashUzs: json['cashUzs'] as int,
    cardUzs: json['cardUzs'] as int,
    balanceUzs: (json['balanceUzs'] as int?) ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    items: (json['items'] as List)
        .map(
          (item) => SaleReceiptItem(
            productId: item['productId'] as String,
            nameSnapshot: item['nameSnapshot'] as String,
            priceSnapshotUzs: item['priceSnapshotUzs'] as int,
            qty: item['qty'] as int,
            lineTotalUzs: item['lineTotalUzs'] as int,
          ),
        )
        .toList(),
  );

  /// Absent on older backends — parsed defensively as "no conflicts".
  List<PosEntryConflict> _conflictsFromJson(Map<String, dynamic> map) {
    return ((map['conflicts'] as List?) ?? const [])
        .map((json) => _posEntryConflictFromJson(json as Map<String, dynamic>))
        .toList();
  }

  PosEntryConflict _posEntryConflictFromJson(Map<String, dynamic> json) {
    return PosEntryConflict(
      childId: json['childId'] as String,
      currentPlanKey: json['currentPlanKey'] as String?,
      currentPlanLabel: json['currentPlanLabel'] as String,
      requestedPlanKey: json['requestedPlanKey'] as String,
      isInside: json['isInside'] as bool,
      accruedDueUzs: json['accruedDueUzs'] as int,
      switchable: json['switchable'] as bool,
    );
  }

  Future<dynamic> _request(Future<Response> Function() call) async {
    try {
      final response = await call();
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      throw ServerException.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException.fromJson(e.response?.data);
    }
  }

  Child _childFromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String?,
      birthDate: DateTime.parse(json['birthDate'] as String),
    );
  }

  Customer _customerFromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int,
      phoneNumber: json['phoneNumber'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String?,
      balance: json['balance'] as int,
      children: (json['children'] as List)
          .map((child) => _childFromJson(child as Map<String, dynamic>))
          .toList(),
    );
  }

  KidsPlan _kidsPlanFromJson(Map<String, dynamic> json) {
    return KidsPlan(
      key: json['key'] as String,
      name: json['name'] as String,
      kind: json['kind'] == 'flat_day'
          ? KidsPlanKind.flatDay
          : KidsPlanKind.perMinuteTiers,
      firstMinuteUzs: json['firstMinuteUzs'] as int?,
      secondMinuteUzs: json['secondMinuteUzs'] as int?,
      extraMinuteUzs: json['extraMinuteUzs'] as int?,
      flatUzs: json['flatUzs'] as int?,
    );
  }

  PosEntry _posEntryFromJson(Map<String, dynamic> json) {
    return PosEntry(
      childId: json['childId'] as String,
      token: json['token'] as String,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
    );
  }

  PosEntryFailure _posEntryFailureFromJson(Map<String, dynamic> json) {
    final code = json['code'] as String;
    return PosEntryFailure(
      childId: json['childId'] as String,
      code: code,
      // Backend failure messages are English; the codes the cashier can
      // actually act on get an Uzbek text here.
      message: switch (code) {
        'VIP_PREPAYMENT_REQUIRED' =>
          "VIP uchun balans yetarli emas — avval to'lov qabul qiling",
        'PLAN_SWITCH_BALANCE_INSUFFICIENT' =>
          "Balans yetarli emas — avval balansni to'ldiring",
        _ => json['message'] as String,
      },
    );
  }
}
