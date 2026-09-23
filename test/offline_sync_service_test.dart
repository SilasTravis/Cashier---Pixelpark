import 'dart:io';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/features/offline/application/offline_sync_service.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/data/offline_sync_remote_data_source.dart';
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:cashier_app/features/offline/domain/offline_shift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _FakeRemote implements OfflineSyncRemoteDataSource {
  final calls =
      <
        ({List<Map<String, dynamic>> shifts, List<Map<String, dynamic>> sales})
      >[];
  Object? throwOnCall;
  OfflineSyncItemResult Function(Map<String, dynamic> sale) saleResult =
      (sale) => OfflineSyncItemResult(
        offlineRequestId: sale['offlineRequestId'] as String,
        status: OfflineSyncStatus.created,
        serverId: 'srv-${sale['offlineRequestId']}',
      );

  @override
  Future<OfflineSyncResult> sync({
    required List<Map<String, dynamic>> shifts,
    required List<Map<String, dynamic>> sales,
  }) async {
    calls.add((shifts: shifts, sales: sales));
    if (throwOnCall != null) throw throwOnCall!;
    return OfflineSyncResult(
      shifts: [
        for (final shift in shifts)
          OfflineSyncItemResult(
            offlineRequestId: shift['offlineRequestId'] as String,
            status: OfflineSyncStatus.created,
            serverId: 'srv-shift',
          ),
      ],
      sales: [for (final sale in sales) saleResult(sale)],
    );
  }
}

OfflineSale _sale(
  String id, {
  String cashierId = 'cashier-1',
  String? shiftId = 'shift-1',
  String? shiftOfflineRequestId,
  int minute = 0,
}) => OfflineSale(
  offlineRequestId: id,
  cashierId: cashierId,
  createdAt: DateTime.utc(2026, 9, 23, 10).add(Duration(minutes: minute)),
  shiftId: shiftId,
  shiftOfflineRequestId: shiftOfflineRequestId,
  lines: const [
    OfflineSaleLine(productId: 'vip', name: 'VIP', priceUzs: 75000, qty: 1),
  ],
  cashUzs: 75000,
  cardUzs: 0,
);

void main() {
  late Directory temp;
  late Box<dynamic> box;
  late OfflineStore store;
  late _FakeRemote remote;
  late OfflineSyncService service;
  String? cashierId = 'cashier-1';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_offline_sync');
    Hive.init(temp.path);
    box = await Hive.openBox<dynamic>(OfflineStore.boxName);
    store = OfflineStore(box);
    remote = _FakeRemote();
    cashierId = 'cashier-1';
    service = OfflineSyncService(
      store,
      remote,
      () => cashierId,
      clock: () => DateTime.utc(2026, 9, 23, 12),
    );
  });

  tearDown(() async {
    await box.close();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test(
    'drops created and duplicate sales, keeps rejected ones as failed',
    () async {
      await store.putSale(_sale('a'));
      await store.putSale(_sale('b', minute: 1));
      await store.putSale(_sale('c', minute: 2));
      remote.saleResult = (sale) => switch (sale['offlineRequestId']) {
        'a' => const OfflineSyncItemResult(
          offlineRequestId: 'a',
          status: OfflineSyncStatus.created,
          serverId: 's1',
        ),
        'b' => const OfflineSyncItemResult(
          offlineRequestId: 'b',
          status: OfflineSyncStatus.duplicate,
          serverId: 's0',
        ),
        _ => const OfflineSyncItemResult(
          offlineRequestId: 'c',
          status: OfflineSyncStatus.rejected,
          code: 'PRODUCT_NOT_FOUND',
          message: 'Mahsulot topilmadi',
        ),
      };

      final report = await service.sync();

      expect(report.syncedCount, 2);
      expect(report.failed.single.offlineRequestId, 'c');
      expect(report.transportFailed, isFalse);
      final left = store.sales().single;
      expect(left.offlineRequestId, 'c');
      expect(left.isFailed, isTrue);
      expect(left.failureCode, 'PRODUCT_NOT_FOUND');
      expect(left.failureMessage, 'Mahsulot topilmadi');
      expect(left.attempts, 1);
    },
  );

  test('leaves everything pending when the request itself fails', () async {
    await store.putSale(_sale('a'));
    remote.throwOnCall = NoInternetException();

    final report = await service.sync();

    expect(report.transportFailed, isTrue);
    expect(store.sales().single.isFailed, isFalse);
  });

  test(
    'a server error on the whole request is a transport failure too',
    () async {
      await store.putSale(_sale('a'));
      remote.throwOnCall = ServerException(
        message: 'Server xatosi',
        statusCode: 500,
      );

      final report = await service.sync();

      expect(report.transportError, 'Server xatosi');
      expect(store.sales().single.status, OfflineSaleStatus.pending);
    },
  );

  test('sends the offline shift first, then refers to its server id', () async {
    await store.saveOfflineShift(
      OfflineShift(
        offlineRequestId: 'off-1',
        cashierId: 'cashier-1',
        openedAt: DateTime.utc(2026, 9, 23, 8),
      ),
    );
    await store.putSale(
      _sale('a', shiftId: null, shiftOfflineRequestId: 'off-1'),
    );
    remote.saleResult = (sale) => const OfflineSyncItemResult(
      offlineRequestId: 'a',
      status: OfflineSyncStatus.rejected,
      code: 'X',
      message: 'bad',
    );

    await service.sync();

    expect(remote.calls.single.shifts.single['offlineRequestId'], 'off-1');
    expect(store.offlineShift('cashier-1')!.serverShiftId, 'srv-shift');

    remote.saleResult = (sale) => const OfflineSyncItemResult(
      offlineRequestId: 'a',
      status: OfflineSyncStatus.created,
      serverId: 's1',
    );
    await service.sync(includeFailed: true);

    expect(remote.calls.last.shifts, isEmpty);
    expect(remote.calls.last.sales.single['shiftId'], 'srv-shift');
  });

  test('forgets the offline shift once nothing queued refers to it', () async {
    await store.saveOfflineShift(
      OfflineShift(
        offlineRequestId: 'off-1',
        cashierId: 'cashier-1',
        openedAt: DateTime.utc(2026, 9, 23, 8),
      ),
    );
    await store.putSale(
      _sale('a', shiftId: null, shiftOfflineRequestId: 'off-1'),
    );

    await service.sync();

    expect(store.sales(), isEmpty);
    expect(store.offlineShift('cashier-1'), isNull);
    expect(store.cachedShift('cashier-1')?.id, 'srv-shift');
  });

  test(
    'splits a long queue into batches of 200, shift only in the first',
    () async {
      await store.saveOfflineShift(
        OfflineShift(
          offlineRequestId: 'off-1',
          cashierId: 'cashier-1',
          openedAt: DateTime.utc(2026, 9, 23, 8),
        ),
      );
      for (var i = 0; i < 450; i++) {
        await store.putSale(_sale('s$i', minute: i));
      }

      final report = await service.sync();

      expect(remote.calls.map((c) => c.sales.length), [200, 200, 50]);
      expect(remote.calls.map((c) => c.shifts.length), [1, 0, 0]);
      expect(report.syncedCount, 450);
    },
  );

  test(
    'skips failed sales on the automatic sync, resends them on retry',
    () async {
      await store.putSale(
        _sale(
          'a',
        ).markFailed(code: 'X', message: 'bad', at: DateTime.utc(2026)),
      );
      await store.putSale(_sale('b', minute: 1));

      await service.sync();
      expect(remote.calls.single.sales.map((s) => s['offlineRequestId']), [
        'b',
      ]);

      await service.sync(onlyIds: {'a'}, includeFailed: true);
      expect(remote.calls.last.sales.map((s) => s['offlineRequestId']), ['a']);
    },
  );

  test("never sends another cashier's sales", () async {
    await store.putSale(_sale('mine'));
    await store.putSale(_sale('theirs', cashierId: 'cashier-2'));

    await service.sync();

    expect(remote.calls.single.sales.map((s) => s['offlineRequestId']), [
      'mine',
    ]);
    expect(store.sales().single.offlineRequestId, 'theirs');
  });

  test('does nothing when nobody is signed in or nothing is queued', () async {
    expect(await service.sync(), SyncReport.empty);
    cashierId = null;
    await store.putSale(_sale('a'));
    expect(await service.sync(), SyncReport.empty);
    expect(remote.calls, isEmpty);
  });

  test('concurrent sync calls share one run', () async {
    await store.putSale(_sale('a'));

    await Future.wait([service.sync(), service.sync()]);

    expect(remote.calls.length, 1);
  });
}
