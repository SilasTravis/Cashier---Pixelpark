import '../local_source/local_source.dart';
import 'update_exception.dart';
import 'version_compare.dart';

/// The most recent self-update attempt that failed, as the terminal
/// heartbeat reports it (`lastUpdateFailure` in the heartbeat body).
class UpdateFailureRecord {
  const UpdateFailureRecord({
    required this.version,
    required this.code,
    required this.message,
    required this.at,
  });

  /// The version the till tried to install.
  final String version;

  /// An [UpdateFailureCode] name, or [UpdateFailureLog.unexpectedCode] for
  /// anything that wasn't an [UpdateException].
  final String code;

  /// Developer-facing English detail, at most
  /// [UpdateFailureLog.maxMessageLength] characters. Only an admin in the
  /// dashboard ever reads it — never the cashier.
  final String message;

  final DateTime at;

  Map<String, dynamic> toJson() => {
    'version': version,
    'code': code,
    'message': message,
    'at': at.toUtc().toIso8601String(),
  };

  /// Null for anything that isn't a complete record — a corrupt row must
  /// not break the heartbeat; it just reads as "no failure".
  static UpdateFailureRecord? tryParse(Map<String, dynamic> json) {
    final version = json['version'];
    final code = json['code'];
    final message = json['message'];
    final at = json['at'] is String ? DateTime.tryParse(json['at']) : null;
    if (version is! String || code is! String || message is! String) {
      return null;
    }
    if (at == null) return null;
    return UpdateFailureRecord(
      version: version,
      code: code,
      message: message,
      at: at,
    );
  }
}

/// Remembers the last failed download/stage/apply of a self-update, so the
/// terminal heartbeat can tell the dashboard "this till tried 1.0.8 and
/// failed its checksum" instead of the admin only seeing an old version.
///
/// Only failures a cashier actually triggered land here (the background
/// timer never downloads — see `UpdateService`); a failed *check* is not an
/// update failure and is not recorded.
///
/// A record stops being relevant once the till runs the version it tried
/// (or a newer one) — a later retry succeeded — so [current] drops it then.
/// A newer failure simply overwrites an older one.
class UpdateFailureLog {
  UpdateFailureLog({
    required this._localSource,
    required this._currentVersion,
    this._clock = DateTime.now,
  });

  /// The code for a failure that wasn't an [UpdateException] — most
  /// realistically a `DioException` from a dropped download.
  static const String unexpectedCode = 'unexpected';

  /// The backend's column limits (`cashier_terminals`).
  static const int maxMessageLength = 500;
  static const int maxCodeLength = 50;

  static final RegExp _plainVersion = RegExp(r'^\d{1,6}\.\d{1,6}\.\d{1,6}$');

  final LocalSource _localSource;
  final String _currentVersion;
  final DateTime Function() _clock;

  /// Never throws: a broken Hive write must not replace the real update
  /// error the cashier is about to see.
  Future<void> record(String version, Object error) async {
    // The backend accepts only plain x.y.z here and rejects the WHOLE
    // heartbeat otherwise — a GitHub tag like `1.1.0-rc1` would silence
    // this till on the dashboard until it ran that version.
    if (!_plainVersion.hasMatch(version)) return;
    final code = error is UpdateException ? error.code.name : unexpectedCode;
    final message = error is UpdateException ? error.message : error.toString();
    final record = UpdateFailureRecord(
      version: version,
      code: _truncate(code, maxCodeLength),
      message: _truncate(message, maxMessageLength),
      at: _clock(),
    );
    try {
      await _localSource.setLastUpdateFailure(record.toJson());
    } catch (_) {}
  }

  /// The stored failure while it is still relevant, else null. Clears a
  /// record the running version has already caught up with (and a corrupt
  /// one), so it stops being reported.
  UpdateFailureRecord? current() {
    final raw = _localSource.getLastUpdateFailure();
    if (raw == null) return null;
    final record = UpdateFailureRecord.tryParse(raw);
    if (record != null &&
        _plainVersion.hasMatch(record.version) &&
        isNewerVersion(record.version, _currentVersion)) {
      return record;
    }
    // Fire-and-forget: Hive drops the in-memory copy synchronously.
    _localSource.setLastUpdateFailure(null).catchError((_) {});
    return null;
  }

  static String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
