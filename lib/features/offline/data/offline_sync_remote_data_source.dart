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
    try {
      // The server runs roughly 5 queries per sale, so a large batch (up to
      // 200 sales) can take well past Dio's default 30s timeouts.
      final response = await dio.post(
        '/v1/pos/offline/sync',
        data: {'shifts': shifts, 'sales': sales},
        options: Options(
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      return OfflineSyncResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (ConnectivityInterceptor.isConnectionError(e)) {
        throw NoInternetException();
      }
      throw ServerException.fromJson(e.response?.data);
    }
  }
}
