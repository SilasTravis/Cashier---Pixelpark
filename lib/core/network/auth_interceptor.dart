import 'package:dio/dio.dart';

import '../local_source/local_source.dart';

/// Attaches the saved cashier access token to every outgoing request.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.localSource);

  final LocalSource localSource;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final accessToken = localSource.getAccessToken();
    final hasAuth = options.headers.containsKey('Authorization');
    if (!hasAuth && accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }
}
