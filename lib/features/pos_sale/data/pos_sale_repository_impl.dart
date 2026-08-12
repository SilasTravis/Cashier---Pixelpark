import 'package:dartz/dartz.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failure.dart';
import '../domain/sale_receipt.dart';
import 'pos_sale_remote_data_source.dart';

class PosSaleRepository {
  PosSaleRepository(this.remote);

  final PosSaleRemoteDataSource remote;

  Future<Either<Failure, SaleReceipt>> checkout({
    required List<CheckoutLine> lines,
    required int cashUzs,
    required int cardUzs,
  }) async {
    try {
      return Right(
        await remote.checkout(lines: lines, cashUzs: cashUzs, cardUzs: cardUzs),
      );
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
