import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../domain/sale_history.dart';
import '../../pos_account/domain/customer.dart';

class SalesHistoryRemoteDataSource {
  SalesHistoryRemoteDataSource(this.dio);
  final Dio dio;

  Future<SalesHistoryPageData> list({
    SaleHistoryPeriod? period,
    DateTime? from,
    DateTime? to,
    String? productId,
    required int page,
    int limit = 100,
  }) async {
    try {
      final response = await dio.get(
        '/v1/pos/sales/history',
        queryParameters: {
          if (period != null) 'period': period.apiValue,
          if (from != null) 'from': _date(from),
          if (to != null) 'to': _date(to),
          'productId': ?productId,
          'page': page,
          'limit': limit,
        },
      );
      final json = Map<String, dynamic>.from(response.data as Map);
      return SalesHistoryPageData(
        items: (json['items'] as List)
            .map((item) => _sale(Map<String, dynamic>.from(item as Map)))
            .toList(),
        total: json['total'] as int,
      );
    } on DioException catch (error) {
      throw ServerException.fromJson(error.response?.data);
    }
  }

  Future<SalesHistorySummary> summary({
    SaleHistoryPeriod? period,
    DateTime? from,
    DateTime? to,
    String? productId,
  }) async {
    try {
      final response = await dio.get(
        '/v1/pos/sales/history/summary',
        queryParameters: {
          if (period != null) 'period': period.apiValue,
          if (from != null) 'from': _date(from),
          if (to != null) 'to': _date(to),
          'productId': ?productId,
        },
      );
      final json = Map<String, dynamic>.from(response.data as Map);
      return SalesHistorySummary(
        count: json['salesCount'] as int,
        totalUzs: json['subtotalUzs'] as int,
        cashUzs: json['cashUzs'] as int,
        cardUzs: json['cardUzs'] as int,
        balanceUzs: json['balanceUzs'] as int,
      );
    } on DioException catch (error) {
      throw ServerException.fromJson(error.response?.data);
    }
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  SaleHistoryEntry _sale(Map<String, dynamic> json) => SaleHistoryEntry(
    id: json['id'] as String,
    type: json['type'] as String,
    totalUzs: json['subtotalUzs'] as int,
    cashUzs: json['cashUzs'] as int,
    cardUzs: json['cardUzs'] as int,
    balanceUzs: json['balanceUzs'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    customer: json['customer'] == null
        ? null
        : _customer(Map<String, dynamic>.from(json['customer'] as Map)),
    items: (json['items'] as List).map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      return SaleHistoryItem(
        name: item['nameSnapshot'] as String,
        priceUzs: item['priceSnapshotUzs'] as int,
        qty: item['qty'] as int,
        totalUzs: item['lineTotalUzs'] as int,
      );
    }).toList(),
  );

  Customer _customer(Map<String, dynamic> json) => Customer(
    id: json['id'] as int,
    phoneNumber: json['phoneNumber'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String?,
    balance: json['balance'] as int,
    children: (json['children'] as List).map((raw) {
      final child = Map<String, dynamic>.from(raw as Map);
      return Child(
        id: child['id'] as String,
        firstName: child['firstName'] as String,
        lastName: child['lastName'] as String?,
        birthDate: DateTime.parse(child['birthDate'] as String),
      );
    }).toList(),
  );
}
