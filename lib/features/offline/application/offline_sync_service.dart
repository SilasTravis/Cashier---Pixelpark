import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../../../core/error/exceptions.dart';
import '../../shift/domain/shift.dart';
import '../data/offline_store.dart';
import '../data/offline_sync_remote_data_source.dart';
import '../domain/offline_sale.dart';
import '../domain/offline_shift.dart';

class SyncReport extends Equatable {
  const SyncReport({
    this.syncedCount = 0,
    this.failed = const [],
    this.transportError,
  });

  static const empty = SyncReport();

  final int syncedCount;
  final List<OfflineSale> failed;

  /// Set when a request never got per-sale answers (no internet, 5xx, 401…).
  /// Every sale of that request is still pending and safe to resend.
  final String? transportError;

  bool get transportFailed => transportError != null;

  @override
  List<Object?> get props => [syncedCount, failed, transportError];
}

/// Replays the signed-in cashier's queue to `POST /v1/pos/offline/sync`,
/// offline shift first. Created/duplicate sales leave the queue; rejected
/// ones stay as `failed` with the server's reason, never deleted.
class OfflineSyncService {
  OfflineSyncService(
    this._store,
    this._remote,
    this._currentCashierId, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const batchSize = 200;

  final OfflineStore _store;
  final OfflineSyncRemoteDataSource _remote;
  final String? Function() _currentCashierId;
  final DateTime Function() _clock;

  Future<SyncReport>? _inFlight;
  ({Set<String>? onlyIds, bool includeFailed})? _inFlightArgs;

  /// [includeFailed]: the automatic sync on reconnect only sends pending
  /// sales; the Unsynced page's Retry resends failed ones too.
  ///
  /// A call that matches the currently running one (same [onlyIds]/
  /// [includeFailed]) shares its result. A call with different arguments —
  /// e.g. a Retry tapped while the automatic sync is mid-flight — must not
  /// be swallowed by it, so it waits for that run to finish and then starts
  /// its own; only one sync request is ever outstanding at a time.
  Future<SyncReport> sync({Set<String>? onlyIds, bool includeFailed = false}) {
    final inFlight = _inFlight;
    if (inFlight != null) {
      if (_sameArgs(_inFlightArgs, onlyIds, includeFailed)) return inFlight;
      return inFlight.then(
        (_) => sync(onlyIds: onlyIds, includeFailed: includeFailed),
      );
    }
    _inFlightArgs = (onlyIds: onlyIds, includeFailed: includeFailed);
    final future = _sync(onlyIds, includeFailed).whenComplete(() {
      _inFlight = null;
      _inFlightArgs = null;
    });
    _inFlight = future;
    return future;
  }

  static bool _sameArgs(
    ({Set<String>? onlyIds, bool includeFailed})? args,
    Set<String>? onlyIds,
    bool includeFailed,
  ) {
    if (args == null || args.includeFailed != includeFailed) return false;
    final a = args.onlyIds;
    if (a == null || onlyIds == null) return a == onlyIds;
    return a.length == onlyIds.length && a.containsAll(onlyIds);
  }

  Future<SyncReport> _sync(Set<String>? onlyIds, bool includeFailed) async {
    final cashierId = _currentCashierId();
    if (cashierId == null) return SyncReport.empty;

    var shift = _store.offlineShift(cashierId);
    final queue = _store
        .sales(cashierId: cashierId)
        .where((sale) => includeFailed || !sale.isFailed)
        .where(
          (sale) => onlyIds == null || onlyIds.contains(sale.offlineRequestId),
        )
        .toList();
    if (queue.isEmpty && (shift == null || shift.isSynced)) {
      return SyncReport.empty;
    }

    final batches = <List<OfflineSale>>[
      for (var i = 0; i < queue.length; i += batchSize)
        queue.sublist(i, math.min(i + batchSize, queue.length)),
    ];
    if (batches.isEmpty) batches.add(const []); // shift-only request

    var synced = 0;
    final failed = <OfflineSale>[];

    // Sends one request (a batch, or one sale resent solo after the batch it
    // was part of got rejected outright). Returns a transport-error message
    // when the request never got per-sale answers; null otherwise. [shift]
    // is only offered on [includeShift] — set for the very first request of
    // the whole sync, and never again, even if that first request had to be
    // split into solo retries (I1).
    Future<String?> sendRequest(
      List<OfflineSale> saleBatch, {
      required bool includeShift,
    }) async {
      final sendShift = includeShift && shift != null && !shift!.isSynced;
      final OfflineSyncResult result;
      try {
        result = await _remote.sync(
          shifts: sendShift ? [shift!.toSyncJson()] : const [],
          sales: [for (final sale in saleBatch) _payload(sale, shift)],
        );
      } on NoInternetException {
        return "Internet aloqasi yo'q";
      } on ServerException catch (e) {
        return e.message;
      } on OfflineSyncValidationException catch (e) {
        if (saleBatch.length > 1) {
          var carryShift = includeShift;
          for (final sale in saleBatch) {
            final err = await sendRequest([sale], includeShift: carryShift);
            carryShift = false;
            if (err != null) return err;
          }
          return null;
        }
        // A single sale still fails validation on its own — it's genuinely
        // bad (out-of-range qty/price, an empty line list…), not a victim of
        // some other sale in the batch. Fail it and move on.
        final sale = saleBatch.single;
        final marked = sale.markFailed(
          code: e.code ?? 'VALIDATION',
          message: e.message,
          at: _clock(),
        );
        await _store.putSale(marked);
        failed.add(marked);
        return null;
      }

      shift = await _applyShiftResults(shift, result.shifts);

      final byId = {for (final sale in saleBatch) sale.offlineRequestId: sale};
      final done = <String>[];
      for (final item in result.sales) {
        final sale = byId[item.offlineRequestId];
        if (sale == null) continue;
        if (item.status == OfflineSyncStatus.rejected) {
          final marked = sale.markFailed(
            code: item.code,
            message: item.message ?? 'Server savdoni qabul qilmadi',
            at: _clock(),
          );
          await _store.putSale(marked);
          failed.add(marked);
        } else {
          done.add(item.offlineRequestId);
        }
      }
      await _store.removeSales(done);
      synced += done.length;
      return null;
    }

    for (var i = 0; i < batches.length; i++) {
      final error = await sendRequest(batches[i], includeShift: i == 0);
      if (error != null) {
        return SyncReport(
          syncedCount: synced,
          failed: failed,
          transportError: error,
        );
      }
    }

    await _releaseOfflineShiftIfDone(cashierId);
    return SyncReport(syncedCount: synced, failed: failed);
  }

  Map<String, dynamic> _payload(OfflineSale sale, OfflineShift? shift) =>
      sale.toSyncJson(
        serverShiftIdForOfflineShift:
            shift != null &&
                sale.shiftOfflineRequestId == shift.offlineRequestId
            ? shift.serverShiftId
            : null,
      );

  Future<OfflineShift?> _applyShiftResults(
    OfflineShift? shift,
    List<OfflineSyncItemResult> results,
  ) async {
    if (shift == null) return null;
    for (final item in results) {
      if (item.offlineRequestId == shift!.offlineRequestId &&
          item.status != OfflineSyncStatus.rejected &&
          item.serverId != null) {
        shift = shift.withServerShiftId(item.serverId!);
        await _store.saveOfflineShift(shift);
      }
    }
    return shift;
  }

  /// A synced offline shift is only kept while some queued sale still names
  /// it; after that the server's own shift (cached online) takes over.
  Future<void> _releaseOfflineShiftIfDone(String cashierId) async {
    final shift = _store.offlineShift(cashierId);
    if (shift == null || !shift.isSynced) return;
    final stillReferenced = _store
        .sales(cashierId: cashierId)
        .any((sale) => sale.shiftOfflineRequestId == shift.offlineRequestId);
    if (stillReferenced) return;
    // Keep the till on that shift even if it drops offline again before the
    // shell has reloaded the server shift.
    if (_store.cachedShift(cashierId) == null) {
      await _store.cacheShift(
        cashierId,
        Shift(
          id: shift.serverShiftId!,
          openedAt: shift.openedAt,
          closedAt: null,
          status: 'open',
          totals: ShiftTotals.zero,
        ),
      );
    }
    await _store.clearOfflineShift(cashierId);
  }
}
