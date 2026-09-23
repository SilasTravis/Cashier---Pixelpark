import 'dart:typed_data';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/features/offline/data/offline_sync_remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the effective [RequestOptions] Dio hands to the adapter, and
/// answers every request with a fixed empty sync response — no network
/// involved. Same shape as `_CapturingAdapter` in `test/release_source_test.dart`.
class _CapturingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{"shifts": [], "sales": []}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A hand-written fake transport: answers every request with a fixed
/// body/status/content-type, regardless of URL — same shape as
/// `_FixedResponseAdapter` in `test/release_source_test.dart`. No mocking
/// library is available in this repo.
class _FixedResponseAdapter implements HttpClientAdapter {
  _FixedResponseAdapter(
    this.body, {
    this.statusCode = 200,
    this.contentType = Headers.jsonContentType,
  });

  final String body;
  final int statusCode;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Throws a connection-level [DioException] (no HTTP response at all) — the
/// shape of an offline machine or a blocked host, as opposed to a server
/// that actually answered with an error status.
class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Failed host lookup',
    );
  }

  @override
  void close({bool force = false}) {}
}

OfflineSyncRemoteDataSourceImpl _remoteWith(HttpClientAdapter adapter) =>
    OfflineSyncRemoteDataSourceImpl(Dio()..httpClientAdapter = adapter);

void main() {
  test(
    'the sync POST uses a 60s receive/send timeout, the server does ~5 queries per sale',
    () async {
      final adapter = _CapturingAdapter();
      final remote = _remoteWith(adapter);

      await remote.sync(shifts: const [], sales: const []);

      expect(
        adapter.requests.single.receiveTimeout,
        const Duration(seconds: 60),
      );
      expect(adapter.requests.single.sendTimeout, const Duration(seconds: 60));
    },
  );

  test(
    'parses shiftId/saleId keys, maps an unknown status to rejected, and falls back uz -> en',
    () async {
      final remote = _remoteWith(
        _FixedResponseAdapter('''
        {
          "shifts": [
            {"offlineRequestId": "off-1", "status": "created", "shiftId": "srv-1"}
          ],
          "sales": [
            {"offlineRequestId": "a", "status": "created", "saleId": "sale-a"},
            {"offlineRequestId": "b", "status": "duplicate", "saleId": "sale-b"},
            {
              "offlineRequestId": "c",
              "status": "somethingUnexpected",
              "message": {"uz": "Xato uz", "en": "Error en"}
            },
            {
              "offlineRequestId": "d",
              "status": "rejected",
              "message": {"en": "Error en only"}
            }
          ]
        }
        '''),
      );

      final result = await remote.sync(shifts: const [], sales: const []);

      expect(result.shifts.single.offlineRequestId, 'off-1');
      expect(result.shifts.single.status, OfflineSyncStatus.created);
      expect(result.shifts.single.serverId, 'srv-1');

      expect(result.sales[0].status, OfflineSyncStatus.created);
      expect(result.sales[0].serverId, 'sale-a');
      expect(result.sales[1].status, OfflineSyncStatus.duplicate);
      expect(result.sales[1].serverId, 'sale-b');
      // An unrecognized wire status is treated as a rejection, not a crash.
      expect(result.sales[2].status, OfflineSyncStatus.rejected);
      expect(result.sales[2].message, 'Xato uz');
      // No uz text on this one — falls back to en.
      expect(result.sales[3].status, OfflineSyncStatus.rejected);
      expect(result.sales[3].message, 'Error en only');
    },
  );

  test('a 400 throws OfflineSyncValidationException with code/message', () async {
    final remote = _remoteWith(
      _FixedResponseAdapter(
        '{"message": {"uz": "Noto‘g‘ri maʼlumot", "en": "Invalid payload"}, "code": "VALIDATION_ERROR"}',
        statusCode: 400,
      ),
    );

    await expectLater(
      remote.sync(shifts: const [], sales: const []),
      throwsA(
        isA<OfflineSyncValidationException>()
            .having((e) => e.message, 'message', 'Noto‘g‘ri maʼlumot')
            .having((e) => e.code, 'code', 'VALIDATION_ERROR'),
      ),
    );
  });

  test('a 422 also throws OfflineSyncValidationException', () async {
    final remote = _remoteWith(
      _FixedResponseAdapter(
        '{"message": {"en": "Invalid payload"}, "code": "X"}',
        statusCode: 422,
      ),
    );

    await expectLater(
      remote.sync(shifts: const [], sales: const []),
      throwsA(isA<OfflineSyncValidationException>()),
    );
  });

  test('a connection error throws NoInternetException', () async {
    final remote = _remoteWith(_ThrowingAdapter());

    await expectLater(
      remote.sync(shifts: const [], sales: const []),
      throwsA(isA<NoInternetException>()),
    );
  });

  test('a 500 throws ServerException', () async {
    final remote = _remoteWith(
      _FixedResponseAdapter(
        '{"message": {"uz": "Server xatosi"}, "code": "INTERNAL"}',
        statusCode: 500,
      ),
    );

    await expectLater(
      remote.sync(shifts: const [], sales: const []),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Server xatosi',
        ),
      ),
    );
  });

  test(
    'a malformed 200 body (e.g. a captive-portal page) throws ServerException',
    () async {
      final remote = _remoteWith(
        _FixedResponseAdapter(
          '<html>captive portal</html>',
          contentType: Headers.textPlainContentType,
        ),
      );

      await expectLater(
        remote.sync(shifts: const [], sales: const []),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Server javobi noto‘g‘ri',
          ),
        ),
      );
    },
  );
}
