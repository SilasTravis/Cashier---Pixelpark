import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/update/update_exception.dart';
import '../../../../core/update/update_release.dart';
import '../../../../core/update/update_service.dart';

sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate();
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.release);

  final UpdateRelease release;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.release, this.received, this.total);

  final UpdateRelease release;
  final int received;
  final int total;

  /// 0.0–1.0, or null while the total size is still unknown.
  double? get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : null;
}

class UpdateReadyToRestart extends UpdateState {
  const UpdateReadyToRestart(this.release, this.staged);

  final UpdateRelease release;
  final Directory staged;
}

/// Common supertype for both update-failure shapes, so `state is
/// UpdateFailure` still works as a general check (e.g. to show a shared
/// "Retry" button regardless of which kind occurred). It carries no
/// displayable text itself — see the two subclasses for what each renders.
///
/// Sealed on purpose: the next task's card is expected to `switch`
/// exhaustively over the full [UpdateState] hierarchy, so handling both
/// [UpdateFailureKnown] and [UpdateFailureUnexpected] is a compile-time
/// obligation rather than a doc comment a caller can miss.
sealed class UpdateFailure extends UpdateState {
  const UpdateFailure(this.releasePageUrl);

  /// Shown so an operator can always fall back to a manual download.
  final String? releasePageUrl;
}

/// An [UpdateException] was thrown by the update layer. Its [message] is
/// already written to be shown directly to a cashier (see
/// `update_exception.dart`) and is safe to render as-is.
class UpdateFailureKnown extends UpdateFailure {
  const UpdateFailureKnown(this.message, super.releasePageUrl);

  final String message;
}

/// Anything other than an [UpdateException] — most realistically a
/// `DioException` from an offline or blocked POS machine, whose
/// `toString()` is a multi-line technical dump. There is deliberately no
/// displayable message here: the UI must substitute its own localized
/// generic text instead of rendering [debugDetail].
class UpdateFailureUnexpected extends UpdateFailure {
  const UpdateFailureUnexpected(this.debugDetail, super.releasePageUrl);

  /// The raw error, for logs or a diagnostic details view only — never
  /// meant to be shown to a cashier directly.
  final String debugDetail;
}

class UpdateCubit extends Cubit<UpdateState> {
  UpdateCubit(this._service) : super(const UpdateIdle());

  final UpdateService _service;

  String get currentVersion => _service.currentVersion;

  Future<void> check() async {
    _emit(const UpdateChecking());
    try {
      final release = await _service.check();
      _emit(
        release == null ? const UpdateUpToDate() : UpdateAvailable(release),
      );
    } catch (error) {
      _emit(_failureFrom(error, null));
    }
  }

  Future<void> download(UpdateRelease release) async {
    _emit(UpdateDownloading(release, 0, release.zipSize));
    try {
      final staged = await _service.downloadAndStage(
        release,
        onProgress: (received, total) {
          _emit(UpdateDownloading(release, received, total));
        },
      );
      _emit(UpdateReadyToRestart(release, staged));
    } catch (error) {
      _emit(_failureFrom(error, release.releasePageUrl));
    }
  }

  /// Does not return when it succeeds — the process is replaced.
  Future<void> restart() async {
    final current = state;
    if (current is! UpdateReadyToRestart) return;
    try {
      await _service.applyAndRestart(current.staged);
    } catch (error) {
      _emit(_failureFrom(error, current.release.releasePageUrl));
    }
  }

  /// Every emit in this cubit goes through here instead of calling `emit`
  /// directly. `bloc`'s `emit` throws a `StateError` once the cubit is
  /// closed, and `check()`/`download()`/`restart()` all resume after an
  /// `await` whose surrounding call may have outlived the cubit (e.g. the
  /// cashier navigated away from Settings while a check or download was
  /// still in flight). Swallowing that case here — rather than only at the
  /// download-progress callback — means no code path in this class can
  /// throw from a post-close emit, including from inside a `catch` block,
  /// where a second throw would otherwise go uncaught.
  void _emit(UpdateState state) {
    if (isClosed) return;
    emit(state);
  }

  /// [UpdateException] messages are already written for a cashier to read,
  /// so they pass through untouched as [UpdateFailureKnown]. Anything else
  /// becomes [UpdateFailureUnexpected], with the raw text kept only in
  /// [UpdateFailureUnexpected.debugDetail] for diagnosis — there is no
  /// user-facing message field for it to leak into.
  UpdateFailure _failureFrom(Object error, String? releasePageUrl) {
    if (error is UpdateException) {
      return UpdateFailureKnown(error.message, releasePageUrl);
    }
    return UpdateFailureUnexpected(error.toString(), releasePageUrl);
  }
}
