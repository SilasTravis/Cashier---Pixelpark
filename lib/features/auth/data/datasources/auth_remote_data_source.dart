import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../models/auth_tokens_model.dart';

abstract class AuthRemoteDataSource {
  Future<LoginResponseModel> login({
    required String username,
    required String password,
  });
  Future<CurrentSessionModel> getMe();
  Future<void> logout(String refreshToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<LoginResponseModel> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        '/v1/cashier/auth/login',
        data: {'username': username, 'password': password},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return LoginResponseModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      throw ServerException.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException.fromJson(e.response?.data);
    } on FormatException {
      throw ServerException(message: "Server javobini o'qib bo'lmadi");
    }
  }

  @override
  Future<CurrentSessionModel> getMe() async {
    try {
      final response = await dio.get('/v1/cashier/auth/me');
      if (response.statusCode == 200) {
        return CurrentSessionModel.fromJson(
          response.data as Map<String, dynamic>,
        );
      }
      throw ServerException.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException.fromJson(e.response?.data);
    } on FormatException {
      throw ServerException(message: "Server javobini o'qib bo'lmadi");
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await dio.post(
        '/v1/cashier/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } on DioException {
      // Logout is best-effort — the local session is cleared regardless.
    }
  }
}
