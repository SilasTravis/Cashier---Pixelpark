import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/offline/application/offline_sync_service.dart';
import '../../features/offline/data/offline_store.dart';
import '../../features/offline/domain/offline_sale.dart';
import '../connectivity/connectivity_monitor.dart';

part 'app_mode_state.dart';

typedef RunSync =
    Future<SyncReport> Function({Set<String>? onlyIds, bool includeFailed});

/// App-wide online/offline mode. Never switches on its own: it raises a
/// [ModePrompt] and waits for the cashier to confirm (spec D13).
class AppModeCubit extends Cubit<AppModeState> {
  AppModeCubit({
    required Stream<ConnectivityEvent> connectivity,
    required Future<bool> Function() checkNow,
    required OfflineStore store,
    required RunSync sync,
    required String? Function() currentCashierId,
    DateTime Function()? clock,
    this.postponeFor = const Duration(minutes: 5),
  }) : _checkNow = checkNow, // ignore: prefer_initializing_formals
       _store = store,
       _sync = sync, // ignore: prefer_initializing_formals
       _cashierId = currentCashierId, // ignore: prefer_initializing_formals
       _clock = clock ?? DateTime.now,
       super(
         AppModeState(
           mode: store.isOfflineMode ? AppMode.offline : AppMode.online,
         ),
       ) {
    _subscription = connectivity.listen(_onConnectivity);
    _store.addListener(refreshCounts);
    refreshCounts();
  }

  final Duration postponeFor;
  final Future<bool> Function() _checkNow;
  final OfflineStore _store;
  final RunSync _sync;
  final String? Function() _cashierId;
  final DateTime Function() _clock;
  late final StreamSubscription<ConnectivityEvent> _subscription;

  DateTime? _declinedAt;
  DateTime? _postponedAt;

  void _onConnectivity(ConnectivityEvent event) {
    switch (state.mode) {
      case AppMode.online:
        if (event.reachable) {
          _declinedAt = null;
          if (state.prompt == ModePrompt.goOffline) {
            emit(state.copyWith(prompt: ModePrompt.none));
          }
          return;
        }
        if (state.prompt != ModePrompt.none) return;
        if (_declinedAt != null && !event.fromUserRequest) return;
        emit(state.copyWith(prompt: ModePrompt.goOffline));
      case AppMode.offline:
        if (!event.reachable) {
          if (state.prompt == ModePrompt.goOnline) {
            emit(state.copyWith(prompt: ModePrompt.none));
          }
          return;
        }
        if (state.prompt != ModePrompt.none || _isPostponed) return;
        emit(state.copyWith(prompt: ModePrompt.goOnline));
      case AppMode.syncing:
        return;
    }
  }

  bool get _isPostponed =>
      _postponedAt != null && _clock().difference(_postponedAt!) < postponeFor;

  Future<void> acceptOffline() async {
    _declinedAt = null;
    await _store.setOfflineMode(true);
    emit(state.copyWith(mode: AppMode.offline, prompt: ModePrompt.none));
  }

  void declineOffline() {
    _declinedAt = _clock();
    emit(state.copyWith(prompt: ModePrompt.none));
  }

  /// "Onlaynni tekshirish". Ignores the postpone window on purpose.
  Future<bool> checkOnlineNow() async {
    final reachable = await _checkNow();
    if (reachable && state.mode == AppMode.offline) {
      emit(state.copyWith(prompt: ModePrompt.goOnline));
    }
    return reachable;
  }

  void postponeOnline() {
    _postponedAt = _clock();
    emit(state.copyWith(prompt: ModePrompt.none));
  }

  Future<void> acceptOnline() async {
    emit(
      state.copyWith(
        mode: AppMode.syncing,
        prompt: ModePrompt.none,
        clearReport: true,
      ),
    );
    final report = await _sync();
    if (report.transportFailed && !report.serverReachable) {
      // The connection itself failed: genuinely still offline.
      _postponedAt = _clock();
      emit(state.copyWith(mode: AppMode.offline, lastReport: report));
      return;
    }
    // Any HTTP answer (even a 5xx) proves the server is reachable. Locking
    // the till offline on a persistent server error would also block
    // logout forever, so go online; the sales stay pending (Unsynced tab)
    // and the report tells the cashier what went wrong.
    _postponedAt = null;
    await _store.setOfflineMode(false);
    emit(state.copyWith(mode: AppMode.online, lastReport: report));
  }

  /// The Unsynced page's Retry. Resends failed sales too; online only.
  Future<SyncReport> retry({Set<String>? ids}) async {
    if (state.mode != AppMode.online) return SyncReport.empty;
    final report = await _sync(onlyIds: ids, includeFailed: true);
    emit(state.copyWith(lastReport: report));
    return report;
  }

  void reportShown() => emit(state.copyWith(clearReport: true));

  /// Also called by the shell after login — the counts belong to whoever is
  /// signed in.
  void refreshCounts() {
    if (isClosed) return;
    final cashierId = _cashierId();
    final sales = cashierId == null
        ? const <OfflineSale>[]
        : _store.sales(cashierId: cashierId);
    final failed = sales.where((sale) => sale.isFailed).length;
    emit(
      state.copyWith(pendingCount: sales.length - failed, failedCount: failed),
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    _store.removeListener(refreshCounts);
    return super.close();
  }
}
