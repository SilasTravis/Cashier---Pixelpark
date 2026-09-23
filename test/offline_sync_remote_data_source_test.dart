import 'dart:typed_data';

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

void main() {
  test(
    'the sync POST uses a 60s receive/send timeout, the server does ~5 queries per sale',
    () async {
      final adapter = _CapturingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final remote = OfflineSyncRemoteDataSourceImpl(dio);

      await remote.sync(shifts: const [], sales: const []);

      expect(
        adapter.requests.single.receiveTimeout,
        const Duration(seconds: 60),
      );
      expect(adapter.requests.single.sendTimeout, const Duration(seconds: 60));
    },
  );
}
