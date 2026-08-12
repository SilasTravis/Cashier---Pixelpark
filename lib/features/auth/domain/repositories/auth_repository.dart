import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../entities/cashier.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthSession>> login({
    required String username,
    required String password,
  });

  Future<Either<Failure, AuthSession>> getCurrentSession();

  Future<void> logout();
}
