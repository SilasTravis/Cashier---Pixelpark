import 'package:dartz/dartz.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failure.dart';
import '../../offline/data/offline_store.dart';
import '../domain/discount.dart';
import '../domain/sale_receipt.dart';
import 'pos_sale_remote_data_source.dart';

class PosSaleRepository {
  PosSaleRepository(this.remote, this._store);

  final PosSaleRemoteDataSource remote;
  final OfflineStore _store;

  Future<Either<Failure, SaleReceipt>> checkout({
    required List<CheckoutLine> lines,
    required int cashUzs,
    required int cardUzs,
    String? discountId,
  }) => _call(
    () => remote.checkout(
      lines: lines,
      cashUzs: cashUzs,
      cardUzs: cardUzs,
      discountId: discountId,
    ),
  );

  /// Cached like products; offline the picker shows the last known list.
  Future<Either<Failure, List<Discount>>> fetchDiscounts() async {
    final cached = _store.cachedDiscounts();
    if (_store.isOfflineMode) return Right(cached ?? const []);
    final result = await _call(() => remote.fetchDiscounts());
    return result.fold(
      (failure) async => cached != null ? Right(cached) : Left(failure),
      (discounts) async {
        await _store.cacheDiscounts(discounts);
        return Right(discounts);
      },
    );
  }

  Future<Either<Failure, T>> _call<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
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
