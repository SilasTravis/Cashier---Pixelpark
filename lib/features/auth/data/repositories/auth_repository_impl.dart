import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/local_source/local_source.dart';
import '../../domain/entities/cashier.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/auth_tokens_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this.remoteDataSource, this.localSource);

  final AuthRemoteDataSource remoteDataSource;
  final LocalSource localSource;

  @override
  Future<Either<Failure, AuthSession>> login({
    required String username,
    required String password,
  }) async {
    try {
      final loginResponse = await remoteDataSource.login(
        username: username,
        password: password,
      );
      _saveTokens(loginResponse.tokens);

      // The login response doesn't include the branch — fetch it once so
      // the shell header can show it immediately.
      final session = await remoteDataSource.getMe();
      _saveSession(session);
      return Right(
        AuthSession(cashier: session.cashier, branch: session.branch),
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

  @override
  Future<Either<Failure, AuthSession>> getCurrentSession() async {
    try {
      final session = await remoteDataSource.getMe();
      _saveSession(session);
      return Right(
        AuthSession(cashier: session.cashier, branch: session.branch),
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

  @override
  Future<void> logout() async {
    final refreshToken = localSource.getRefreshToken();
    if (refreshToken != null) {
      await remoteDataSource.logout(refreshToken);
    }
    await localSource.clearSession();
  }

  void _saveTokens(AuthTokensModel tokens) {
    localSource.setAccessToken(tokens.accessToken);
    localSource.setRefreshToken(tokens.refreshToken);
  }

  void _saveSession(CurrentSessionModel session) {
    localSource.setCashier(
      id: session.cashier.id,
      fullName: session.cashier.fullName,
      username: session.cashier.username,
      branchId: session.branch.id,
      branchName: session.branch.name,
    );
  }
}
