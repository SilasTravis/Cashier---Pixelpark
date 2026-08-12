/// Returns true if [remote] is a newer version than [current]. Both are
/// dot-separated numeric versions (e.g. `1.2.0`); a `+build` suffix (as in
/// `pubspec.yaml`'s `1.0.0+1`) is ignored since it isn't user-facing.
bool isNewerVersion(String remote, String current) {
  final r = _parts(remote);
  final c = _parts(current);
  for (var i = 0; i < 3; i++) {
    final rv = i < r.length ? r[i] : 0;
    final cv = i < c.length ? c[i] : 0;
    if (rv != cv) return rv > cv;
  }
  return false;
}

List<int> _parts(String version) => version
    .split('+')
    .first
    .split('.')
    .map((part) => int.tryParse(part) ?? 0)
    .toList();
