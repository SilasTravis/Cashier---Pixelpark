import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../domain/market_order.dart';

/// Pixel Market parcels at this cashier's park (`/v1/pos/market/*`). The
/// backend scopes every call to the cashier's own branch.
class MarketRepository {
  MarketRepository(this.dio);
  final Dio dio;

  /// Orders on their way here: `confirmed` (the shop is packing) and
  /// `handed_over` (the shop sent it — can be received).
  Future<List<MarketOrder>> incoming() =>
      _orders(() => dio.get('/v1/pos/market/incoming'));

  /// handed_over → at_branch: the parcel is physically at the park.
  Future<MarketOrder> receive(String orderId) async {
    try {
      final response = await dio.post('/v1/pos/market/orders/$orderId/receive');
      return MarketOrder.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      throw ServerException.fromJson(error.response?.data);
    }
  }

  /// The parent's open orders for [code] (handed_over / at_branch).
  /// 404 `MARKET_PICKUP_NOT_FOUND` when there are none.
  Future<List<MarketOrder>> pickup(String code) =>
      _orders(() => dio.get('/v1/pos/market/pickups/$code'));

  /// Every at_branch order of [code] → picked_up; returns those orders.
  Future<List<MarketOrder>> handOver(String code) =>
      _orders(() => dio.post('/v1/pos/market/pickups/$code/hand-over'));

  Future<List<MarketOrder>> _orders(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      return [
        for (final raw in response.data as List)
          MarketOrder.fromJson(Map<String, dynamic>.from(raw as Map)),
      ];
    } on DioException catch (error) {
      throw ServerException.fromJson(error.response?.data);
    }
  }
}
