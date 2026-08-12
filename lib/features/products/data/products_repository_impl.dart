import 'package:dartz/dartz.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failure.dart';
import '../domain/product.dart';
import 'products_remote_data_source.dart';

class ProductsRepository {
  ProductsRepository(this.remote);

  final ProductsRemoteDataSource remote;

  Future<Either<Failure, List<Product>>> listProducts() async {
    try {
      return Right(await remote.listProducts());
    } on ServerException catch (e) {
      return Left(
        ServerFailure(
          message: e.message,
          code: e.code,
          statusCode: e.statusCode,
        ),
      );
    } on NoInternetException {
      return Left(NoInternetFailure());
    }
  }
}
