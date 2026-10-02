import 'dart:async';
import 'dart:typed_data';

import 'package:cashier_app/core/connectivity/connectivity_monitor.dart';
import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/core/offline/widgets/mode_prompt_host.dart';
import 'package:cashier_app/features/offline/application/offline_sync_service.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late OfflineStore store;
  late StreamController<ConnectivityEvent> events;
  late AppModeCubit cubit;

  AppModeCubit buildCubit() => AppModeCubit(
    connectivity: events.stream,
    checkNow: () async => true,
    store: store,
    sync: ({Set<String>? onlyIds, bool includeFailed = false}) async =>
        const SyncReport(syncedCount: 2),
    currentCashierId: () => 'cashier-1',
  );

  setUp(() async {
    // In-memory box: real Hive file I/O inside testWidgets' FakeAsync zone
    // deadlocks (see global constraints).
    store = OfflineStore(
      await Hive.openBox<dynamic>(OfflineStore.boxName, bytes: Uint8List(0)),
    );
    events = StreamController<ConnectivityEvent>.broadcast();
  });

  tearDown(() async {
    await events.close();
    await Hive.close();
  });

  // The cubit is built inside the test body, not setUp: a bloc created
  // outside testWidgets' FakeAsync zone delivers its states on real
  // microtasks, which pump() never flushes.
  Future<void> pump(WidgetTester tester) async {
    cubit = buildCubit();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalization.delegate],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        locale: const Locale('en'),
        home: BlocProvider.value(
          value: cubit,
          child: const ModePromptHost(child: Scaffold(body: Text('till'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an outage asks before going offline', (tester) async {
    await pump(tester);

    events.add(
      const ConnectivityEvent(reachable: false, fromUserRequest: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('No internet connection'), findsOneWidget);

    await tester.tap(find.text('Yes, go offline'));
    await tester.pumpAndSettle();
    expect(cubit.state.mode, AppMode.offline);
    expect(find.text('No internet connection'), findsNothing);
  });

  testWidgets('declining keeps the till online', (tester) async {
    await pump(tester);

    events.add(
      const ConnectivityEvent(reachable: false, fromUserRequest: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(cubit.state.mode, AppMode.online);
  });

  testWidgets(
    'a sync report that arrives while a confirm dialog is open is shown '
    'once the dialog closes',
    (tester) async {
      await pump(tester);

      events.add(
        const ConnectivityEvent(reachable: false, fromUserRequest: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('No internet connection'), findsOneWidget);

      // The internet comes back behind the dialog (the cubit drops the
      // prompt) and then the Unsynced page's Retry finishes: by the time the
      // cashier answers, neither the prompt nor the report changes again.
      events.add(const ConnectivityEvent(reachable: true));
      await tester.pumpAndSettle();
      expect(cubit.state.prompt, ModePrompt.none);
      await cubit.retry();
      await tester.pumpAndSettle();
      expect(cubit.state.lastReport, isNotNull);
      expect(find.text('2 sales synced, 0 failed.'), findsNothing);

      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(find.text('2 sales synced, 0 failed.'), findsOneWidget);
    },
  );

  testWidgets('back online: confirm, sync, then show the result', (
    tester,
  ) async {
    await store.setOfflineMode(true);
    await pump(tester);

    events.add(const ConnectivityEvent(reachable: true));
    await tester.pumpAndSettle();
    expect(find.text('Internet is back'), findsOneWidget);

    await tester.tap(find.text('Yes, sync'));
    await tester.pumpAndSettle();

    expect(cubit.state.mode, AppMode.online);
    expect(find.text('2 sales synced, 0 failed.'), findsOneWidget);
  });
}
