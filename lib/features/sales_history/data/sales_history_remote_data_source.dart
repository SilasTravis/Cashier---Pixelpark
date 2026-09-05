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
        count: _int(json['salesCount']),
        totalUzs: _int(json['subtotalUzs']),
        cashUzs: _int(json['cashUzs']),
        cardUzs: _int(json['cardUzs']),
        balanceUzs: _int(json['balanceUzs']),
        refundedUzs: _int(json['refundedUzs']),
      );
    } on DioException catch (error) {
      throw ServerException.fromJson(error.response?.data);
    }
  }

  Future<SaleHistoryEntry> refund({
    required String saleId,
    required int amountUzs,
    required SaleRefundMethod method,
    required String reason,
    required String requestId,
    List<String> gatePassIds = const [],
  }) async {
    try {
      final response = await dio.post(
        '/v1/pos/sales/$saleId/refunds',
        data: {
          'amountUzs': amountUzs,
          'method': method.apiValue,
          'reason': reason,
          'requestId': requestId,
          if (gatePassIds.isNotEmpty) 'gatePassIds': gatePassIds,
        },
      );
      return _sale(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (error) {
      throw ServerException.fromJson(error.response?.data);
    }
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  SaleHistoryEntry _sale(Map<String, dynamic> json) {
    final subtotalUzs = _int(json['subtotalUzs']);
    final cashUzs = _int(json['cashUzs']);
    final cardUzs = _int(json['cardUzs']);
    final refundedUzs = _int(json['refundedUzs']);
    return SaleHistoryEntry(
      id: json['id'] as String,
      type: json['type'] as String,
      totalUzs: subtotalUzs,
      cashUzs: cashUzs,
      cardUzs: cardUzs,
      balanceUzs: _int(json['balanceUzs']),
      refundedUzs: refundedUzs,
      refundedCashUzs: _int(json['refundedCashUzs']),
      refundedCardUzs: _int(json['refundedCardUzs']),
      refundedBalanceUzs: _int(json['refundedBalanceUzs']),
      netUzs: _int(json['netUzs'], fallback: subtotalUzs - refundedUzs),
      refundableUzs: _int(
        json['refundableUzs'],
        fallback: subtotalUzs - refundedUzs,
      ),
      refundableCashUzs: _int(json['refundableCashUzs'], fallback: cashUzs),
      refundableCardUzs: _int(json['refundableCardUzs'], fallback: cardUzs),
      refundableBalanceUzs: _int(json['refundableBalanceUzs']),
      canRefund: json['canRefund'] == true,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      customer: json['customer'] == null
          ? null
          : _customer(Map<String, dynamic>.from(json['customer'] as Map)),
      items: ((json['items'] as List?) ?? const []).map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        return SaleHistoryItem(
          name: item['nameSnapshot'] as String,
          priceUzs: _int(item['priceSnapshotUzs']),
          qty: _int(item['qty']),
          totalUzs: _int(item['lineTotalUzs']),
        );
      }).toList(),
      passes: ((json['passes'] as List?) ?? const []).map((raw) {
        final pass = Map<String, dynamic>.from(raw as Map);
        final enteredAt = pass['enteredAt'] as String?;
        return SaleGatePass(
          id: pass['id'] as String,
          childId: pass['childId'] as String,
          code: pass['code'] as String,
          planLabel: pass['planLabel'] as String,
          priceUzs: _int(pass['priceUzs']),
          refundable: pass['refundable'] == true,
          enteredAt: enteredAt == null
              ? null
              : DateTime.parse(enteredAt).toLocal(),
        );
      }).toList(),
      refunds: ((json['refunds'] as List?) ?? const []).map((raw) {
        final refund = Map<String, dynamic>.from(raw as Map);
        return SaleHistoryRefund(
          id: refund['id'] as String,
          amountUzs: _int(refund['amountUzs']),
          method: _refundMethod(refund['method']),
          reason: refund['reason'] as String,
          refundedByType: refund['refundedByType'] as String,
          refundedByName: refund['refundedByName'] as String,
          createdAt: DateTime.parse(refund['createdAt'] as String).toLocal(),
        );
      }).toList(),
    );
  }

  SaleRefundMethod _refundMethod(Object? value) => switch (value) {
    'card' => SaleRefundMethod.card,
    'balance' => SaleRefundMethod.balance,
    _ => SaleRefundMethod.cash,
  };

  int _int(Object? value, {int fallback = 0}) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? fallback,
    _ => fallback,
  };

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
