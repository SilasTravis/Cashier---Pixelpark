import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'release_source.dart';
import 'update_exception.dart';
import 'update_release.dart';
import 'version_compare.dart';
import 'windows_updater.dart';

/// Asserts the extracted tree really holds everything [zipPath] says it
/// does, at the sizes it says.
///
/// A top-level function rather than a private method so tests can drive it
/// against a tree sabotaged by hand, the way antivirus or a full disk would
/// sabotage it.
///
/// `extractFileToDisk` reports success for a tree it only wrote part of:
/// archive 4.0.9 wraps the per-entry `writeContent` in
/// `try { … } catch (_) {}` (`lib/src/io/extract_archive_to_disk.dart`), so
/// a full disk, a locked handle, or one quarantined DLL leaves a short or
/// empty file and raises nothing. Everything downstream — the executable
/// check below, and both name checks in the batch script — would then wave
/// that tree through and `robocopy /MIR` it over a working install.
///
/// Checking the archive's own directory against the disk turns that silent
/// truncation back into an ordinary failed download, which the caller
/// already knows how to clean up and retry.
Future<void> verifyExtractedArchive({
  required String zipPath,
  required Directory staged,
}) async {
  final input = InputFileStream(zipPath);
  final archive = ZipDecoder().decodeStream(input);
  final problems = <String>[];
  final root = p.canonicalize(staged.path);

  try {
    for (final entry in archive) {
      // Directories are created by the extractor and carry no content;
      // symlinks become links, not files, and Windows builds have none.
      if (!entry.isFile || entry.isSymbolicLink) continue;

      final filePath = p.join(staged.path, p.normalize(entry.name));
      // The extractor refuses to write outside the output folder, so an
      // entry that escapes it is legitimately absent rather than lost.
      if (!p.isWithin(root, p.canonicalize(filePath))) continue;

      final file = File(filePath);
      if (!await file.exists()) {
        problems.add('${entry.name} (missing)');
        continue;
      }
      final actual = await file.length();
      if (actual != entry.size) {
        problems.add('${entry.name} ($actual of ${entry.size} bytes)');
      }
    }
  } finally {
    await input.close();
    await archive.clear();
  }

  if (problems.isEmpty) return;
  // Name a few rather than all of them: this text reaches a cashier.
  final named = problems.take(3).join(', ');
  final rest = problems.length > 3 ? ' and ${problems.length - 3} more' : '';
  throw UpdateException(
    'The update did not unpack completely — ${problems.length} file(s) are '
    'missing or truncated: $named$rest. The download was discarded; '
    'please try again.',
  );
}

/// Owns the update lifecycle: is there a newer release, fetch and verify it,
/// hand it to the platform updater.
///
/// The background timer only ever calls [check] — downloading or restarting
/// unattended would interrupt a cashier mid-shift. Everything past the check
/// is driven by the Settings UI.
class UpdateService {
  UpdateService({
    required this._source,
    required this.currentVersion,
    required this._supportDirectory,
    this._updater = const WindowsUpdater(),
    this._checkInterval = const Duration(hours: 4),
  });

  final ReleaseSource _source;
  final Future<Directory> Function() _supportDirectory;
  final WindowsUpdater _updater;
  final Duration _checkInterval;

  /// The running app's version, compared against the latest release tag.
  final String currentVersion;

  /// Non-null while a newer release is known. Drives the sidebar badge.
  final ValueNotifier<UpdateRelease?> available = ValueNotifier(null);

  /// `available` reduced to a boolean, for widgets that only need to know
  /// whether to show a badge.
  late final ValueListenable<bool> hasUpdate = _HasUpdate(available);

  Timer? _timer;
  bool _disposed = false;

  Future<UpdateRelease?> check() async {
    final latest = await _source.fetchLatest();
    final newer =
        latest != null && isNewerVersion(latest.version, currentVersion)
        ? latest
        : null;
    available.value = newer;
    return newer;
  }

  Future<Directory> downloadAndStage(
    UpdateRelease release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final updates = await _updatesDirectory();
    final zip = File(
      '${updates.path}${Platform.pathSeparator}v${release.version}.zip',
    );
    final staged = Directory(
      '${updates.path}${Platform.pathSeparator}v${release.version}',
    );

    // Always start clean: a half-finished attempt must never be mistaken
    // for a usable staged build.
    await _remove(zip, staged);

    try {
      await _source.downloadZip(release, zip.path, onProgress: onProgress);
      await _verifyDigest(release, zip);
      await extractFileToDisk(zip.path, staged.path);
      // Before any check that looks at one named file: extraction can lose
      // everything *but* the executable and still report success.
      await verifyExtractedArchive(zipPath: zip.path, staged: staged);

      final exe = File(
        '${staged.path}${Platform.pathSeparator}cashier_app.exe',
      );
      if (!await exe.exists()) {
        throw const UpdateException(
          'cashier_app.exe not found in the downloaded archive',
        );
      }
      await zip.delete();
      return staged;
    } catch (_) {
      try {
        await _remove(zip, staged);
      } catch (_) {
        // Best-effort cleanup: a locked file (e.g. antivirus holding a
        // handle on a just-extracted binary) must never displace the real
        // failure reason surfaced to the cashier.
      }
      rethrow;
    }
  }

  Future<Never> applyAndRestart(Directory staged) async {
    if (!Platform.isWindows) {
      throw const UpdateException('Self-update is only supported on Windows');
    }
    _timer?.cancel();
    return _updater.apply(
      updatesDir: await _updatesDirectory(),
      staged: staged,
    );
  }

  void startBackgroundChecks() {
    _timer?.cancel();
    unawaited(_safeCheck());
    _timer = Timer.periodic(_checkInterval, (_) => unawaited(_safeCheck()));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    available.dispose();
  }

  Future<void> _safeCheck() async {
    try {
      await check();
    } catch (_) {
      // A background check that can't reach GitHub must stay invisible;
      // the cashier sees errors only when they press the button themselves.
    }
  }

  Future<void> _verifyDigest(UpdateRelease release, File zip) async {
    final expected = await _source.fetchSha256(release);
    if (expected == null) return;
    final actual = (await sha256.bind(zip.openRead()).first).toString();
    if (actual != expected.toLowerCase()) {
      throw const UpdateException('Downloaded file failed its checksum check');
    }
  }

  Future<Directory> _updatesDirectory() async {
    final support = await _supportDirectory();
    final updates = Directory(
      '${support.path}${Platform.pathSeparator}updates',
    );
    if (!await updates.exists()) await updates.create(recursive: true);
    return updates;
  }

  Future<void> _remove(File zip, Directory staged) async {
    if (await zip.exists()) await zip.delete();
    if (await staged.exists()) await staged.delete(recursive: true);
  }
}

class _HasUpdate extends ValueNotifier<bool> {
  _HasUpdate(this._source) : super(_source.value != null) {
    _source.addListener(_sync);
  }

  final ValueNotifier<UpdateRelease?> _source;

  void _sync() => value = _source.value != null;

  @override
  void dispose() {
    _source.removeListener(_sync);
    super.dispose();
  }
}
