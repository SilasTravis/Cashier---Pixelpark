/// One published GitHub release, reduced to what the updater needs.
class UpdateRelease {
  const UpdateRelease({
    required this.version,
    required this.notes,
    required this.zipUrl,
    required this.zipSize,
    required this.sha256Url,
    required this.releasePageUrl,
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

    return UpdateRelease(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      notes: (json['body'] as String?) ?? '',
      zipUrl: zip['browser_download_url'] as String,
      zipSize: (zip['size'] as num?)?.toInt() ?? 0,
      sha256Url:
          _assetEndingWith(assets, '.sha256')?['browser_download_url'] as String?,
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
