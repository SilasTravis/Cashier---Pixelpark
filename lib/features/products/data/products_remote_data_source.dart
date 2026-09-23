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
      final response = await dio.get('/v1/pos/products');
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
