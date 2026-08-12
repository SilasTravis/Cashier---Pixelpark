import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../domain/customer.dart';
import '../domain/gate_pass.dart';

class TopupResult {
  const TopupResult({required this.balance, required this.transactionId});

  final int balance;
  final int transactionId;
}

abstract class PosAccountRemoteDataSource {
  Future<List<Customer>> searchCustomers(String phone);

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

  Future<TopupResult> topup({
    required int customerId,
    required int amountUzs,
    required int cashUzs,
    required int cardUzs,
  });

  Future<IssuedPasses> issuePasses({
    required int customerId,
    required String productId,
    required List<String> childIds,
    required int cashUzs,
    required int cardUzs,
  });
}

class PosAccountRemoteDataSourceImpl implements PosAccountRemoteDataSource {
  PosAccountRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<List<Customer>> searchCustomers(String phone) async {
    final response = await _request(
      () => dio.get('/v1/pos/customers', queryParameters: {'phone': phone}),
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
  Future<IssuedPasses> issuePasses({
    required int customerId,
    required String productId,
    required List<String> childIds,
    required int cashUzs,
    required int cardUzs,
  }) async {
    final response = await _request(
      () => dio.post(
        '/v1/pos/customers/$customerId/passes',
        data: {
          'productId': productId,
          'childIds': childIds,
          'cashUzs': cashUzs,
          'cardUzs': cardUzs,
        },
      ),
    );
    final map = response as Map<String, dynamic>;
    final sale = map['sale'] as Map<String, dynamic>;
    final passes = (map['passes'] as List)
        .map((json) => _gatePassFromJson(json as Map<String, dynamic>))
        .toList();
    return IssuedPasses(saleId: sale['id'] as String, passes: passes);
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

  GatePass _gatePassFromJson(Map<String, dynamic> json) {
    return GatePass(
      id: json['id'] as String,
      childId: json['childId'] as String,
      code: json['code'] as String,
      planLabel: json['planLabel'] as String,
      priceUzs: json['priceUzs'] as int,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}
