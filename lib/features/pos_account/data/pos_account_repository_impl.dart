import 'package:dartz/dartz.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failure.dart';
import '../domain/customer.dart';
import '../domain/gate_pass.dart';
import 'pos_account_remote_data_source.dart';

class PosAccountRepository {
  PosAccountRepository(this.remote);

  final PosAccountRemoteDataSource remote;

  Future<Either<Failure, List<Customer>>> searchCustomers(String phone) =>
      _call(() => remote.searchCustomers(phone));

  Future<Either<Failure, Customer>> createCustomer({
    required String phoneNumber,
    required String fullName,
  }) => _call(
    () => remote.createCustomer(phoneNumber: phoneNumber, fullName: fullName),
  );

  Future<Either<Failure, Child>> addChild({
    required int customerId,
    required String firstName,
    String? lastName,
    required String birthDate,
  }) => _call(
    () => remote.addChild(
      customerId: customerId,
      firstName: firstName,
      lastName: lastName,
      birthDate: birthDate,
    ),
  );

  Future<Either<Failure, TopupResult>> topup({
    required int customerId,
    required int amountUzs,
    required int cashUzs,
    required int cardUzs,
  }) => _call(
    () => remote.topup(
      customerId: customerId,
      amountUzs: amountUzs,
      cashUzs: cashUzs,
      cardUzs: cardUzs,
    ),
  );

  Future<Either<Failure, IssuedPasses>> issuePasses({
    required int customerId,
    required String productId,
    required List<String> childIds,
    required int cashUzs,
    required int cardUzs,
  }) => _call(
    () => remote.issuePasses(
      customerId: customerId,
      productId: productId,
      childIds: childIds,
      cashUzs: cashUzs,
      cardUzs: cardUzs,
    ),
  );

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
