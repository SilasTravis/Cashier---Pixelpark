import 'package:dio/dio.dart';
import 'package:dio_retry_plus/dio_retry_plus.dart';
import 'package:flutter/foundation.dart';

import '../../constants/app_constants.dart';
import '../local_source/local_source.dart';
import 'auth_interceptor.dart';
import 'token_refresher.dart';

/// Builds the shared [Dio] client: base URL (test/prod switch lives in
/// [LocalSource], defaulting to [AppConstants.defaultApiBaseUrl]), auth
/// header injection, and 401-triggered token refresh + retry.
Dio buildDio(LocalSource localSource, TokenRefresher tokenRefresher) {
  final dio =
      Dio(
          BaseOptions(
            baseUrl:
                localSource.getApiBaseUrl() ?? AppConstants.defaultApiBaseUrl,
            contentType: 'application/json',
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            connectTimeout: const Duration(seconds: 30),
          ),
        )
        ..interceptors.addAll([
          AuthInterceptor(localSource),
          LogInterceptor(
            request: kDebugMode,
            responseBody: kDebugMode,
            error: kDebugMode,
            requestBody: kDebugMode,
          ),
        ]);

  dio.interceptors.add(
    RetryInterceptor(
      dio: dio,
      retryDelays: const [Duration(seconds: 3), Duration(seconds: 2)],
      toNoInternetPageNavigator: () async {},
      refreshTokenFunction: () => tokenRefresher.refresh(),
      accessTokenGetter: () {
        final accessToken = localSource.getAccessToken();
        return accessToken == null ? '' : 'Bearer $accessToken';
      },
      forbiddenFunction: () async {},
      logPrint: (message) {
        if (kDebugMode &&
            message.contains(
              RegExp('retry|error|fail', caseSensitive: false),
            )) {
          debugPrint(message);
        }
      },
    ),
  );

  return dio;
}
