import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../domain/product.dart';

abstract class ProductsRemoteDataSource {
  Future<List<Product>> listProducts();
}

class ProductsRemoteDataSourceImpl implements ProductsRemoteDataSource {
  ProductsRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<List<Product>> listProducts() async {
    try {
      // includeOffline: the offline-only plan items are cached with the rest
      // and shown only in offline mode (an older backend ignores the flag).
      final response = await dio.get(
        '/v1/pos/products',
        queryParameters: {'includeOffline': 'true'},
      );
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      throw ServerException.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException.fromJson(e.response?.data);
    }
  }
}
