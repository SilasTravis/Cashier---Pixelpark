import 'dart:async';
import 'dart:io';

import 'package:cashier_app/core/connectivity/connectivity_monitor.dart';
import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/features/offline/application/offline_sync_service.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _down = ConnectivityEvent(reachable: false);
const _downOnRequest = ConnectivityEvent(
  reachable: false,
  fromUserRequest: true,
);
const _up = ConnectivityEvent(reachable: true);

OfflineSale _sale(String id, {bool failed = false}) {
  final sale = OfflineSale(
    offlineRequestId: id,
    cashierId: 'cashier-1',
    createdAt: DateTime.utc(2026, 9, 23, 10),
    shiftId: 'shift-1',
    lines: const [
      OfflineSaleLine(productId: 'vip', name: 'VIP', priceUzs: 75000, qty: 1),
    ],
    cashUzs: 75000,
    cardUzs: 0,
  );
  return failed
      ? sale.markFailed(code: 'X', message: 'bad', at: DateTime.utc(2026))
      : sale;
}

void main() {
  late Directory temp;
  late Box<dynamic> box;
  late OfflineStore store;
  late StreamController<ConnectivityEvent> events;
  late DateTime now;
  late bool probeAnswer;
  late SyncReport nextReport;
  late List<({Set<String>? onlyIds, bool includeFailed})> syncCalls;

  AppModeCubit build() => AppModeCubit(
    connectivity: events.stream,
    checkNow: () async => probeAnswer,
    store: store,
    sync: ({Set<String>? onlyIds, bool includeFailed = false}) async {
      syncCalls.add((onlyIds: onlyIds, includeFailed: includeFailed));
      return nextReport;
    },
    currentCashierId: () => 'cashier-1',
    clock: () => now,
  );

  Future<void> send(ConnectivityEvent event) async {
    events.add(event);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_app_mode');
    Hive.init(temp.path);
    box = await Hive.openBox<dynamic>(OfflineStore.boxName);
    store = OfflineStore(box);
    events = StreamController<ConnectivityEvent>.broadcast();
    now = DateTime.utc(2026, 9, 23, 10);
    probeAnswer = true;
    nextReport = SyncReport.empty;
    syncCalls = [];
  });

  tearDown(() async {
    await events.close();
    await box.close();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('comes back offline after a restart during an outage', () async {
    await store.setOfflineMode(true);
    final cubit = build();
    addTearDown(cubit.close);
    expect(cubit.state.mode, AppMode.offline);
  });

  test(
    'an outage asks first; accepting switches to offline and persists it',
    () async {
      final cubit = build();
      addTearDown(cubit.close);

      await send(_down);
      expect(cubit.state.prompt, ModePrompt.goOffline);
      expect(cubit.state.mode, AppMode.online);

      await cubit.acceptOffline();
      expect(cubit.state.mode, AppMode.offline);
      expect(cubit.state.prompt, ModePrompt.none);
      expect(store.isOfflineMode, isTrue);
    },
  );

  test('after declining, only a failed real request asks again', () async {
    final cubit = build();
    addTearDown(cubit.close);

    await send(_down);
    cubit.declineOffline();
    expect(cubit.state.prompt, ModePrompt.none);

    await send(_down);
    expect(cubit.state.prompt, ModePrompt.none);

    await send(_downOnRequest);
    expect(cubit.state.prompt, ModePrompt.goOffline);
  });

  test(
    'the internet coming back clears a decline and a stale offline prompt',
    () async {
      final cubit = build();
      addTearDown(cubit.close);

      await send(_down);
      await send(_up);
      expect(cubit.state.prompt, ModePrompt.none);

      await send(_down);
      cubit.declineOffline();
      await send(_up);
      await send(_down);
      expect(cubit.state.prompt, ModePrompt.goOffline);
    },
  );

  test(
    'offline: reachability offers to go online, "later" holds it for 5 minutes',
    () async {
      await store.setOfflineMode(true);
      final cubit = build();
      addTearDown(cubit.close);

      await send(_up);
      expect(cubit.state.prompt, ModePrompt.goOnline);

      cubit.postponeOnline();
      now = now.add(const Duration(minutes: 4));
      await send(_up);
      expect(cubit.state.prompt, ModePrompt.none);

      now = now.add(const Duration(minutes: 2));
      await send(_up);
      expect(cubit.state.prompt, ModePrompt.goOnline);
    },
  );

  test(
    '"check online" asks at once, even inside the postpone window',
    () async {
      await store.setOfflineMode(true);
      final cubit = build();
      addTearDown(cubit.close);

      await send(_up);
      cubit.postponeOnline();

      expect(await cubit.checkOnlineNow(), isTrue);
      expect(cubit.state.prompt, ModePrompt.goOnline);
    },
  );

  test(
    '"check online" with no internet reports false and asks nothing',
    () async {
      await store.setOfflineMode(true);
      probeAnswer = false;
      final cubit = build();
      addTearDown(cubit.close);

      expect(await cubit.checkOnlineNow(), isFalse);
      expect(cubit.state.prompt, ModePrompt.none);
    },
  );

  test('going online syncs, then switches and remembers the report', () async {
    await store.setOfflineMode(true);
    nextReport = const SyncReport(syncedCount: 3);
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.acceptOnline();

    expect(syncCalls.single.includeFailed, isFalse);
    expect(cubit.state.mode, AppMode.online);
    expect(cubit.state.lastReport, nextReport);
    expect(store.isOfflineMode, isFalse);

    cubit.reportShown();
    expect(cubit.state.lastReport, isNull);
  });

  test(
    'a sync that cannot reach the server leaves the terminal offline',
    () async {
      await store.setOfflineMode(true);
      nextReport = const SyncReport(
        transportError: "Internet aloqasi yo'q",
        serverReachable: false,
      );
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.acceptOnline();

      expect(cubit.state.mode, AppMode.offline);
      expect(cubit.state.lastReport?.transportFailed, isTrue);
      expect(store.isOfflineMode, isTrue);

      await send(_up); // postponed after the failed attempt
      expect(cubit.state.prompt, ModePrompt.none);
    },
  );

  test('a sync the server answered with an error still goes online and keeps '
      'the report', () async {
    await store.setOfflineMode(true);
    await store.putSale(_sale('a'));
    nextReport = const SyncReport(transportError: 'Internal server error');
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.acceptOnline();

    expect(cubit.state.mode, AppMode.online);
    expect(store.isOfflineMode, isFalse);
    expect(cubit.state.lastReport, nextReport);
    expect(cubit.state.lastReport?.serverReachable, isTrue);
    // The sale is untouched and still pending; the Unsynced tab shows it.
    expect(store.sales().single.isFailed, isFalse);
    expect(cubit.state.pendingCount, 1);
  });

  test('retry resends failed sales too, and only online', () async {
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.retry(ids: {'a'});
    expect(syncCalls.single.onlyIds, {'a'});
    expect(syncCalls.single.includeFailed, isTrue);

    await cubit.acceptOffline();
    await cubit.retry();
    expect(syncCalls, hasLength(1));
  });

  test('tracks pending and failed counts from the store', () async {
    final cubit = build();
    addTearDown(cubit.close);

    await store.putSale(_sale('a'));
    await store.putSale(_sale('b', failed: true));

    expect(cubit.state.pendingCount, 1);
    expect(cubit.state.failedCount, 1);
    expect(cubit.state.queuedCount, 2);
  });
}
