import 'dart:io';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/core/error/failure.dart';
import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:cashier_app/features/offline/domain/offline_shift.dart';
import 'package:cashier_app/features/pos_sale/data/pos_sale_remote_data_source.dart';
import 'package:cashier_app/features/pos_sale/data/pos_sale_repository_impl.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';
import 'package:cashier_app/features/products/data/products_remote_data_source.dart';
import 'package:cashier_app/features/products/data/products_repository_impl.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/shift/data/shift_remote_data_source.dart';
import 'package:cashier_app/features/shift/data/shift_repository_impl.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _vip = Product(
  id: 'vip',
  name: 'VIP',
  priceUzs: 75000,
  category: 'Tariflar',
  icon: 'ph-crown',
  offlineOnly: true,
);
const _flyer = Discount(
  id: 'd',
  name: 'Flayer',
  kind: DiscountKind.percent,
  value: 10,
);
final _serverShift = Shift(
  id: 'shift-1',
  openedAt: DateTime.utc(2026, 9, 23, 8),
  closedAt: null,
  status: 'open',
  totals: ShiftTotals.zero,
);

class _Products extends ProductsRemoteDataSourceImpl {
  _Products() : super(Dio());
  Object? error;
  int calls = 0;
  @override
  Future<List<Product>> listProducts() async {
    calls++;
    if (error != null) throw error!;
    return const [_vip];
  }
}

class _Sales extends PosSaleRemoteDataSourceImpl {
  _Sales() : super(Dio());
  Object? error;
  @override
  Future<List<Discount>> fetchDiscounts() async {
    if (error != null) throw error!;
    return const [_flyer];
  }
}

class _Shifts extends ShiftRemoteDataSourceImpl {
  _Shifts() : super(Dio());
  Object? error;
  int calls = 0;
  @override
  Future<Shift> getCurrentShift() async {
    calls++;
    if (error != null) throw error!;
    return _serverShift;
  }

  @override
  Future<Shift> closeShift({String? closingNote}) async {
    calls++;
    return Shift(
      id: _serverShift.id,
      openedAt: _serverShift.openedAt,
      closedAt: DateTime.utc(2026, 9, 23, 20),
      status: 'closed',
      totals: ShiftTotals.zero,
    );
  }
}

void main() {
  late Directory temp;
  late Box<dynamic> offlineBox;
  late Box<dynamic> appBox;
  late OfflineStore store;
  late LocalSource local;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_offline_repos');
    Hive.init(temp.path);
    offlineBox = await Hive.openBox<dynamic>(OfflineStore.boxName);
    appBox = await Hive.openBox<dynamic>('cashier_app_box_test');
    store = OfflineStore(offlineBox);
    local = LocalSource(appBox)
      ..setCashier(
        id: 'cashier-1',
        fullName: 'Zaira',
        username: 'zaira',
        branchId: 'branch-1',
        branchName: 'Algoritm',
      );
  });

  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  group('ProductsRepository', () {
    test(
      'caches the catalog online and serves it offline without calling out',
      () async {
        final remote = _Products();
        final repository = ProductsRepository(remote, store, local);

        expect((await repository.listProducts()).getOrElse(() => []), const [
          _vip,
        ]);
        await store.setOfflineMode(true);
        remote.error = NoInternetException();

        expect((await repository.listProducts()).getOrElse(() => []), const [
          _vip,
        ]);
        expect(remote.calls, 1);
      },
    );

    test(
      'offline without a cached catalog explains that internet is needed',
      () async {
        await store.setOfflineMode(true);
        final result = await ProductsRepository(
          _Products(),
          store,
          local,
        ).listProducts();
        expect(result.fold((f) => f, (_) => null), isA<CacheFailure>());
      },
    );

    test('falls back to the cache when an online fetch fails', () async {
      final remote = _Products();
      final repository = ProductsRepository(remote, store, local);
      await repository.listProducts();
      remote.error = ServerException(message: 'down', statusCode: 502);

      expect((await repository.listProducts()).isRight(), isTrue);
    });
  });

  group('PosSaleRepository discounts', () {
    test('cached online, served offline', () async {
      final remote = _Sales();
      final repository = PosSaleRepository(remote, store);
      await repository.fetchDiscounts();
      await store.setOfflineMode(true);
      remote.error = NoInternetException();

      expect((await repository.fetchDiscounts()).getOrElse(() => []), const [
        _flyer,
      ]);
    });
  });

  group('ShiftRepository', () {
    ShiftRepository build(_Shifts remote) => ShiftRepository(
      remote,
      store,
      local,
      newId: () => 'off-shift-1',
      clock: () => DateTime.utc(2026, 9, 23, 9),
    );

    test('offline, the cached open shift keeps the till open', () async {
      final remote = _Shifts();
      final repository = build(remote);
      await repository.getCurrentShift();
      await store.setOfflineMode(true);

      final result = await repository.getCurrentShift();

      expect(result.getOrElse(() => throw 'no shift').id, 'shift-1');
      expect(remote.calls, 1);
    });

    test('offline with no shift: opening one creates it locally', () async {
      await store.setOfflineMode(true);
      final repository = build(_Shifts());

      final before = await repository.getCurrentShift();
      expect(
        before.fold((f) => (f as ServerFailure).code, (_) => null),
        'SHIFT_NOT_OPEN',
      );

      final opened = (await repository.openShift(
        openingCashUzs: 20000,
      )).getOrElse(() => throw 'x');
      expect(opened.id, 'offline:off-shift-1');
      expect(store.offlineShift('cashier-1')!.openingCashUzs, 20000);
      expect(
        (await repository.getCurrentShift()).getOrElse(() => throw 'x').id,
        'offline:off-shift-1',
      );
    });

    test(
      'offline, a synced offline shift (kept only as a mapping) is never the '
      'open shift',
      () async {
        await store.saveOfflineShift(
          OfflineShift(
            offlineRequestId: 'off-1',
            cashierId: 'cashier-1',
            openedAt: DateTime.utc(2026, 9, 22, 8),
            serverShiftId: 'srv-old',
          ),
        );
        await store.setOfflineMode(true);

        final result = await build(_Shifts()).getCurrentShift();

        expect(
          result.fold((f) => (f as ServerFailure).code, (s) => s.id),
          'SHIFT_NOT_OPEN',
        );
      },
    );

    test('opening a new offline shift keeps failed sales of the old synced one '
        'pointed at its server shift', () async {
      await store.saveOfflineShift(
        OfflineShift(
          offlineRequestId: 'off-old',
          cashierId: 'cashier-1',
          openedAt: DateTime.utc(2026, 9, 22, 8),
          serverShiftId: 'srv-old',
        ),
      );
      await store.putSale(
        OfflineSale(
          offlineRequestId: 'a',
          cashierId: 'cashier-1',
          createdAt: DateTime.utc(2026, 9, 22, 10),
          shiftOfflineRequestId: 'off-old',
          lines: const [
            OfflineSaleLine(
              productId: 'vip',
              name: 'VIP',
              priceUzs: 75000,
              qty: 1,
            ),
          ],
          cashUzs: 75000,
          cardUzs: 0,
        ).markFailed(code: 'X', message: 'bad', at: DateTime.utc(2026)),
      );
      await store.setOfflineMode(true);

      await build(_Shifts()).openShift();

      expect(store.offlineShift('cashier-1')!.offlineRequestId, 'off-shift-1');
      final sale = store.sales().single;
      expect(sale.isFailed, isTrue);
      expect(sale.toSyncJson()['shiftId'], 'srv-old');
      expect(sale.toSyncJson().containsKey('shiftOfflineRequestId'), isFalse);
    });

    test('a shift cannot be closed offline', () async {
      await store.setOfflineMode(true);
      final result = await build(_Shifts()).closeShift();
      expect(
        result.fold((f) => (f as ServerFailure).code, (_) => null),
        'OFFLINE_UNAVAILABLE',
      );
    });

    test(
      'closing is blocked while sales still wait to sync, allowed with only failed ones',
      () async {
        final remote = _Shifts();
        final repository = build(remote);
        final sale = OfflineSale(
          offlineRequestId: 'a',
          cashierId: 'cashier-1',
          createdAt: DateTime.utc(2026, 9, 23, 10),
          shiftId: 'shift-1',
          lines: const [
            OfflineSaleLine(
              productId: 'vip',
              name: 'VIP',
              priceUzs: 75000,
              qty: 1,
            ),
          ],
          cashUzs: 75000,
          cardUzs: 0,
        );
        await store.putSale(sale);

        final blocked = await repository.closeShift();
        expect(
          blocked.fold((f) => (f as ServerFailure).code, (_) => null),
          'OFFLINE_SALES_PENDING',
        );

        await store.putSale(
          sale.markFailed(code: 'X', message: 'bad', at: DateTime.utc(2026)),
        );
        await repository.getCurrentShift();
        final closed = await repository.closeShift();
        expect(closed.isRight(), isTrue);
        expect(store.cachedShift('cashier-1'), isNull);
      },
    );

    test('online, "no open shift" clears a stale cached shift', () async {
      final remote = _Shifts();
      final repository = build(remote);
      await repository.getCurrentShift();
      remote.error = ServerException(
        message: 'Smena ochilmagan',
        code: 'SHIFT_NOT_OPEN',
      );

      await repository.getCurrentShift();

      expect(store.cachedShift('cashier-1'), isNull);
    });

    test(
      'a fully synced offline shift is forgotten when the shift closes',
      () async {
        await store.saveOfflineShift(
          OfflineShift(
            offlineRequestId: 'off-1',
            cashierId: 'cashier-1',
            openedAt: DateTime.utc(2026, 9, 23, 8),
            serverShiftId: 'shift-1',
          ),
        );
        await build(_Shifts()).closeShift();
        expect(store.offlineShift('cashier-1'), isNull);
      },
    );

    test(
      'an invalid opening cash amount is rejected offline and saves nothing',
      () async {
        await store.setOfflineMode(true);
        final repository = build(_Shifts());

        final negative = await repository.openShift(openingCashUzs: -1);
        expect(negative.fold((f) => f, (_) => null), isA<CacheFailure>());
        expect(store.offlineShift('cashier-1'), isNull);

        final tooLarge = await repository.openShift(
          openingCashUzs: 10000000001,
        );
        expect(tooLarge.fold((f) => f, (_) => null), isA<CacheFailure>());
        expect(store.offlineShift('cashier-1'), isNull);
      },
    );
  });
}
