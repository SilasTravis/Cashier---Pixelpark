import 'package:dio/dio.dart';

import 'update_exception.dart';
import 'update_release.dart';

/// Where update packages come from. An interface so [UpdateService] can be
/// tested against a fake without touching the network.
abstract interface class ReleaseSource {
  Future<UpdateRelease?> fetchLatest();

  /// The published SHA-256 digest as lowercase hex, or null when the release
  /// has no digest asset.
  Future<String?> fetchSha256(UpdateRelease release);

  Future<void> downloadZip(
    UpdateRelease release,
    String savePath, {
    void Function(int received, int total)? onProgress,
  });
}

/// Reads releases from the public GitHub API. The repo is public, so every
/// request here is unauthenticated — this must never carry a token, and it
/// deliberately uses its own [Dio] rather than the app's API client, whose
/// base URL and bearer interceptor point at the Pixel Park backend.
class GithubReleaseSource implements ReleaseSource {
  GithubReleaseSource({Dio? dio}) : _dio = dio ?? Dio();

  static const String repoSlug = 'SilasTravis/Cashier---Pixelpark';
  static const String latestReleaseUrl =
      'https://api.github.com/repos/$repoSlug/releases/latest';

  final Dio _dio;

  @override
  Future<UpdateRelease?> fetchLatest() async {
    final response = await _dio.get<Map<String, dynamic>>(
      latestReleaseUrl,
      options: Options(headers: const {'Accept': 'application/vnd.github+json'}),
    );
    final data = response.data;
    if (data == null) return null;
    return UpdateRelease.fromGithubJson(data);
  }

  @override
  Future<String?> fetchSha256(UpdateRelease release) async {
    final url = release.sha256Url;
    // No .sha256 asset was published for this release at all — verification
    // is legitimately skipped, not a failure.
    if (url == null) return null;

    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final digest = parseSha256Digest(response.data);
    if (digest == null) {
      // The asset exists but its body isn't a valid digest — a 404/error
      // page served with a 200 status, a truncated download, a proxy that
      // rewrote the content, etc. Never silently fall back to "no digest
      // published": fail closed so an unverified binary is never installed.
      throw UpdateException(
        'Could not read the published checksum for version '
        '${release.version} at $url — the file did not contain a valid '
        'SHA-256 digest. Refusing to install an unverified update.',
      );
    }
    return digest;
  }

  @override
  Future<void> downloadZip(
    UpdateRelease release,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    await _dio.download(
      release.zipUrl,
      savePath,
      onReceiveProgress: (received, total) {
        // GitHub sends Content-Length, but fall back to the asset size from
        // the API when a proxy strips it, so the progress bar stays useful.
        onProgress?.call(received, total > 0 ? total : release.zipSize);
      },
    );
  }
}
