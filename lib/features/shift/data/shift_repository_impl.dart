import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failure.dart';
import '../../../core/local_source/local_source.dart';
import '../../offline/data/offline_store.dart';
import '../../offline/domain/offline_sale.dart';
import '../../offline/domain/offline_shift.dart';
import '../domain/shift.dart';
import 'shift_remote_data_source.dart';

/// Online: the server's shift, cached after every good load. Offline: that
/// cached shift, or one the cashier opens locally (spec D7) — created on the
/// server first when the queue syncs.
class ShiftRepository {
  ShiftRepository(
    this.remote,
    this._store,
    this._local, {
    String Function()? newId,
    DateTime Function()? clock,
  }) : _newId = newId ?? (() => const Uuid().v4()),
       _clock = clock ?? DateTime.now;

  final ShiftRemoteDataSource remote;
  final OfflineStore _store;
  final LocalSource _local;
  final String Function() _newId;
  final DateTime Function() _clock;

  Future<Either<Failure, Shift>> getCurrentShift() async {
    final cashierId = _local.getCashierId();
    if (_store.isOfflineMode) return _localShift(cashierId);
    final result = await _call(remote.getCurrentShift);
    if (cashierId == null) return result;
    return result.fold(
      (failure) async {
        if (failure is ServerFailure && failure.code == 'SHIFT_NOT_OPEN') {
          await _store.clearCachedShift(cashierId);
        }
        return Left(failure);
      },
      (shift) async {
        await _store.cacheShift(cashierId, shift);
        return Right(shift);
      },
    );
  }

  Future<Either<Failure, Shift>> openShift({int? openingCashUzs}) async {
    final cashierId = _local.getCashierId();
    if (_store.isOfflineMode) {
      if (cashierId == null) {
        return Left(CacheFailure(message: 'Kassir aniqlanmadi'));
      }
      if (openingCashUzs != null &&
          (openingCashUzs < 0 || openingCashUzs > 10000000000)) {
        return Left(CacheFailure(message: "Boshlang'ich naqd summa noto'g'ri"));
      }
      await _rehomeSalesOfSyncedOfflineShift(cashierId);
      final shift = OfflineShift(
        offlineRequestId: _newId(),
        cashierId: cashierId,
        openedAt: _clock(),
        openingCashUzs: openingCashUzs,
      );
      await _store.saveOfflineShift(shift);
      return Right(shift.toShift());
    }
    final result = await _call(
      () => remote.openShift(openingCashUzs: openingCashUzs),
    );
    return result.fold((failure) async => Left(failure), (shift) async {
      if (cashierId != null) await _store.cacheShift(cashierId, shift);
      return Right(shift);
    });
  }

  Future<Either<Failure, Shift>> closeShift({String? closingNote}) async {
    if (_store.isOfflineMode) {
      return Left(
        ServerFailure(
          message: "Offline rejimda smenani yopib bo'lmaydi",
          code: 'OFFLINE_UNAVAILABLE',
        ),
      );
    }
    final cashierId = _local.getCashierId();
    final pending = cashierId == null
        ? 0
        : _store.sales(cashierId: cashierId).where((s) => !s.isFailed).length;
    if (pending > 0) {
      return Left(
        ServerFailure(
          message:
              "$pending ta savdo hali sinxronlanmagan. Avval onlayn rejimda sinxronlang.",
          code: 'OFFLINE_SALES_PENDING',
        ),
      );
    }
    final result = await _call(
      () => remote.closeShift(closingNote: closingNote),
    );
    return result.fold((failure) async => Left(failure), (shift) async {
      if (cashierId != null) await _forgetShift(cashierId);
      return Right(shift);
    });
  }

  Future<void> _forgetShift(String cashierId) async {
    await _store.clearCachedShift(cashierId);
    final offline = _store.offlineShift(cashierId);
    final stillReferenced = _store
        .sales(cashierId: cashierId)
        .any((sale) => sale.shiftOfflineRequestId == offline?.offlineRequestId);
    if (offline != null && offline.isSynced && !stillReferenced) {
      await _store.clearOfflineShift(cashierId);
    }
  }

  /// The store keeps ONE offline shift per cashier. A synced one survives
  /// only as the mapping that lets its failed sales be retried against its
  /// server shift; before a new offline shift overwrites it, point those
  /// sales straight at the server shift so the mapping isn't needed.
  Future<void> _rehomeSalesOfSyncedOfflineShift(String cashierId) async {
    final old = _store.offlineShift(cashierId);
    if (old == null || !old.isSynced) return;
    for (final sale in _store.sales(cashierId: cashierId)) {
      if (sale.shiftOfflineRequestId == old.offlineRequestId) {
        await _store.putSale(sale.withServerShift(old.serverShiftId!));
      }
    }
  }

  Either<Failure, Shift> _localShift(String? cashierId) {
    if (cashierId != null) {
      final cached = _store.cachedShift(cashierId);
      if (cached != null && cached.isOpen) {
        return Right(
          _plusQueuedSales(cached, cashierId, (s) => s.shiftId == cached.id),
        );
      }
      // A synced offline shift is only a mapping (see above) — it may have
      // been closed on the server since, so it is never the open shift.
      final offline = _store.offlineShift(cashierId);
      if (offline != null && !offline.isSynced) {
        return Right(
          _plusQueuedSales(
            offline.toShift(),
            cashierId,
            (s) => s.shiftOfflineRequestId == offline.offlineRequestId,
          ),
        );
      }
    }
    return Left(
      ServerFailure(message: 'Smena ochilmagan', code: 'SHIFT_NOT_OPEN'),
    );
  }

  /// The cached totals stop at the last online load; add this shift's
  /// queued sales so the header's takings keep up offline. Failed sales are
  /// left out — the server refused them. PaymentSplit keeps cash + card ==
  /// total (no change given), so cash and card can be summed as tendered.
  Shift _plusQueuedSales(
    Shift shift,
    String cashierId,
    bool Function(OfflineSale sale) belongs,
  ) {
    final queued = _store
        .sales(cashierId: cashierId)
        .where((sale) => !sale.isFailed && belongs(sale))
        .toList();
    if (queued.isEmpty) return shift;
    int sum(int Function(OfflineSale sale) of) =>
        queued.fold(0, (total, sale) => total + of(sale));
    final t = shift.totals;
    return shift.copyWith(
      totals: ShiftTotals(
        salesCount: t.salesCount + queued.length,
        subtotalUzs: t.subtotalUzs + sum((s) => s.totalUzs),
        cashUzs: t.cashUzs + sum((s) => s.cashUzs),
        cardUzs: t.cardUzs + sum((s) => s.cardUzs),
        topupUzs: t.topupUzs,
        balanceSalesUzs: t.balanceSalesUzs,
        refundedUzs: t.refundedUzs,
        discountUzs: t.discountUzs + sum((s) => s.discountUzs),
      ),
    );
  }

  Future<Either<Failure, Shift>> _call(Future<Shift> Function() call) async {
    try {
      return Right(await call());
    } on ServerException catch (e) {
      return Left(
        ServerFailure(
          message: e.message,
          code: e.code,
          statusCode: e.statusCode,
        ),
      );
    } on NoInternetException {
      return Left(NoInternetFailure());
    }
  }
}
