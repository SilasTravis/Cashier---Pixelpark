/// Matches a lowercase-normalized SHA-256 hex digest: 64 hex characters.
final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

/// Parses the raw text of a `.sha256` release asset into a lowercase hex
/// digest. Accepts a bare digest or the `<digest>  <filename>` form produced
/// by `sha256sum`, trims surrounding whitespace, and normalizes case.
///
/// Returns null when [raw] is null, empty, or doesn't reduce to a valid
/// 64-character hex digest — e.g. an HTML error page served for a 404 or a
/// redirect. That mirrors [UpdateRelease.sha256Url] being null: "no digest
/// published", which callers already handle by skipping verification.
String? parseSha256Digest(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  // The file may be a bare digest or `<digest>  <filename>`.
  final token = trimmed.split(RegExp(r'\s+')).first.toLowerCase();
  return _sha256Pattern.hasMatch(token) ? token : null;
}

/// One published release, reduced to what the updater needs.
class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.notes,
    required this.zipUrl,
    required this.zipSize,
    required this.sha256Url,
    required this.releasePageUrl,
    this.sha256,
  });

  /// Release tag with any leading `v` stripped, e.g. `1.2.3`.
  final String version;
  final String notes;
  final String zipUrl;
  final int zipSize;

  /// Null when CI didn't attach a digest — the download then skips
  /// verification rather than refusing to update.
  final String? sha256Url;
  final String releasePageUrl;

  /// The digest itself, for sources that return it inline with the release
  /// (the Pixel Park backend mirror) instead of as a separate asset.
  final String? sha256;

  /// Parses `GET /repos/{owner}/{repo}/releases/latest`. Returns null when
  /// the payload has no tag or no `.zip` asset, which is what a release
  /// published by hand (or by a half-finished CI run) looks like.
  static UpdateRelease? fromGithubJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String?;
    if (tag == null || tag.isEmpty) return null;

    final assets = (json['assets'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final zip = _assetEndingWith(assets, '.zip');
    if (zip == null) return null;

    final zipUrl = zip['browser_download_url'];
    if (zipUrl is! String) return null;

    return UpdateRelease(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      notes: (json['body'] as String?) ?? '',
      zipUrl: zipUrl,
      zipSize: (zip['size'] as num?)?.toInt() ?? 0,
      sha256Url:
          _assetEndingWith(assets, '.sha256')?['browser_download_url']
              as String?,
      releasePageUrl: (json['html_url'] as String?) ?? '',
    );
  }

  static Map<String, dynamic>? _assetEndingWith(
    List<Map<String, dynamic>> assets,
    String suffix,
  ) {
    for (final asset in assets) {
      final name = asset['name'] as String?;
      if (name != null && name.endsWith(suffix)) return asset;
    }
    return null;
  }
}

/// Parses `GET /v1/pos/app-update/latest` from the Pixel Park backend, which
/// mirrors the GitHub releases for park networks that block github.com.
/// Returns null when the mirror holds no release yet or the payload is
/// malformed. [downloadBaseUrl] is the API origin the zip is served from.
UpdateRelease? updateReleaseFromBackendJson(
  Map<String, dynamic> json, {
  required String downloadBaseUrl,
}) {
  final latest = json['latest'];
  if (latest is! Map<String, dynamic>) return null;
  final version = latest['version'];
  if (version is! String || version.isEmpty) return null;
  final base = downloadBaseUrl.replaceAll(RegExp(r'/+$'), '');
  return UpdateRelease(
    version: version,
    notes: (latest['notes'] as String?) ?? '',
    zipUrl: '$base/v1/pos/app-update/${Uri.encodeComponent(version)}/download',
    zipSize: (latest['zipSize'] as num?)?.toInt() ?? 0,
    sha256Url: null,
    sha256: latest['sha256'] as String?,
    // github.com is exactly what's blocked here — no page worth linking.
    releasePageUrl: '',
  );
}
