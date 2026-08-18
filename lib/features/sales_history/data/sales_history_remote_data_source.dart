import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../domain/sale_history.dart';

class SalesHistoryRemoteDataSource {
  SalesHistoryRemoteDataSource(this.dio);
  final Dio dio;

  Future<SalesHistoryPageData> list({
    required SaleHistoryPeriod period,
    required int page,
    int limit = 20,
  }) async {
    try {
      final response = await dio.get(
        '/v1/pos/sales/history',
        queryParameters: {
          'period': period.apiValue,
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

  Future<SalesHistorySummary> summary(SaleHistoryPeriod period) async {
    try {
      final response = await dio.get(
        '/v1/pos/sales/history/summary',
        queryParameters: {'period': period.apiValue},
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

  SaleHistoryEntry _sale(Map<String, dynamic> json) => SaleHistoryEntry(
    id: json['id'] as String,
    type: json['type'] as String,
    totalUzs: json['subtotalUzs'] as int,
    cashUzs: json['cashUzs'] as int,
    cardUzs: json['cardUzs'] as int,
    balanceUzs: json['balanceUzs'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
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
}
