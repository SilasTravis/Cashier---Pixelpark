import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/kids_plan.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_detail_panel.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';

/// Canned-response Dio adapter: records the last request and answers every
/// call with [payload].
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.payload);

  final Object payload;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FakeRemote implements PosAccountRemoteDataSource {
  @override
  Future<List<KidsPlan>> listPlans() async => const [
    KidsPlan(
      key: 'standard',
      name: 'Standart',
      kind: KidsPlanKind.perMinuteTiers,
      firstMinuteUzs: 1000,
      secondMinuteUzs: 1000,
      extraMinuteUzs: 1000,
      flatUzs: null,
    ),
    KidsPlan(
      key: 'vip',
      name: 'VIP',
      kind: KidsPlanKind.flatDay,
      firstMinuteUzs: null,
      secondMinuteUzs: null,
      extraMinuteUzs: null,
      flatUzs: 75000,
    ),
  ];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => const [];

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  Future<List<Discount>> fetchDiscounts({
    DiscountScope scope = DiscountScope.goods,
  }) async => scope == DiscountScope.entry
      ? const [
          Discount(
            id: 'disc-free',
            name: 'Nogiron bola',
            kind: DiscountKind.percent,
            value: 100,
            scope: DiscountScope.entry,
          ),
          Discount(
            id: 'disc-partial',
            name: 'Flayer 30%',
            kind: DiscountKind.percent,
            value: 30,
            scope: DiscountScope.entry,
          ),
        ]
      : const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<PosAccountBloc> _pumpPanel(WidgetTester tester) async {
  // The panel is a desktop two-column layout — give it desktop room.
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final bloc = PosAccountBloc(PosAccountRepository(_FakeRemote()))
    ..add(const PosAccountPlansRequested())
    ..add(const PosAccountDiscountsRequested(scope: DiscountScope.entry))
    ..add(
      PosAccountCustomerSelected(
        Customer(
          id: 7,
          phoneNumber: '+998901234567',
          firstName: 'Dil',
          lastName: null,
          balance: 0,
          children: [
            Child(
              id: 'child-1',
              firstName: 'Aziza',
              lastName: null,
              birthDate: DateTime(2018, 1, 1),
            ),
          ],
        ),
      ),
    );
  addTearDown(bloc.close);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalization.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalization.delegate.supportedLocales,
      home: BlocProvider.value(
        value: bloc,
        child: const Scaffold(
          body: SingleChildScrollView(child: CustomerDetailPanel()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return bloc;
}

void main() {
  group('data source', () {
    test(
      'checkout sends entryDiscounts + companions and parses HAMROH passes',
      () async {
        final adapter = _FakeAdapter({
          'entries': [],
          'failures': [],
          'conflicts': [],
          'companionPasses': [
            {'code': 'HAMROHCODE12', 'expiresAt': '2026-08-19T17:00:00.000Z'},
          ],
          'balance': 5000,
        });
        final dio = Dio(BaseOptions(baseUrl: 'http://x'))
          ..httpClientAdapter = adapter;
        final source = PosAccountRemoteDataSourceImpl(dio);

        final result = await source.planEntryCheckout(
          customerId: 7,
          planKey: 'standard',
          childIds: const ['child-1'],
          products: const [],
          cashUzs: 20000,
          cardUzs: 0,
          entryDiscounts: const {'child-1': 'disc-free'},
          companions: 2,
        );

        final body = adapter.lastRequest!.data as Map<String, dynamic>;
        expect(body['entryDiscounts'], [
          {'childId': 'child-1', 'discountId': 'disc-free'},
        ]);
        expect(body['companions'], 2);
        expect(result.companionPasses, hasLength(1));
        expect(result.companionPasses.first.code, 'HAMROHCODE12');
      },
    );

    test(
      'unused entry-discount/companion fields are omitted for older backends',
      () async {
        final adapter = _FakeAdapter({'entries': [], 'failures': []});
        final dio = Dio(BaseOptions(baseUrl: 'http://x'))
          ..httpClientAdapter = adapter;
        final source = PosAccountRemoteDataSourceImpl(dio);

        final result = await source.planEntryCheckout(
          customerId: 7,
          planKey: 'standard',
          childIds: const ['child-1'],
          products: const [],
          cashUzs: 0,
          cardUzs: 0,
        );

        final body = adapter.lastRequest!.data as Map<String, dynamic>;
        expect(body.containsKey('entryDiscounts'), isFalse);
        expect(body.containsKey('companions'), isFalse);
        expect(result.companionPasses, isEmpty);
      },
    );

    test('fetchCompanionPriceUzs reads the server-owned price', () async {
      final adapter = _FakeAdapter({'companionPriceUzs': 12000});
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;
      final source = PosAccountRemoteDataSourceImpl(dio);

      expect(await source.fetchCompanionPriceUzs(), 12000);
      expect(adapter.lastRequest!.path, '/v1/pos/config');
    });
  });

  group('panel', () {
    testWidgets('cashier can pick an entry discount from the 3-dots menu', (
      tester,
    ) async {
      await _pumpPanel(tester);

      await tester.tap(find.byTooltip('Chegirma'));
      await tester.pumpAndSettle();

      final option = find.text('Nogiron bola (100%)');
      expect(option, findsOneWidget);
      await tester.tap(option);
      await tester.pumpAndSettle();

      expect(find.text('Chegirma: Nogiron bola'), findsOneWidget);
    });

    testWidgets('a 100%-off entry discount zeroes the VIP charge', (
      tester,
    ) async {
      await _pumpPanel(tester);

      // Child + VIP: 75 000 required on a zero balance.
      await tester.tap(find.text('QR'));
      await tester.pump();
      await tester.tap(find.text('VIP'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '75000'), findsOneWidget);

      // Pick the 100%-off entry discount from the row's 3-dots menu.
      await tester.tap(find.byTooltip('Chegirma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nogiron bola (100%)'));
      await tester.pumpAndSettle();

      expect(find.text('Chegirma: Nogiron bola'), findsOneWidget);
      // Nothing to pay any more — the payment field is gone.
      expect(find.widgetWithText(TextField, '75000'), findsNothing);
      expect(find.text('Kirish (1)'), findsOneWidget);
    });

    testWidgets('a partial entry discount only reduces the VIP charge', (
      tester,
    ) async {
      await _pumpPanel(tester);

      await tester.tap(find.text('QR'));
      await tester.pump();
      await tester.tap(find.text('VIP'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '75000'), findsOneWidget);

      await tester.tap(find.byTooltip('Chegirma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flayer 30% (30%)'));
      await tester.pumpAndSettle();

      expect(find.text('Chegirma: Flayer 30%'), findsOneWidget);
      // 75 000 * 70% = 52 500 — still due, just discounted.
      expect(find.widgetWithText(TextField, '52500'), findsOneWidget);
    });

    testWidgets('each HAMROH companion adds its price to the required total', (
      tester,
    ) async {
      await _pumpPanel(tester);

      await tester.tap(find.text('QR'));
      await tester.pump();
      await tester.tap(find.text('Standart'));
      await tester.pumpAndSettle();

      final hamrohRow = find
          .ancestor(of: find.text('HAMROH QR'), matching: find.byType(Row))
          .first;
      await tester.tap(
        find.descendant(
          of: hamrohRow,
          matching: find.byIcon(PhosphorIconsRegular.plus),
        ),
      );
      await tester.pumpAndSettle();

      // One companion at the default 10 000 price, zero balance → required.
      expect(find.widgetWithText(TextField, '10000'), findsOneWidget);
    });
  });
}
