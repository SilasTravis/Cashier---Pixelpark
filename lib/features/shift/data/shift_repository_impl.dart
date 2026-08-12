import 'package:dartz/dartz.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failure.dart';
import '../domain/shift.dart';
import 'shift_remote_data_source.dart';

class ShiftRepository {
  ShiftRepository(this.remote);

  final ShiftRemoteDataSource remote;

  Future<Either<Failure, Shift>> openShift({int? openingCashUzs}) =>
      _call(() => remote.openShift(openingCashUzs: openingCashUzs));

  Future<Either<Failure, Shift>> closeShift({String? closingNote}) =>
      _call(() => remote.closeShift(closingNote: closingNote));

  Future<Either<Failure, Shift>> getCurrentShift() => _call(remote.getCurrentShift);

  Future<Either<Failure, Shift>> _call(Future<Shift> Function() call) async {
    try {
      return Right(await call());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code, statusCode: e.statusCode));
    } on NoInternetException {
      return Left(NoInternetFailure());
    }
  }
}
