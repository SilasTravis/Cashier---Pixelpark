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

UpdateRelease _releaseWithSha256Url(String? url) => UpdateRelease(
  version: '1.2.3',
  notes: '',
  zipUrl: 'https://example.test/v1.2.3.zip',
  zipSize: 10,
  sha256Url: url,
  releasePageUrl: 'https://example.test/releases/v1.2.3',
);

GithubReleaseSource _sourceRespondingWith(String body, {int statusCode = 200}) {
  final dio = Dio()..httpClientAdapter = _FixedResponseAdapter(body, statusCode: statusCode);
  return GithubReleaseSource(dio: dio);
}

void main() {
  group('GithubReleaseSource.fetchSha256', () {
    test('(a) returns null without any request when there is no sha256 asset', () async {
      final source = _sourceRespondingWith('should never be read');
      final release = _releaseWithSha256Url(null);

      expect(await source.fetchSha256(release), isNull);
    });

    test('(b) returns the lowercase digest when the asset body parses', () async {
      final source = _sourceRespondingWith(_validDigest);
      final release = _releaseWithSha256Url('https://example.test/v1.2.3.zip.sha256');

      expect(await source.fetchSha256(release), _validDigest);
    });

    test('(c) throws UpdateException when the asset body is an HTML error page', () async {
      final source = _sourceRespondingWith(
        '<html><body><h1>404 Not Found</h1></body></html>',
      );
      final release = _releaseWithSha256Url('https://example.test/v1.2.3.zip.sha256');

      expect(
        () => source.fetchSha256(release),
        throwsA(isA<UpdateException>()),
      );
    });

    test('(c) throws UpdateException when the asset body is empty', () async {
      final source = _sourceRespondingWith('');
      final release = _releaseWithSha256Url('https://example.test/v1.2.3.zip.sha256');

      expect(
        () => source.fetchSha256(release),
        throwsA(isA<UpdateException>()),
      );
    });

    test('(c) throws UpdateException when the asset body is whitespace only', () async {
      final source = _sourceRespondingWith('   \n  ');
      final release = _releaseWithSha256Url('https://example.test/v1.2.3.zip.sha256');

      expect(
        () => source.fetchSha256(release),
        throwsA(isA<UpdateException>()),
      );
    });

    test('the UpdateException message identifies the release', () async {
      final source = _sourceRespondingWith('not a digest');
      final release = _releaseWithSha256Url('https://example.test/v1.2.3.zip.sha256');

      try {
        await source.fetchSha256(release);
        fail('expected UpdateException');
      } on UpdateException catch (e) {
        expect(e.message, contains('1.2.3'));
      }
    });
  });
}
