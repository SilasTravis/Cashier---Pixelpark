import 'package:dio/dio.dart';
import 'package:dio_retry_plus/dio_retry_plus.dart';
import 'package:flutter/foundation.dart';

import '../../constants/app_constants.dart';
import '../local_source/local_source.dart';
import 'auth_interceptor.dart';
import 'connectivity_interceptor.dart';
import 'token_refresher.dart';

/// Builds the shared [Dio] client: base URL (test/prod switch lives in
/// [LocalSource], defaulting to [AppConstants.defaultApiBaseUrl]), auth
/// header injection, and 401-triggered token refresh + retry. When
/// [onConnectionFailure] is given, it's called every time a request fails to
/// reach the server at all (see [ConnectivityInterceptor]).
Dio buildDio(
  LocalSource localSource,
  TokenRefresher tokenRefresher, {
  void Function()? onConnectionFailure,
}) {
  final dio =
      Dio(
          BaseOptions(
            baseUrl:
                localSource.getApiBaseUrl() ?? AppConstants.defaultApiBaseUrl,
            contentType: 'application/json',
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            // 10 s, not 30: with two retries a dead network must be noticed in seconds.
            connectTimeout: const Duration(seconds: 10),
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

  // Last, so it sees each attempt's final error after the retry logic.
  if (onConnectionFailure != null) {
    dio.interceptors.add(ConnectivityInterceptor(onConnectionFailure));
  }

  return dio;
}
