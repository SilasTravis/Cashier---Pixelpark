import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'update_manifest.dart';
import 'version_compare.dart';

/// Silent background update checker — no in-app settings screen, no user
/// prompts. Polls a manifest hosted on pixelpark.uz (the same site used to
/// release/distribute this app), downloads a newer installer when found,
/// and applies it — launches the installer detached and quits this process
/// — once it's safe to interrupt the cashier, i.e. once they're signed out
/// (between shifts or at day's end), never mid-session.
class UpdateChecker {
  UpdateChecker({required this.isSafeToApply, Dio? dio}) : _dio = dio ?? Dio();

  static const _manifestUrl = 'https://pixelpark.uz/systems/pos/updates.json';
  static const _checkInterval = Duration(hours: 4);

  final bool Function() isSafeToApply;
  final Dio _dio;

  Timer? _timer;
  String? _pendingInstallerPath;

  void start() {
    unawaited(_tick());
    _timer = Timer.periodic(_checkInterval, (_) => unawaited(_tick()));
  }

  void dispose() => _timer?.cancel();

  Future<void> _tick() async {
    try {
      if (_pendingInstallerPath != null) {
        await _applyIfSafe();
        return;
      }
      final manifest = await _fetchManifest();
      if (manifest == null) return;
      final info = await PackageInfo.fromPlatform();
      if (!isNewerVersion(manifest.version, info.version)) return;
      _pendingInstallerPath = await _download(manifest);
      await _applyIfSafe();
    } catch (_) {
      // Best-effort — a failed check must never surface to the cashier.
    }
  }

  Future<UpdateManifest?> _fetchManifest() async {
    final response = await _dio.get<Map<String, dynamic>>(_manifestUrl);
    final data = response.data;
    if (data == null) return null;
    return UpdateManifest.fromJson(data);
  }

  Future<String> _download(UpdateManifest manifest) async {
    final dir = await getApplicationSupportDirectory();
    final updatesDir = Directory('${dir.path}/updates');
    await updatesDir.create(recursive: true);
    final path = '${updatesDir.path}/cashier-${manifest.version}.exe';
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      await _dio.download(manifest.url, path);
    }
    return path;
  }

  Future<void> _applyIfSafe() async {
    final path = _pendingInstallerPath;
    if (path == null || !isSafeToApply()) return;
    if (!await File(path).exists()) {
      _pendingInstallerPath = null;
      return;
    }
    await Process.start(path, [], mode: ProcessStartMode.detached);
    _timer?.cancel();
    exit(0);
  }
}
