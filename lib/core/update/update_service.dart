// The constructor below assigns public-named parameters (source,
// supportDirectory, updater, checkInterval) to private fields (_source,
// _supportDirectory, _updater, _checkInterval). prefer_initializing_formals
// doesn't apply: `this._source` would make the named parameter's external
// label `_source`, which callers outside this library can't spell — that
// would silently change this class's public constructor API.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'release_source.dart';
import 'update_exception.dart';
import 'update_release.dart';
import 'version_compare.dart';
import 'windows_updater.dart';

/// Owns the update lifecycle: is there a newer release, fetch and verify it,
/// hand it to the platform updater.
///
/// The background timer only ever calls [check] — downloading or restarting
/// unattended would interrupt a cashier mid-shift. Everything past the check
/// is driven by the Settings UI.
class UpdateService {
  UpdateService({
    required ReleaseSource source,
    required this.currentVersion,
    required Future<Directory> Function() supportDirectory,
    WindowsUpdater updater = const WindowsUpdater(),
    Duration checkInterval = const Duration(hours: 4),
  }) : _source = source,
       _supportDirectory = supportDirectory,
       _updater = updater,
       _checkInterval = checkInterval;

  final ReleaseSource _source;
  final Future<Directory> Function() _supportDirectory;
  final WindowsUpdater _updater;
  final Duration _checkInterval;

  /// The running app's version, compared against the latest release tag.
  final String currentVersion;

  /// Non-null while a newer release is known. Drives the sidebar badge.
  final ValueNotifier<UpdateRelease?> available = ValueNotifier(null);

  Timer? _timer;

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
      await _remove(zip, staged);
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
    unawaited(_safeCheck());
    _timer = Timer.periodic(_checkInterval, (_) => unawaited(_safeCheck()));
  }

  void dispose() {
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
