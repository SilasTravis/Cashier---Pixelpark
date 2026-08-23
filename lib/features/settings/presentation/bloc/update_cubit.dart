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

/// Distinguishes an [UpdateException] — thrown by the update layer with a
/// message already written to be shown to a cashier (see
/// `update_exception.dart`) — from anything else. The most likely
/// "anything else" is a `DioException` from an offline or blocked POS
/// machine, whose `toString()` is a multi-line technical dump. [known]
/// failures are safe to render as [UpdateFailure.message] directly;
/// [unexpected] failures are not, and the UI is expected to substitute its
/// own localized generic message instead.
enum UpdateFailureKind { known, unexpected }

class UpdateFailure extends UpdateState {
  const UpdateFailure(
    this.message,
    this.releasePageUrl, {
    this.kind = UpdateFailureKind.known,
    this.debugDetail,
  });

  /// Human-readable and safe to show as-is when [kind] is
  /// [UpdateFailureKind.known]. Empty when [kind] is
  /// [UpdateFailureKind.unexpected] — the UI must not fall back to
  /// displaying it, and should render its own localized message instead.
  final String message;

  /// Shown so an operator can always fall back to a manual download.
  final String? releasePageUrl;

  final UpdateFailureKind kind;

  /// The raw error, for logs or a diagnostic details view — never meant to
  /// be shown to a cashier directly. Only set when [kind] is
  /// [UpdateFailureKind.unexpected].
  final String? debugDetail;
}

class UpdateCubit extends Cubit<UpdateState> {
  UpdateCubit(this._service) : super(const UpdateIdle());

  final UpdateService _service;

  String get currentVersion => _service.currentVersion;

  Future<void> check() async {
    emit(const UpdateChecking());
    try {
      final release = await _service.check();
      emit(release == null ? const UpdateUpToDate() : UpdateAvailable(release));
    } catch (error) {
      emit(_failureFrom(error, null));
    }
  }

  Future<void> download(UpdateRelease release) async {
    emit(UpdateDownloading(release, 0, release.zipSize));
    try {
      final staged = await _service.downloadAndStage(
        release,
        onProgress: (received, total) {
          if (isClosed) return;
          emit(UpdateDownloading(release, received, total));
        },
      );
      emit(UpdateReadyToRestart(release, staged));
    } catch (error) {
      emit(_failureFrom(error, release.releasePageUrl));
    }
  }

  /// Does not return when it succeeds — the process is replaced.
  Future<void> restart() async {
    final current = state;
    if (current is! UpdateReadyToRestart) return;
    try {
      await _service.applyAndRestart(current.staged);
    } catch (error) {
      emit(_failureFrom(error, current.release.releasePageUrl));
    }
  }

  /// [UpdateException] messages are already written for a cashier to read,
  /// so they pass through untouched. Anything else is reduced to a kind the
  /// UI can react to, with the raw text kept only for diagnosis — never
  /// interpolated into the user-facing message.
  UpdateFailure _failureFrom(Object error, String? releasePageUrl) {
    if (error is UpdateException) {
      return UpdateFailure(error.message, releasePageUrl);
    }
    return UpdateFailure(
      '',
      releasePageUrl,
      kind: UpdateFailureKind.unexpected,
      debugDetail: error.toString(),
    );
  }
}
