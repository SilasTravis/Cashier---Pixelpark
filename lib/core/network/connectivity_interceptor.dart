import 'dart:io';

import 'package:dio/dio.dart';

/// Tells the connectivity monitor when a real request failed to reach the
/// server, so the offline prompt can appear right after a failed action
/// instead of waiting for the next health poll. Never swallows the error.
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor(this._onConnectionFailure);

  final void Function() _onConnectionFailure;

  /// `Options(extra: {backgroundKey: true})` marks a request nobody asked
  /// for (a periodic refresh). Its connection failures are not reported.
  static const backgroundKey = 'background';

  static bool isConnectionError(DioException e) => switch (e.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => true,
    DioExceptionType.unknown => e.error is SocketException,
    _ => false,
  };

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final background = err.requestOptions.extra[backgroundKey] == true;
    if (!background && isConnectionError(err)) _onConnectionFailure();
    handler.next(err);
  }
}
