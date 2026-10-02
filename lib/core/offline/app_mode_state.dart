part of 'app_mode_cubit.dart';

enum AppMode { online, offline, syncing }

/// Which confirmation modal the shell owes the cashier right now.
enum ModePrompt { none, goOffline, goOnline }

class AppModeState extends Equatable {
  const AppModeState({
    this.mode = AppMode.online,
    this.prompt = ModePrompt.none,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastReport,
  });

  final AppMode mode;
  final ModePrompt prompt;
  final int pendingCount;
  final int failedCount;

  /// Outcome of the last sync until the UI has shown it
  /// ([AppModeCubit.reportShown]).
  final SyncReport? lastReport;

  /// Syncing counts as offline for gating — no online-only action may start
  /// while the queue is being replayed.
  bool get isOffline => mode != AppMode.online;
  int get queuedCount => pendingCount + failedCount;

  AppModeState copyWith({
    AppMode? mode,
    ModePrompt? prompt,
    int? pendingCount,
    int? failedCount,
    SyncReport? lastReport,
    bool clearReport = false,
  }) => AppModeState(
    mode: mode ?? this.mode,
    prompt: prompt ?? this.prompt,
    pendingCount: pendingCount ?? this.pendingCount,
    failedCount: failedCount ?? this.failedCount,
    lastReport: clearReport ? null : (lastReport ?? this.lastReport),
  );

  @override
  List<Object?> get props => [
    mode,
    prompt,
    pendingCount,
    failedCount,
    lastReport,
  ];
}
