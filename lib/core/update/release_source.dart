import 'package:dio/dio.dart';

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
    if (url == null) return null;
    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data?.trim();
    if (body == null || body.isEmpty) return null;
    // The file may be a bare digest or `<digest>  <filename>`.
    return body.split(RegExp(r'\s+')).first.toLowerCase();
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
