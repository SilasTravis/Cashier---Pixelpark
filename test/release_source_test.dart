import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/release_source.dart';
import 'package:cashier_app/core/update/update_exception.dart';
import 'package:cashier_app/core/update/update_release.dart';

const _validDigest =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

/// A hand-written fake transport: responds to any request with a fixed
/// body/status, regardless of URL. Good enough since each test only ever
/// issues one request. No mocking library is available in this repo.
class _FixedResponseAdapter implements HttpClientAdapter {
  _FixedResponseAdapter(this.body, {this.statusCode = 200});

  final String body;
  final int statusCode;

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
        Headers.contentTypeHeader: [Headers.textPlainContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Same fixed-response behaviour as [_FixedResponseAdapter], but records
/// the effective [RequestOptions] Dio handed to the adapter for each call —
/// i.e. the per-call [Options] merged over any `BaseOptions` — so a test can
/// assert on the timeouts a call actually ends up using (I3).
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(
    this.body, {
    this.statusCode = 200,
    this.contentType = Headers.textPlainContentType,
  });

  final String body;
  final int statusCode;
  final String contentType;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

/// Throws a connection-level [DioException] (no HTTP response at all) —
/// the shape of an offline machine or a blocked host, as opposed to a
/// server that actually answered with an error status.
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

UpdateRelease _releaseWithSha256Url(String? url) => UpdateRelease(
  version: '1.2.3',
  notes: '',
  zipUrl: 'https://example.test/v1.2.3.zip',
  zipSize: 10,
  sha256Url: url,
  releasePageUrl: 'https://example.test/releases/v1.2.3',
);

GithubReleaseSource _sourceRespondingWith(String body, {int statusCode = 200}) {
  final dio = Dio()
    ..httpClientAdapter = _FixedResponseAdapter(body, statusCode: statusCode);
  return GithubReleaseSource(dio: dio);
}

void main() {
  group('GithubReleaseSource.fetchSha256', () {
    test(
      '(a) returns null without any request when there is no sha256 asset',
      () async {
        final source = _sourceRespondingWith('should never be read');
        final release = _releaseWithSha256Url(null);

        expect(await source.fetchSha256(release), isNull);
      },
    );

    test(
      '(b) returns the lowercase digest when the asset body parses',
      () async {
        final source = _sourceRespondingWith(_validDigest);
        final release = _releaseWithSha256Url(
          'https://example.test/v1.2.3.zip.sha256',
        );

        expect(await source.fetchSha256(release), _validDigest);
      },
    );

    test(
      '(c) throws UpdateException when the asset body is an HTML error page',
      () async {
        final source = _sourceRespondingWith(
          '<html><body><h1>404 Not Found</h1></body></html>',
        );
        final release = _releaseWithSha256Url(
          'https://example.test/v1.2.3.zip.sha256',
        );

        expect(
          () => source.fetchSha256(release),
          throwsA(isA<UpdateException>()),
        );
      },
    );

    test('(c) throws UpdateException when the asset body is empty', () async {
      final source = _sourceRespondingWith('');
      final release = _releaseWithSha256Url(
        'https://example.test/v1.2.3.zip.sha256',
      );

      expect(
        () => source.fetchSha256(release),
        throwsA(isA<UpdateException>()),
      );
    });

    test(
      '(c) throws UpdateException when the asset body is whitespace only',
      () async {
        final source = _sourceRespondingWith('   \n  ');
        final release = _releaseWithSha256Url(
          'https://example.test/v1.2.3.zip.sha256',
        );

        expect(
          () => source.fetchSha256(release),
          throwsA(isA<UpdateException>()),
        );
      },
    );

    test('the UpdateException message identifies the release', () async {
      final source = _sourceRespondingWith('not a digest');
      final release = _releaseWithSha256Url(
        'https://example.test/v1.2.3.zip.sha256',
      );

      try {
        await source.fetchSha256(release);
        fail('expected UpdateException');
      } on UpdateException catch (e) {
        expect(e.message, contains('1.2.3'));
      }
    });
  });

  // --- no release published yet (I6) ---------------------------------------
  //
  // `/releases/latest` returns 404 on a repo with no releases at all — that
  // is a legitimate "nothing to update to" state, not a failure. It must be
  // told apart from a genuine server error and from a connection failure,
  // both of which still have to surface as errors.
  group('GithubReleaseSource.fetchLatest', () {
    test('returns null when the repo has no releases yet (404)', () async {
      final dio = Dio()
        ..httpClientAdapter = _FixedResponseAdapter(
          '{"message":"Not Found"}',
          statusCode: 404,
        );
      final source = GithubReleaseSource(dio: dio);

      expect(await source.fetchLatest(), isNull);
    });

    test('still throws for a genuine server error (500)', () async {
      final dio = Dio()
        ..httpClientAdapter = _FixedResponseAdapter(
          '{"message":"Internal Server Error"}',
          statusCode: 500,
        );
      final source = GithubReleaseSource(dio: dio);

      expect(() => source.fetchLatest(), throwsA(isA<DioException>()));
    });

    test('still throws on a connection failure (offline/blocked)', () async {
      final dio = Dio()..httpClientAdapter = _ThrowingAdapter();
      final source = GithubReleaseSource(dio: dio);

      expect(() => source.fetchLatest(), throwsA(isA<DioException>()));
    });
  });

  // --- timeouts (I3) -------------------------------------------------------
  //
  // Without a timeout, a captive portal or a black-holed connection leaves
  // `UpdateChecking`/`UpdateDownloading` spinning forever — the only escape
  // is switching tabs. Every call GithubReleaseSource makes must carry a
  // connectTimeout, and the two small JSON/text calls must also carry a
  // receiveTimeout. The zip download deliberately gets a longer
  // receiveTimeout: in dio 5.11.0 (response_stream_handler.dart /
  // io_adapter.dart) receiveTimeout is a per-chunk inactivity timer — reset
  // on every `onData` — not a cap on the whole transfer, so a large but
  // steadily-progressing download is never killed by it.
  group('timeouts', () {
    const validJson =
        '{"tag_name":"v1.2.3","body":"notes","assets":'
        '[{"name":"app.zip","browser_download_url":'
        '"https://example.test/app.zip","size":10}]}';

    test('fetchLatest sets a connect and a receive timeout', () async {
      final adapter = _CapturingAdapter(
        validJson,
        contentType: Headers.jsonContentType,
      );
      final source = GithubReleaseSource(
        dio: Dio()..httpClientAdapter = adapter,
      );

      await source.fetchLatest();

      expect(adapter.requests, hasLength(1));
      final options = adapter.requests.single;
      expect(options.connectTimeout, isNotNull);
      expect(options.connectTimeout, greaterThan(Duration.zero));
      expect(options.receiveTimeout, isNotNull);
      expect(options.receiveTimeout, greaterThan(Duration.zero));
    });

    test('fetchSha256 sets a connect and a receive timeout', () async {
      final adapter = _CapturingAdapter(_validDigest);
      final source = GithubReleaseSource(
        dio: Dio()..httpClientAdapter = adapter,
      );
      final release = _releaseWithSha256Url(
        'https://example.test/v1.2.3.zip.sha256',
      );

      await source.fetchSha256(release);

      expect(adapter.requests, hasLength(1));
      final options = adapter.requests.single;
      expect(options.connectTimeout, isNotNull);
      expect(options.connectTimeout, greaterThan(Duration.zero));
      expect(options.receiveTimeout, isNotNull);
      expect(options.receiveTimeout, greaterThan(Duration.zero));
    });

    test('downloadZip sets a connect timeout and a generous receive '
        '(stall) timeout', () async {
      final adapter = _CapturingAdapter('zip bytes');
      final source = GithubReleaseSource(
        dio: Dio()..httpClientAdapter = adapter,
      );
      final release = _releaseWithSha256Url(null);
      final dir = await Directory.systemTemp.createTemp('release_source_test');
      addTearDown(() => dir.delete(recursive: true));
      final savePath = '${dir.path}/app.zip';

      await source.downloadZip(release, savePath);

      expect(adapter.requests, hasLength(1));
      final options = adapter.requests.single;
      expect(options.connectTimeout, isNotNull);
      expect(options.connectTimeout, greaterThan(Duration.zero));
      expect(options.receiveTimeout, isNotNull);
      // Deliberately not asserting an upper bound equal to the JSON
      // calls': the whole point of I3 is that this one must stay
      // generous rather than sharing their short value, since dio applies
      // it per-chunk rather than to the whole transfer.
      expect(
        options.receiveTimeout,
        greaterThanOrEqualTo(const Duration(seconds: 20)),
      );
    });
  });
}
