import 'dart:async';
import 'dart:typed_data';

import 'package:cashier_app/core/connectivity/connectivity_monitor.dart';
import 'package:cashier_app/core/error/failure.dart';
import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/features/auth/domain/entities/cashier.dart';
import 'package:cashier_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:cashier_app/features/offline/application/offline_sync_service.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:cashier_app/features/settings/presentation/widgets/logout_button.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/injector_container.dart';
import 'package:cashier_app/router/app_navigator.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _FakeAuth implements AuthRepository {
  int logouts = 0;

  @override
  Future<void> logout() async => logouts++;

  @override
  Future<Either<Failure, AuthSession>> login({
    required String username,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, AuthSession>> getCurrentSession() =>
      throw UnimplementedError();
}

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
  late OfflineStore store;
  late StreamController<ConnectivityEvent> events;
  late _FakeAuth auth;

  setUp(() async {
    // In-memory box: real Hive file I/O inside testWidgets' FakeAsync zone
    // deadlocks (see global constraints).
    store = OfflineStore(
      await Hive.openBox<dynamic>(OfflineStore.boxName, bytes: Uint8List(0)),
    );
    events = StreamController<ConnectivityEvent>.broadcast();
    auth = _FakeAuth();
    sl.registerSingleton<AuthRepository>(auth);
  });

  tearDown(() async {
    await sl.unregister<AuthRepository>();
    await events.close();
    await Hive.close();
  });

  // The cubit is built inside the test body: a bloc created outside
  // testWidgets' FakeAsync zone delivers its states on real microtasks.
  Future<void> pump(WidgetTester tester) async {
    final cubit = AppModeCubit(
      connectivity: events.stream,
      checkNow: () async => true,
      store: store,
      sync: ({Set<String>? onlyIds, bool includeFailed = false}) async =>
          SyncReport.empty,
      currentCashierId: () => 'cashier-1',
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalization.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        locale: const Locale('en'),
        routes: {Routes.login: (_) => const Text('login screen')},
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: Center(child: LogoutButton())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pending sales block sign-out with a snackbar', (tester) async {
    await store.putSale(_sale('a'));
    await store.putSale(_sale('b', failed: true));
    await pump(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '1 sales are not synced. Sync them in online mode before signing out.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sign out anyway'), findsNothing);
    expect(auth.logouts, 0);
    expect(find.text('login screen'), findsNothing);
  });

  testWidgets(
    'only failed sales: confirm first; cancel stays, confirm leaves',
    (tester) async {
      await store.putSale(_sale('a', failed: true));
      await store.putSale(_sale('b', failed: true));
      await pump(tester);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '2 sales failed to sync. They stay saved on this till. '
          'Sign out anyway?',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(auth.logouts, 0);
      expect(find.text('login screen'), findsNothing);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out anyway'));
      await tester.pumpAndSettle();
      expect(auth.logouts, 1);
      expect(find.text('login screen'), findsOneWidget);
      // Failed sales are never deleted by signing out.
      expect(store.sales(), hasLength(2));
    },
  );

  testWidgets('nothing queued signs out straight away', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(auth.logouts, 1);
    expect(find.text('login screen'), findsOneWidget);
  });
}
