import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
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
  int fetchLatestCalls = 0;
  Object? failDownloadWith;

  /// Fires synchronously whenever [fetchSha256] is called, before it
  /// returns the digest — lets a test inject a side effect (e.g. locking
  /// down the updates folder) between the download completing and the
  /// digest check that follows.
  void Function()? beforeFetchSha256;

  @override
  Future<UpdateRelease?> fetchLatest() async {
    fetchLatestCalls++;
    return latest;
  }

  @override
  Future<String?> fetchSha256(UpdateRelease release) async {
    beforeFetchSha256?.call();
    return digest;
  }

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

/// Overwrites the start of one entry's compressed data, leaving every
/// header and offset intact.
///
/// This is the shape of the real failure C1 describes: `extractFileToDisk`
/// wraps `writeContent` in `try { … } catch (_) {}`, so an entry it cannot
/// decode — corrupt data, a disk-full write, an antivirus grabbing the
/// handle — leaves a zero-length file behind and no exception at all.
Uint8List _corruptEntryData(List<int> zipBytes, String entryName) {
  final bytes = Uint8List.fromList(zipBytes);
  final name = entryName.codeUnits;
  for (var i = 0; i + 30 + name.length <= bytes.length; i++) {
    // Local file header signature.
    if (bytes[i] != 0x50 ||
        bytes[i + 1] != 0x4b ||
        bytes[i + 2] != 0x03 ||
        bytes[i + 3] != 0x04) {
      continue;
    }
    final nameLength = bytes[i + 26] | (bytes[i + 27] << 8);
    if (nameLength != name.length) continue;
    var matches = true;
    for (var k = 0; k < nameLength; k++) {
      if (bytes[i + 30 + k] != name[k]) {
        matches = false;
        break;
      }
    }
    if (!matches) continue;

    final extraLength = bytes[i + 28] | (bytes[i + 29] << 8);
    final dataStart = i + 30 + nameLength + extraLength;
    // 0xff opens a deflate block with an invalid type, so the inflater
    // throws on the very first byte.
    for (var k = 0; k < 8; k++) {
      bytes[dataStart + k] = 0xff;
    }
    return bytes;
  }
  fail('no local file header for "$entryName" in the test zip');
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
    // Long enough to compress: the corruption helper below relies on the
    // entry being deflated rather than stored.
    File(
      '${payload.path}/flutter_windows.dll',
    ).writeAsStringSync('flutter-windows-' * 200);
    Directory('${payload.path}/data').createSync();
    File('${payload.path}/data/app.so').writeAsStringSync('app-so-' * 200);
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

  // --- silently truncated extraction (C1) ---------------------------------

  test('rejects an archive that only extracted part way', () async {
    // package:archive swallows the write failure, so extraction "succeeds"
    // with a zero-length flutter_windows.dll. Nothing downstream would
    // notice: cashier_app.exe is present and the script's guards only ever
    // look at the executable.
    final source = _FakeSource(
      zipBytes: _corruptEntryData(zipBytes, 'flutter_windows.dll'),
    );
    final service = serviceWith(source);

    await expectLater(
      service.downloadAndStage(_release()),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.message,
          'message',
          contains('flutter_windows.dll'),
        ),
      ),
    );
    // A failed download, not a half-staged build waiting to be applied.
    expect(Directory('${support.path}/updates/v1.2.3').existsSync(), isFalse);
    expect(File('${support.path}/updates/v1.2.3.zip').existsSync(), isFalse);
  });

  test('accepts an extraction that matches the archive', () async {
    final staged = Directory('${support.path}/staged');
    await extractFileToDisk('${support.path}/source.zip', staged.path);

    await expectLater(
      verifyExtractedArchive(
        zipPath: '${support.path}/source.zip',
        staged: staged,
      ),
      completes,
    );
  });

  test('catches a file that vanished after extraction', () async {
    final staged = Directory('${support.path}/staged');
    await extractFileToDisk('${support.path}/source.zip', staged.path);
    // e.g. antivirus quarantining one file out of the tree.
    File('${staged.path}/data/app.so').deleteSync();

    await expectLater(
      verifyExtractedArchive(
        zipPath: '${support.path}/source.zip',
        staged: staged,
      ),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.message,
          'message',
          allOf(contains('app.so'), contains('missing')),
        ),
      ),
    );
  });

  test('catches a file that landed short', () async {
    final staged = Directory('${support.path}/staged');
    await extractFileToDisk('${support.path}/source.zip', staged.path);
    final dll = File('${staged.path}/flutter_windows.dll');
    final full = dll.lengthSync();
    // e.g. the disk filling up part way through the write.
    dll.writeAsBytesSync(dll.readAsBytesSync().sublist(0, full - 10));

    await expectLater(
      verifyExtractedArchive(
        zipPath: '${support.path}/source.zip',
        staged: staged,
      ),
      throwsA(
        isA<UpdateException>().having(
          (e) => e.message,
          'message',
          contains('flutter_windows.dll'),
        ),
      ),
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

  // --- concurrent downloads (I2) ------------------------------------------

  test('a second download joins the one already running', () async {
    // The cubit that owns this call is rebuilt on every tab switch, so a
    // cashier who starts a download, switches tabs and comes back can press
    // the button again while the first is still running. Two writers on the
    // same v1.2.3.zip and v1.2.3\ is how a half-extracted tree gets made.
    final source = _FakeSource(zipBytes: zipBytes);
    final service = serviceWith(source);

    final first = service.downloadAndStage(_release());
    final second = service.downloadAndStage(_release());
    final staged = await Future.wait([first, second]);

    expect(source.downloadCalls, 1);
    expect(staged[1].path, staged[0].path);
    expect(File('${staged[0].path}/cashier_app.exe').existsSync(), isTrue);
    expect(File('${staged[0].path}/flutter_windows.dll').existsSync(), isTrue);
  });

  test('a finished download does not suppress the next one', () async {
    final source = _FakeSource(zipBytes: zipBytes);
    final service = serviceWith(source);

    await service.downloadAndStage(_release());
    await service.downloadAndStage(_release());

    expect(
      source.downloadCalls,
      2,
      reason: 'the guard must clear once the download it covers is done',
    );
  });

  test('a failed download does not wedge the guard shut', () async {
    final source = _FakeSource(zipBytes: zipBytes)
      ..failDownloadWith = const UpdateException('network down');
    final service = serviceWith(source);

    await expectLater(
      service.downloadAndStage(_release()),
      throwsA(isA<UpdateException>()),
    );

    source.failDownloadWith = null;
    final staged = await service.downloadAndStage(_release());
    expect(File('${staged.path}/cashier_app.exe').existsSync(), isTrue);
    expect(source.downloadCalls, 2);
  });

  test('starting background checks twice does not leak a duplicate timer', () {
    fakeAsync((async) {
      final source = _FakeSource(zipBytes: zipBytes, latest: _release());
      final service = UpdateService(
        source: source,
        currentVersion: '1.0.0',
        supportDirectory: () async => support,
        checkInterval: const Duration(seconds: 1),
      );

      // Called back-to-back, as a defensive double-call (e.g. re-entrant
      // init) would do. Each call fires one immediate check; only one
      // periodic timer should end up alive.
      service.startBackgroundChecks();
      service.startBackgroundChecks();

      // Ticks land at t=1s, 2s, 3s. A single surviving timer fires 3
      // times; a leaked first timer would add 3 more (8 total instead
      // of 5). This is deterministic under fakeAsync's virtual clock —
      // no real-time flakiness.
      async.elapse(const Duration(milliseconds: 3500));

      expect(source.fetchLatestCalls, 5);

      service.dispose();
    });
  });

  test('dispose can be called twice without throwing', () {
    final service = serviceWith(_FakeSource(zipBytes: zipBytes));

    service.dispose();

    expect(service.dispose, returnsNormally);
  });

  test(
    'a cleanup failure during unwind does not mask the original exception',
    () async {
      final source = _FakeSource(zipBytes: zipBytes, digest: 'deadbeef');
      final updatesDir = Directory('${support.path}/updates');
      source.beforeFetchSha256 = () {
        // Simulate cleanup being unable to touch the updates folder, e.g.
        // antivirus holding a handle on a just-extracted binary. This
        // fires after the zip has been written to disk but before the
        // (failing) digest check, so the catch block's cleanup attempt
        // hits a real permission error when it tries to delete the zip.
        Process.runSync('chmod', ['555', updatesDir.path]);
      };
      final service = serviceWith(source);

      try {
        await expectLater(
          service.downloadAndStage(
            _release(sha256Url: 'https://example.test/app.zip.sha256'),
          ),
          throwsA(
            isA<UpdateException>().having(
              (e) => e.message,
              'message',
              'Downloaded file failed its checksum check',
            ),
          ),
        );
      } finally {
        // Restore write access so tearDown can delete the temp dir.
        Process.runSync('chmod', ['755', updatesDir.path]);
      }
    },
  );
}
