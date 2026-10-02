import 'dart:async';
import 'dart:typed_data';

import 'package:cashier_app/core/connectivity/connectivity_monitor.dart';
import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/features/offline/application/offline_sync_service.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:cashier_app/features/offline/presentation/pages/unsynced_sales_page.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late OfflineStore store;
  late StreamController<ConnectivityEvent> events;
  late List<Set<String>?> retried;

  setUp(() async {
    store = OfflineStore(
      await Hive.openBox<dynamic>(OfflineStore.boxName, bytes: Uint8List(0)),
    );
    events = StreamController<ConnectivityEvent>.broadcast();
    retried = [];
    await store.putSale(
      OfflineSale(
        offlineRequestId: '35b4fb47-a84f-483f-b73c-44ff6a04be23',
        cashierId: 'cashier-1',
        createdAt: DateTime.utc(2026, 9, 23, 10, 15),
        shiftId: 'shift-1',
        lines: const [
          OfflineSaleLine(
            productId: 'vip',
            name: 'VIP',
            priceUzs: 75000,
            qty: 2,
          ),
        ],
        cashUzs: 150000,
        cardUzs: 0,
      ).markFailed(
        code: 'PRODUCT_NOT_FOUND',
        message: 'Mahsulot topilmadi',
        at: DateTime.utc(2026, 9, 23, 12),
      ),
    );
  });

  tearDown(() async {
    await events.close();
    await Hive.close();
  });

  Future<AppModeCubit> pump(
    WidgetTester tester, {
    required bool offline,
  }) async {
    await store.setOfflineMode(offline);
    final cubit = AppModeCubit(
      connectivity: events.stream,
      checkNow: () async => true,
      store: store,
      sync: ({Set<String>? onlyIds, bool includeFailed = false}) async {
        retried.add(onlyIds);
        return SyncReport.empty;
      },
      currentCashierId: () => 'cashier-1',
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        // GlobalMaterialLocalizations.delegate also loads intl's date-symbol
        // data (see lib/app.dart) — OfflineSaleTile formats dates with
        // DateFormat, which throws LocaleDataException without it.
        localizationsDelegates: const [
          AppLocalization.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: UnsyncedSalesPage(store: store, cashierId: 'cashier-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('shows the failed sale with its reason and support code', (
    tester,
  ) async {
    await pump(tester, offline: false);

    expect(find.text('Mahsulot topilmadi'), findsOneWidget);
    expect(find.textContaining('35b4fb47'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
  });

  testWidgets('retry resends that sale when online', (tester) async {
    await pump(tester, offline: false);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(retried, [
      {'35b4fb47-a84f-483f-b73c-44ff6a04be23'},
    ]);
  });

  testWidgets('retry is disabled offline', (tester) async {
    await pump(tester, offline: true);

    // OutlinedButton.icon builds a private subclass, which find.byType misses.
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Retry'),
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Switch to online mode to resend'), findsOneWidget);
  });
}
