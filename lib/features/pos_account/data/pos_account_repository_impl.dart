import 'package:dartz/dartz.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failure.dart';
import '../../products/domain/product.dart';
import '../domain/active_pass.dart';
import '../domain/customer.dart';
import '../domain/kids_plan.dart';
import '../domain/playing_child.dart';
import '../domain/pos_entry.dart';
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

  Future<Either<Failure, List<KidsPlan>>> listPlans() =>
      _call(() => remote.listPlans());

  Future<Either<Failure, PosEntryResult>> issuePlanEntry({
    required int customerId,
    required String planKey,
    required List<String> childIds,
    bool replacePlan = false,
  }) => _call(
    () => remote.issuePlanEntry(
      customerId: customerId,
      planKey: planKey,
      childIds: childIds,
      replacePlan: replacePlan,
    ),
  );

  Future<Either<Failure, List<Product>>> listProducts() =>
      _call(() => remote.listProducts());

  Future<Either<Failure, List<PlayingChild>>> listPlaying(int customerId) =>
      _call(() => remote.listPlaying(customerId));

  Future<Either<Failure, List<ActivePass>>> listActivePasses(int customerId) =>
      _call(() => remote.listActivePasses(customerId));

  Future<Either<Failure, PosEntryResult>> planEntryCheckout({
    required int customerId,
    required String planKey,
    required List<String> childIds,
    required List<CheckoutLine> products,
    required int cashUzs,
    required int cardUzs,
  }) => _call(
    () => remote.planEntryCheckout(
      customerId: customerId,
      planKey: planKey,
      childIds: childIds,
      products: products,
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
