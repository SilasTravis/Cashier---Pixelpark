import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../domain/sale_receipt.dart';

class CheckoutLine {
  const CheckoutLine({required this.productId, required this.qty});

  final String productId;
  final int qty;
}

abstract class PosSaleRemoteDataSource {
  Future<SaleReceipt> checkout({
    required List<CheckoutLine> lines,
    required int cashUzs,
    required int cardUzs,
  });
}

class PosSaleRemoteDataSourceImpl implements PosSaleRemoteDataSource {
  PosSaleRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<SaleReceipt> checkout({
    required List<CheckoutLine> lines,
    required int cashUzs,
    required int cardUzs,
  }) async {
    try {
      final response = await dio.post(
        '/v1/pos/sales',
        data: {
          'lines': [
            for (final line in lines)
              {'productId': line.productId, 'qty': line.qty},
          ],
          'cashUzs': cashUzs,
          'cardUzs': cardUzs,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _receiptFromJson(response.data as Map<String, dynamic>);
      }
      throw ServerException.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException.fromJson(e.response?.data);
    }
  }

  SaleReceipt _receiptFromJson(Map<String, dynamic> json) {
    return SaleReceipt(
      id: json['id'] as String,
      subtotalUzs: json['subtotalUzs'] as int,
      cashUzs: json['cashUzs'] as int,
      cardUzs: json['cardUzs'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List)
          .map((item) => _itemFromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  SaleReceiptItem _itemFromJson(Map<String, dynamic> json) {
    return SaleReceiptItem(
      productId: json['productId'] as String,
      nameSnapshot: json['nameSnapshot'] as String,
      priceSnapshotUzs: json['priceSnapshotUzs'] as int,
      qty: json['qty'] as int,
      lineTotalUzs: json['lineTotalUzs'] as int,
    );
  }
}
