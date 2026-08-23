import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/release_source.dart';
import 'package:cashier_app/core/update/update_exception.dart';
import 'package:cashier_app/core/update/update_release.dart';
import 'package:cashier_app/core/update/update_service.dart';

UpdateRelease _release({String version = '1.2.3', String? sha256Url}) =>
    UpdateRelease(
      version: version,
      notes: 'notes',
      zipUrl: 'https://example.test/app.zip',
      zipSize: 0,
      sha256Url: sha256Url,
      releasePageUrl: 'https://example.test/releases/tag/v$version',
    );

/// Serves a real zip built on disk, so extraction and hashing are exercised
/// for real rather than stubbed.
class _FakeSource implements ReleaseSource {
  _FakeSource({required this.zipBytes, this.latest, this.digest});

  final List<int> zipBytes;
  UpdateRelease? latest;
  String? digest;
  int downloadCalls = 0;
  Object? failDownloadWith;

  @override
  Future<UpdateRelease?> fetchLatest() async => latest;

  @override
  Future<String?> fetchSha256(UpdateRelease release) async => digest;

  @override
  Future<void> downloadZip(
    UpdateRelease release,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    downloadCalls++;
    final failure = failDownloadWith;
    if (failure != null) throw failure;
    onProgress?.call(zipBytes.length, zipBytes.length);
    await File(savePath).writeAsBytes(zipBytes);
  }
}

void main() {
  late Directory support;
  late List<int> zipBytes;
  late String zipDigest;

  setUp(() async {
    support = Directory.systemTemp.createTempSync('update_service_test');

    // A minimal but genuine zip whose root holds cashier_app.exe.
    // zipDirectory is async in archive 4.x and uses includeDirName: false,
    // so the files land at the zip root — exactly like the CI zip.
    final payload = Directory('${support.path}/payload')..createSync();
    File('${payload.path}/cashier_app.exe').writeAsStringSync('binary');
    File('${payload.path}/flutter_windows.dll').writeAsStringSync('dll');
    final zipPath = '${support.path}/source.zip';
    await ZipFileEncoder().zipDirectory(payload, filename: zipPath);
    zipBytes = File(zipPath).readAsBytesSync();
    zipDigest = sha256.convert(zipBytes).toString();
  });

  tearDown(() => support.deleteSync(recursive: true));

  UpdateService serviceWith(_FakeSource source, {String current = '1.0.0'}) =>
      UpdateService(
        source: source,
        currentVersion: current,
        supportDirectory: () async => support,
      );

  test('check returns the release and flags it when it is newer', () async {
    final source = _FakeSource(zipBytes: zipBytes, latest: _release());
    final service = serviceWith(source);

    final found = await service.check();

    expect(found?.version, '1.2.3');
    expect(service.available.value?.version, '1.2.3');
  });

  test('check returns null and clears the flag when already current', () async {
    final source = _FakeSource(zipBytes: zipBytes, latest: _release());
    final service = serviceWith(source, current: '1.2.3');

    expect(await service.check(), isNull);
    expect(service.available.value, isNull);
  });

  test('check returns null when no release is published', () async {
    final service = serviceWith(_FakeSource(zipBytes: zipBytes));

    expect(await service.check(), isNull);
  });

  test('downloads, extracts, and reports progress', () async {
    final source = _FakeSource(zipBytes: zipBytes, latest: _release());
    final service = serviceWith(source);
    var lastReceived = 0;

    final staged = await service.downloadAndStage(
      _release(),
      onProgress: (received, total) => lastReceived = received,
    );

    expect(File('${staged.path}/cashier_app.exe').existsSync(), isTrue);
    expect(File('${staged.path}/flutter_windows.dll').existsSync(), isTrue);
    expect(lastReceived, zipBytes.length);
  });

  test('accepts a matching published digest', () async {
    final source = _FakeSource(zipBytes: zipBytes, digest: zipDigest);
    final service = serviceWith(source);

    final staged = await service.downloadAndStage(
      _release(sha256Url: 'https://example.test/app.zip.sha256'),
    );

    expect(File('${staged.path}/cashier_app.exe').existsSync(), isTrue);
  });

  test('rejects a mismatched digest and cleans up', () async {
    final source = _FakeSource(zipBytes: zipBytes, digest: 'deadbeef');
    final service = serviceWith(source);

    await expectLater(
      service.downloadAndStage(
        _release(sha256Url: 'https://example.test/app.zip.sha256'),
      ),
      throwsA(isA<UpdateException>()),
    );
    expect(Directory('${support.path}/updates/v1.2.3').existsSync(), isFalse);
    expect(File('${support.path}/updates/v1.2.3.zip').existsSync(), isFalse);
  });

  test('rejects an archive without the executable', () async {
    final other = Directory('${support.path}/other')..createSync();
    File('${other.path}/readme.txt').writeAsStringSync('nope');
    final otherZip = '${support.path}/other.zip';
    await ZipFileEncoder().zipDirectory(other, filename: otherZip);

    final source = _FakeSource(zipBytes: File(otherZip).readAsBytesSync());
    final service = serviceWith(source);

    await expectLater(
      service.downloadAndStage(_release()),
      throwsA(isA<UpdateException>()),
    );
  });

  test('a failed download leaves nothing behind for the retry', () async {
    final source = _FakeSource(zipBytes: zipBytes)
      ..failDownloadWith = const UpdateException('network down');
    final service = serviceWith(source);

    await expectLater(
      service.downloadAndStage(_release()),
      throwsA(isA<UpdateException>()),
    );
    expect(File('${support.path}/updates/v1.2.3.zip').existsSync(), isFalse);

    source.failDownloadWith = null;
    final staged = await service.downloadAndStage(_release());
    expect(File('${staged.path}/cashier_app.exe').existsSync(), isTrue);
    expect(source.downloadCalls, 2);
  });
}
