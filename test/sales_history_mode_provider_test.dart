import 'dart:async';
import 'dart:typed_data';

import 'package:cashier_app/core/connectivity/connectivity_monitor.dart';
import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/features/offline/application/offline_sync_service.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/products/data/products_remote_data_source.dart';
import 'package:cashier_app/features/products/data/products_repository_impl.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/sales_history/data/sales_history_remote_data_source.dart';
import 'package:cashier_app/features/sales_history/data/sales_history_repository.dart';
import 'package:cashier_app/features/sales_history/domain/sale_history.dart';
import 'package:cashier_app/features/sales_history/presentation/bloc/sales_history_bloc.dart';
import 'package:cashier_app/features/sales_history/presentation/pages/sales_history_page.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/injector_container.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _EmptySalesRemote extends SalesHistoryRemoteDataSource {
  _EmptySalesRemote() : super(Dio());

  @override
  Future<SalesHistoryPageData> list({
    SaleHistoryPeriod? period,
    DateTime? from,
    DateTime? to,
    String? productId,
    required int page,
    int limit = 100,
  }) async => const SalesHistoryPageData(items: [], total: 0);

  @override
  Future<SalesHistorySummary> summary({
    SaleHistoryPeriod? period,
    DateTime? from,
    DateTime? to,
    String? productId,
  }) async => const SalesHistorySummary(
    count: 0,
    totalUzs: 0,
    cashUzs: 0,
    cardUzs: 0,
    balanceUzs: 0,
    refundedUzs: 0,
  );
}

class _EmptyProductsRemote implements ProductsRemoteDataSource {
  @override
  Future<List<Product>> listProducts() async => const [];
}

/// The History tab reads [AppModeCubit] from context; lib/app.dart provides
/// it above MaterialApp. This mirrors that tree and proves both modes render.
void main() {
  late OfflineStore store;
  late LocalSource local;
  late StreamController<ConnectivityEvent> events;

  setUp(() async {
    store = OfflineStore(
      await Hive.openBox<dynamic>(OfflineStore.boxName, bytes: Uint8List(0)),
    );
    local = LocalSource(
      await Hive.openBox<dynamic>('cashier_app_box', bytes: Uint8List(0)),
    );
    events = StreamController<ConnectivityEvent>.broadcast();
    sl
      ..registerSingleton<OfflineStore>(store)
      ..registerSingleton<LocalSource>(local)
      ..registerFactory<SalesHistoryBloc>(
        () => SalesHistoryBloc(
          SalesHistoryRepository(_EmptySalesRemote()),
          ProductsRepository(_EmptyProductsRemote(), store, local),
        ),
      );
  });

  tearDown(() async {
    await sl.reset();
    await events.close();
    await Hive.close();
  });

  Future<void> pump(WidgetTester tester, {required bool offline}) async {
    await store.setOfflineMode(offline);
    final cubit = AppModeCubit(
      connectivity: events.stream,
      checkNow: () async => true,
      store: store,
      sync: ({Set<String>? onlyIds, bool includeFailed = false}) async =>
          SyncReport.empty,
      currentCashierId: () => 'cashier-1',
    );
    addTearDown(cubit.close);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider<AppModeCubit>.value(
        value: cubit,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalization.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalization.delegate.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(body: SalesHistoryPage(onOpenCustomer: (_) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('online: the History tab renders the server history', (
    tester,
  ) async {
    await pump(tester, offline: false);

    expect(tester.takeException(), isNull);
    final l10n = AppLocalization.current;
    expect(find.text(l10n.historyOfflineNotice), findsNothing);
    expect(find.text(l10n.historyDateRange), findsOneWidget);
  });

  testWidgets('offline: the History tab shows only the local queue', (
    tester,
  ) async {
    await pump(tester, offline: true);

    expect(tester.takeException(), isNull);
    final l10n = AppLocalization.current;
    expect(find.text(l10n.historyOfflineNotice), findsOneWidget);
    expect(find.text(l10n.historyDateRange), findsNothing);
  });
}
