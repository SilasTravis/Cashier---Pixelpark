import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/network/connectivity_interceptor.dart';
import 'package:cashier_app/core/update/release_source.dart';
import 'package:cashier_app/core/update/update_exception.dart';
import 'package:cashier_app/core/update/update_release.dart';

const _digest =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

/// Answers every request with [body] as JSON and records what was asked.
class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body, {this.statusCode = 200});

  final Object? body;
  final int statusCode;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _api(_JsonAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://api.example.test/api/'))
      ..httpClientAdapter = adapter;

Map<String, dynamic> _latest({String? sha256 = _digest}) => {
  'latest': {
    'version': '1.0.7',
    'notes': 'fixes',
    'zipSize': 1234,
    'sha256': sha256,
    'publishedAt': '2026-09-28T10:00:00.000Z',
  },
};

/// A source that records calls, for [FallbackReleaseSource].
class _FakeSource implements ReleaseSource {
  _FakeSource({this.release, this.error});

  final UpdateRelease? release;
  final Object? error;
  int downloads = 0;

  @override
  Future<UpdateRelease?> fetchLatest() async {
    if (error != null) throw error!;
    return release;
  }

  @override
  Future<String?> fetchSha256(UpdateRelease release) async => _digest;

  @override
  Future<void> downloadZip(
    UpdateRelease release,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async => downloads++;
}

UpdateRelease _release(String version) => UpdateRelease(
  version: version,
  notes: '',
  zipUrl: 'https://example.test/$version.zip',
  zipSize: 1,
  sha256Url: null,
  releasePageUrl: '',
);

void main() {
  group('BackendReleaseSource', () {
    test(
      'reads the mirror and builds a public download URL on the API origin',
      () async {
        final adapter = _JsonAdapter(_latest());
        final source = BackendReleaseSource(
          api: _api(adapter),
          hasSession: () => true,
        );

        final release = await source.fetchLatest();

        expect(
          adapter.requests.single.uri.toString(),
          'https://api.example.test/api/v1/pos/app-update/latest',
        );
        expect(release, isNotNull);
        expect(release!.version, '1.0.7');
        expect(release.notes, 'fixes');
        expect(release.zipSize, 1234);
        expect(
          release.zipUrl,
          'https://api.example.test/api/v1/pos/app-update/1.0.7/download',
        );
        expect(release.releasePageUrl, isEmpty);
        expect(await source.fetchSha256(release), _digest);
      },
    );

    test('is null before the mirror has synced anything', () async {
      final source = BackendReleaseSource(
        api: _api(_JsonAdapter({'latest': null})),
        hasSession: () => true,
      );
      expect(await source.fetchLatest(), isNull);
    });

    test('fails closed when the mirror sent no valid digest', () async {
      final source = BackendReleaseSource(
        api: _api(_JsonAdapter(_latest(sha256: 'nope'))),
        hasSession: () => true,
      );
      final release = (await source.fetchLatest())!;

      expect(
        () => source.fetchSha256(release),
        throwsA(
          isA<UpdateException>().having(
            (e) => e.code,
            'code',
            UpdateFailureCode.checksumUnreadable,
          ),
        ),
      );
    });

    test('an older backend without the mirror surfaces as an error', () async {
      final source = BackendReleaseSource(
        api: _api(_JsonAdapter({'code': 'NOT_FOUND'}, statusCode: 404)),
        hasSession: () => true,
      );
      expect(source.fetchLatest(), throwsA(isA<DioException>()));
    });

    test('never calls the API without a session, so no 401 ends it', () async {
      final adapter = _JsonAdapter(_latest());
      final source = BackendReleaseSource(
        api: _api(adapter),
        hasSession: () => false,
      );

      await expectLater(source.fetchLatest(), throwsA(isA<StateError>()));
      expect(adapter.requests, isEmpty);
    });

    test(
      'marks the check as background for the connectivity monitor',
      () async {
        final adapter = _JsonAdapter(_latest());
        await BackendReleaseSource(
          api: _api(adapter),
          hasSession: () => true,
        ).fetchLatest();
        expect(
          adapter.requests.single.extra[ConnectivityInterceptor.backgroundKey],
          isTrue,
        );
      },
    );
  });

  group('FallbackReleaseSource', () {
    test('uses the primary and downloads through it', () async {
      final primary = _FakeSource(release: _release('1.0.7'));
      final fallback = _FakeSource(release: _release('1.0.6'));
      final source = FallbackReleaseSource(
        primary: primary,
        fallback: fallback,
      );

      final release = (await source.fetchLatest())!;
      await source.downloadZip(release, 'x');

      expect(release.version, '1.0.7');
      expect(primary.downloads, 1);
      expect(fallback.downloads, 0);
    });

    test('trusts a primary that answers "no release"', () async {
      final fallback = _FakeSource(release: _release('1.0.6'));
      final source = FallbackReleaseSource(
        primary: _FakeSource(),
        fallback: fallback,
      );
      expect(await source.fetchLatest(), isNull);
    });

    test(
      'falls back when the primary fails, and downloads from the fallback',
      () async {
        final primary = _FakeSource(error: Exception('404'));
        final fallback = _FakeSource(release: _release('1.0.6'));
        final source = FallbackReleaseSource(
          primary: primary,
          fallback: fallback,
        );

        final release = (await source.fetchLatest())!;
        await source.downloadZip(release, 'x');

        expect(release.version, '1.0.6');
        expect(fallback.downloads, 1);
        expect(primary.downloads, 0);
      },
    );

    test('surfaces the primary error when both fail', () async {
      final source = FallbackReleaseSource(
        primary: _FakeSource(error: const FormatException('backend')),
        fallback: _FakeSource(error: StateError('github blocked')),
      );
      expect(source.fetchLatest(), throwsA(isA<FormatException>()));
    });
  });
}
