import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/network/connectivity_interceptor.dart';
import '../domain/discount.dart';
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
    String? discountId,
  });

  /// Active discount catalog — best-effort at the call site: an older
  /// backend or a transient failure just hides the picker, it never blocks
  /// checkout.
  Future<List<Discount>> fetchDiscounts();
}

class PosSaleRemoteDataSourceImpl implements PosSaleRemoteDataSource {
  PosSaleRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<SaleReceipt> checkout({
    required List<CheckoutLine> lines,
    required int cashUzs,
    required int cardUzs,
    String? discountId,
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
          // Omitted (never sent as null) when no discount is selected —
          // same forward-compat convention as `entryDiscounts`.
          'discountId': ?discountId,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return SaleReceipt.fromJson(response.data as Map<String, dynamic>);
      }
      throw ServerException.fromJson(response.data);
    } on DioException catch (e) {
      // No answer at all (timeout, dropped connection): the server may
      // still have saved the sale, so the caller must not treat this like
      // a rejection. A real fix needs an idempotency key on POST /pos/sales.
      if (ConnectivityInterceptor.isConnectionError(e)) {
        throw NoInternetException();
      }
      throw ServerException.fromJson(e.response?.data);
    }
  }

  @override
  Future<List<Discount>> fetchDiscounts() async {
    try {
      final response = await dio.get('/v1/pos/discounts');
      return (response.data as List)
          .map((json) => Discount.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ServerException.fromJson(e.response?.data);
    }
  }
}
