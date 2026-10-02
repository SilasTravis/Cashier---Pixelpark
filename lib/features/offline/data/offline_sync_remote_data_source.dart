import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/network/connectivity_interceptor.dart';

enum OfflineSyncStatus {
  created,
  duplicate,
  rejected;

  static OfflineSyncStatus fromWire(Object? value) => switch (value) {
    'created' => created,
    'duplicate' => duplicate,
    _ => rejected,
  };
}

/// The server's verdict on one shift or sale of a sync request.
class OfflineSyncItemResult extends Equatable {
  const OfflineSyncItemResult({
    required this.offlineRequestId,
    required this.status,
    this.serverId,
    this.code,
    this.message,
  });

  final String offlineRequestId;
  final OfflineSyncStatus status;

  /// `shiftId` / `saleId` on the server — null when rejected.
  final String? serverId;
  final String? code;

  /// Uzbek text of the `{uz, ru, en}` message, falling back to English.
  final String? message;

  factory OfflineSyncItemResult.fromJson(
    Map<String, dynamic> json,
    String idKey,
  ) {
    final rawMessage = json['message'];
    return OfflineSyncItemResult(
      offlineRequestId: json['offlineRequestId'] as String,
      status: OfflineSyncStatus.fromWire(json['status']),
      serverId: json[idKey] as String?,
      code: json['code'] as String?,
      message: rawMessage is Map
          ? (rawMessage['uz'] ?? rawMessage['en'])?.toString()
          : rawMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    offlineRequestId,
    status,
    serverId,
    code,
    message,
  ];
}

class OfflineSyncResult {
  const OfflineSyncResult({required this.shifts, required this.sales});

  final List<OfflineSyncItemResult> shifts;
  final List<OfflineSyncItemResult> sales;

  factory OfflineSyncResult.fromJson(Map<String, dynamic> json) =>
      OfflineSyncResult(
        shifts: [
          for (final item in json['shifts'] as List? ?? const [])
            OfflineSyncItemResult.fromJson(
              Map<String, dynamic>.from(item as Map),
              'shiftId',
            ),
        ],
        sales: [
          for (final item in json['sales'] as List? ?? const [])
            OfflineSyncItemResult.fromJson(
              Map<String, dynamic>.from(item as Map),
              'saleId',
            ),
        ],
      );
}

/// Thrown when the server rejects the WHOLE request (HTTP 400/422) because
/// its payload failed validation — qty/price/discount out of range, an empty
/// line list, an unknown key, and so on. Unlike [ServerException], this is
/// specific enough for [OfflineSyncService] to know the request itself (not
/// the connection) was the problem, so it can retry the other sales solo
/// instead of treating the whole sync run as a transport failure.
class OfflineSyncValidationException implements Exception {
  OfflineSyncValidationException({required this.message, this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'OfflineSyncValidationException($code): $message';
}

abstract class OfflineSyncRemoteDataSource {
  Future<OfflineSyncResult> sync({
    required List<Map<String, dynamic>> shifts,
    required List<Map<String, dynamic>> sales,
  });
}

class OfflineSyncRemoteDataSourceImpl implements OfflineSyncRemoteDataSource {
  OfflineSyncRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<OfflineSyncResult> sync({
    required List<Map<String, dynamic>> shifts,
    required List<Map<String, dynamic>> sales,
  }) async {
    final Response<dynamic> response;
    try {
      // The server runs roughly 5 queries per sale, so a large batch (up to
      // 200 sales) can take well past Dio's default 30s timeouts.
      response = await dio.post(
        '/v1/pos/offline/sync',
        data: {'shifts': shifts, 'sales': sales},
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
    } on DioException catch (e) {
      if (ConnectivityInterceptor.isConnectionError(e)) {
        throw NoInternetException();
      }
      final parsed = ServerException.fromJson(e.response?.data);
      final statusCode = e.response?.statusCode;
      // 400/422: the payload failed validation. 413: the batch itself is too
      // big (the server caps the body at 1 MB) — splitting it into solo
      // requests fixes that too, so the service should retry it the same
      // way rather than treating it as a permanent transport failure.
      if (statusCode == 400 || statusCode == 422 || statusCode == 413) {
        throw OfflineSyncValidationException(
          message: parsed.message,
          code: parsed.code,
        );
      }
      throw parsed;
    }
    try {
      return OfflineSyncResult.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      // A 200 with a body that isn't the expected JSON shape — e.g. a
      // captive-portal HTML page — is a transport-level problem, not a sale
      // being rejected, so the service should treat it as one.
      throw ServerException(message: 'Server javobi noto‘g‘ri');
    }
  }
}
