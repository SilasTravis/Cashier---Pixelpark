class UpdateManifest {
  const UpdateManifest({required this.version, required this.url, this.notes});

  final String version;
  final String url;
  final String? notes;

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    return UpdateManifest(
      version: json['version'] as String,
      url: json['url'] as String,
      notes: json['notes'] as String?,
    );
  }
}
