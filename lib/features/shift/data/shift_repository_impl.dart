import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failure.dart';
import '../../../core/local_source/local_source.dart';
import '../../offline/data/offline_store.dart';
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

  Either<Failure, Shift> _localShift(String? cashierId) {
    if (cashierId != null) {
      final cached = _store.cachedShift(cashierId);
      if (cached != null && cached.isOpen) return Right(cached);
      final offline = _store.offlineShift(cashierId);
      if (offline != null) return Right(offline.toShift());
    }
    return Left(
      ServerFailure(message: 'Smena ochilmagan', code: 'SHIFT_NOT_OPEN'),
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
