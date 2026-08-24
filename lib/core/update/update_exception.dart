/// The closed set of reasons the update layer refuses to proceed.
///
/// The app is trilingual (Uzbek/Russian/English), but [UpdateException] is
/// written in English (see its doc comment) — that text is for logs and
/// `toString()` only. `UpdateCard` switches on this code instead to pick a
/// fully localized ARB string for the cashier, so no English leaks into the
/// UI for a case this enum names.
enum UpdateFailureCode {
  /// The downloaded zip's SHA-256 didn't match the digest GitHub published
  /// for the release.
  checksumMismatch,

  /// A `.sha256` asset was published, but its body wasn't a valid 64-char
  /// hex digest — the update refuses rather than silently skipping
  /// verification (see the checksum policy in `release_source.dart`).
  checksumUnreadable,

  /// The extracted archive has no `cashier_app.exe` at its root.
  executableMissing,

  /// `extractFileToDisk` reported success but left one or more files short
  /// or missing on disk (see `verifyExtractedArchive`).
  incompleteExtraction,

  /// [UpdateService.applyAndRestart] was called on a non-Windows platform.
  unsupportedPlatform,

  /// No code applies — a stand-in used by tests, or a genuinely
  /// uncategorized failure. `UpdateCard` falls back to showing
  /// [UpdateException.message] verbatim (in English) for this case. No
  /// production throw site in this codebase should reach for [other]: each
  /// of the five cases above already has a real throw site and localized
  /// text, and a sixth case belongs in this enum, not behind [other].
  other,
}

/// Thrown by the update layer when something about a release, its checksum,
/// or its download cannot be trusted enough to proceed.
///
/// [message] is written in English and is developer-facing only — log it or
/// show it in a diagnostics view, but never render it directly in the UI.
/// [code] identifies which of the closed set of [UpdateFailureCode] cases
/// this is, so the UI can show fully localized, cashier-facing text instead
/// (see `UpdateCard`).
class UpdateException implements Exception {
  const UpdateException(this.message, [this.code = UpdateFailureCode.other]);

  final String message;
  final UpdateFailureCode code;

  @override
  String toString() => message;
}
