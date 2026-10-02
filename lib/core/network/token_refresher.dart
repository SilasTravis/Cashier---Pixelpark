import 'package:dio/dio.dart';

import '../../constants/app_constants.dart';
import '../../router/app_navigator.dart';
import '../local_source/local_source.dart';

/// Exchanges the stored refresh token for a fresh pair. Used by the retry
/// interceptor on a 401. When the refresh token itself is rejected the
/// session is over: local data is cleared and the app returns to login.
/// Mirrors pexel_app's `TokenRefresher`, minus the mobile-only session-
/// snapshot/offline-cache machinery this desktop app doesn't have.
class TokenRefresher {
  TokenRefresher(this.localSource, {Dio? dio}) : _dio = dio ?? _createDio();

  final LocalSource localSource;

  /// Own bare client so a 401 on the refresh call can never re-enter the
  /// retry/refresh interceptors of the main [Dio].
  final Dio _dio;

  static Dio _createDio() => Dio(
    BaseOptions(
      contentType: 'application/json',
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      connectTimeout: const Duration(seconds: 30),
    ),
  );

  Future<void>? _inFlight;

  /// Deduplicates concurrent 401s: the backend rotates the refresh token on
  /// every call, so a second parallel attempt would send an already-revoked
  /// token and wrongly end the session.
  Future<void> refresh() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<void> _refresh() async {
    final refreshToken = localSource.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _endSession();
      return;
    }

    try {
      final baseUrl =
          localSource.getApiBaseUrl() ?? AppConstants.defaultApiBaseUrl;
      final response = await _dio.post(
        '$baseUrl/v1/cashier/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final tokens = response.data['tokens'];
      if (tokens == null) {
        await _endSession();
        return;
      }
      localSource.setAccessToken(tokens['accessToken'] as String?);
      localSource.setRefreshToken(tokens['refreshToken'] as String?);
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      // Only a definitive rejection kills the session; network hiccups just
      // let the original request fail and be retried later.
      if (status == 400 || status == 401 || status == 403) {
        await _endSession();
      }
    } catch (_) {
      // Malformed response — treat as transient, keep the session.
    }
  }

  Future<void> _endSession() async {
    await localSource.clearSession();
    rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      Routes.login,
      (route) => false,
    );
  }
}
