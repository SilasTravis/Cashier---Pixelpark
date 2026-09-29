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

  /// Time to establish the TCP/TLS connection, on every call this class
  /// makes. On a captive portal or a black-holed connection this is what
  /// stops `UpdateChecking`/`UpdateDownloading` from spinning forever — the
  /// previous bare `Dio()` had no limit at all. Generous because a POS may
  /// be on a slow or congested connection, not just a broken one.
  static const Duration _connectTimeout = Duration(seconds: 10);

  /// Ceiling for the two small JSON/text calls: the whole response is a few
  /// KB, so if it hasn't arrived in this long the connection is stalled,
  /// not just slow.
  static const Duration _metadataReceiveTimeout = Duration(seconds: 15);

  /// Ceiling for the zip download. Deliberately much longer than
  /// [_metadataReceiveTimeout] and NOT a cap on the whole transfer: in the
  /// dio version pinned here (5.11.0), `receiveTimeout` is applied between
  /// received chunks — `io_adapter.dart` waits this long for the response
  /// headers, and `response_stream_handler.dart`'s `watchReceiveTimeout()`
  /// then resets the timer on every `onData` chunk for the rest of the
  /// stream. So a large but steadily-progressing download on a slow link is
  /// never killed by this; only a connection that goes silent mid-download
  /// (the same captive-portal/black-hole failure mode this finding is
  /// about) trips it.
  static const Duration _downloadStallTimeout = Duration(seconds: 30);

  final Dio _dio;

  @override
  Future<UpdateRelease?> fetchLatest() async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(
        latestReleaseUrl,
        options: Options(
          headers: const {'Accept': 'application/vnd.github+json'},
          connectTimeout: _connectTimeout,
          receiveTimeout: _metadataReceiveTimeout,
        ),
      );
    } on DioException catch (e) {
      // A repo with no releases at all returns 404 from this endpoint —
      // that's "nothing to update to", not a failure. Only treat it that
      // way when the server actually answered with a 404: a connection
      // failure (offline, DNS, a blocked host) carries no response at all
      // and must still surface as an error rather than be swallowed here.
      if (e.type == DioExceptionType.badResponse &&
          e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
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
      options: Options(
        responseType: ResponseType.plain,
        connectTimeout: _connectTimeout,
        receiveTimeout: _metadataReceiveTimeout,
      ),
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
        UpdateFailureCode.checksumUnreadable,
      );
    }
    return digest;
  }

  @override
  Future<void> downloadZip(
    UpdateRelease release,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) => _downloadReleaseZip(_dio, release, savePath, onProgress: onProgress);
}

/// Streams [release]'s zip to [savePath] with the shared timeouts. [dio]
/// must carry no base URL or auth: the zip URL is absolute and public.
Future<void> _downloadReleaseZip(
  Dio dio,
  UpdateRelease release,
  String savePath, {
  void Function(int received, int total)? onProgress,
}) async {
  await dio.download(
    release.zipUrl,
    savePath,
    options: Options(
      connectTimeout: GithubReleaseSource._connectTimeout,
      receiveTimeout: GithubReleaseSource._downloadStallTimeout,
    ),
    onReceiveProgress: (received, total) {
      // GitHub sends Content-Length, but fall back to the asset size from
      // the API when a proxy strips it, so the progress bar stays useful.
      onProgress?.call(received, total > 0 ? total : release.zipSize);
    },
  );
}

/// Reads releases from the Pixel Park backend's mirror of the GitHub
/// releases (`/v1/pos/app-update/*`) — park networks block github.com, but
/// always reach our own API.
///
/// The `latest` check goes through the app's [Dio] ([_api]): it needs the
/// cashier token and gets its refresh-on-401 for free. The zip itself is
/// public and fetched with a separate plain client ([_download]), so the
/// app client's retry interceptor never re-issues a half-finished download.
class BackendReleaseSource implements ReleaseSource {
  BackendReleaseSource({required this._api, Dio? download})
    : _download = download ?? Dio();

  static const String latestPath = '/v1/pos/app-update/latest';

  final Dio _api;
  final Dio _download;

  @override
  Future<UpdateRelease?> fetchLatest() async {
    final response = await _api.get<Map<String, dynamic>>(
      latestPath,
      options: Options(
        connectTimeout: GithubReleaseSource._connectTimeout,
        receiveTimeout: GithubReleaseSource._metadataReceiveTimeout,
      ),
    );
    final data = response.data;
    if (data == null) return null;
    return updateReleaseFromBackendJson(
      data,
      downloadBaseUrl: _api.options.baseUrl,
    );
  }

  @override
  Future<String?> fetchSha256(UpdateRelease release) async {
    final digest = parseSha256Digest(release.sha256);
    // The mirror always stores a digest, so a missing one means a broken
    // payload — fail closed instead of installing unverified.
    if (digest == null) {
      throw UpdateException(
        'The update server sent no valid checksum for version '
        '${release.version}. Refusing to install an unverified update.',
        UpdateFailureCode.checksumUnreadable,
      );
    }
    return digest;
  }

  @override
  Future<void> downloadZip(
    UpdateRelease release,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) =>
      _downloadReleaseZip(_download, release, savePath, onProgress: onProgress);
}

/// Tries [primary] first and falls back to [fallback] only when [primary]
/// fails outright (an older backend without the mirror answers 404, or the
/// API is unreachable). A release found by one source is always downloaded
/// and verified through that same source.
class FallbackReleaseSource implements ReleaseSource {
  FallbackReleaseSource({required this.primary, required this.fallback});

  final ReleaseSource primary;
  final ReleaseSource fallback;

  final Expando<ReleaseSource> _origin = Expando('release origin');

  @override
  Future<UpdateRelease?> fetchLatest() async {
    UpdateRelease? release;
    ReleaseSource source = primary;
    try {
      release = await primary.fetchLatest();
    } catch (_) {
      source = fallback;
      release = await fallback.fetchLatest();
    }
    if (release != null) _origin[release] = source;
    return release;
  }

  ReleaseSource _sourceOf(UpdateRelease release) => _origin[release] ?? primary;

  @override
  Future<String?> fetchSha256(UpdateRelease release) =>
      _sourceOf(release).fetchSha256(release);

  @override
  Future<void> downloadZip(
    UpdateRelease release,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) =>
      _sourceOf(release).downloadZip(release, savePath, onProgress: onProgress);
}
