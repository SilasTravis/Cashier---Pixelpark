import 'package:dartz/dartz.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failure.dart';
import '../../../core/local_source/local_source.dart';
import '../../offline/data/offline_store.dart';
import '../domain/product.dart';
import 'products_remote_data_source.dart';

/// Every good fetch is cached per branch, so the Savdo grid still works
/// offline — and after an app restart during an outage.
class ProductsRepository {
  ProductsRepository(this.remote, this._store, this._local);

  final ProductsRemoteDataSource remote;
  final OfflineStore _store;
  final LocalSource _local;

  Future<Either<Failure, List<Product>>> listProducts() async {
    final branchId = _local.getBranchId();
    final cached = branchId == null ? null : _store.cachedProducts(branchId);
    if (_store.isOfflineMode) {
      return cached != null
          ? Right(cached)
          : Left(
              CacheFailure(
                message: 'Mahsulotlar hali yuklanmagan — internet kerak',
              ),
            );
    }
    try {
      final products = await remote.listProducts();
      if (branchId != null) await _store.cacheProducts(branchId, products);
      return Right(products);
    } on ServerException catch (e) {
      if (cached != null) return Right(cached);
      return Left(
        ServerFailure(
          message: e.message,
          code: e.code,
          statusCode: e.statusCode,
        ),
      );
    } on NoInternetException {
      if (cached != null) return Right(cached);
      return Left(NoInternetFailure());
    }
  }
}
