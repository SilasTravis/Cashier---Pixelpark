import 'dart:convert';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/features/market/data/market_repository.dart';
import 'package:cashier_app/features/market/domain/market_order.dart';
import 'package:cashier_app/features/market/presentation/bloc/market_incoming_cubit.dart';
import 'package:cashier_app/features/market/presentation/bloc/market_pickup_cubit.dart';
import 'package:cashier_app/features/market/presentation/pages/market_page.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/injector_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A backend `toOrderResponse` body (staff audience) — field for field.
Map<String, dynamic> _orderJson({
  String id = 'o1',
  String status = 'at_branch',
}) => {
  'id': id,
  'checkoutId': '3f2a9c1e-7b44-4d2a-9e1f-0c5b6a7d8e9f',
  'status': status,
  'seller': {'id': 's1', 'shopName': 'Toys Bazaar', 'logoUrl': null},
  'branch': {'id': 'b1', 'name': 'Yunusobod', 'address': null},
  'pickupCode': '482913',
  'customer': {'name': 'Aziza', 'phone': '+998901234567'},
  'itemsTotalUzs': 185000,
  'commissionUzs': 18500,
  'cancelReason': null,
  'cancelledBy': null,
  'canCancel': true,
  'createdAt': '2026-10-01T09:30:00.000Z',
  'items': [
    {
      'id': 'i1',
      'productId': 'p1',
      'variantId': 'v1',
      'productName': 'Lego Duplo',
      'variantLabel': 'Pushti · M',
      'imageUrl': 'https://cdn/x.png',
      'unitPriceUzs': 60000,
      'quantity': 2,
      'lineTotalUzs': 120000,
      'reviewed': false,
    },
    {
      'id': 'i2',
      'productId': 'p2',
      'variantId': 'v2',
      'productName': 'Puzzle',
      'variantLabel': '',
      'imageUrl': null,
      'unitPriceUzs': 65000,
      'quantity': 1,
      'lineTotalUzs': 65000,
      'reviewed': false,
    },
  ],
  'events': [
    {
      'status': 'placed',
      'actorType': 'user',
      'note': null,
      'at': '2026-10-01T09:30:00.000Z',
    },
  ],
};

/// Answers each request by path; records what was called.
class _RoutedAdapter implements HttpClientAdapter {
  _RoutedAdapter(this.routes);
  final Map<String, (int, Object)> routes;
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    final (status, body) = routes[key] ?? (500, {});
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

MarketRepository _repo(_RoutedAdapter adapter) =>
    MarketRepository(Dio()..httpClientAdapter = adapter);

void main() {
  group('MarketOrder.fromJson', () {
    test('parses the backend order shape', () {
      final order = MarketOrder.fromJson(_orderJson());
      expect(order.id, 'o1');
      expect(order.status, MarketOrderStatus.atBranch);
      expect(order.shopName, 'Toys Bazaar');
      expect(order.branchName, 'Yunusobod');
      expect(order.customerName, 'Aziza');
      expect(order.customerPhone, '+998901234567');
      expect(order.pickupCode, '482913');
      expect(order.itemsTotalUzs, 185000);
      expect(order.items, hasLength(2));
      expect(order.items.first.variantLabel, 'Pushti · M');
      expect(order.items.first.lineTotalUzs, 120000);
      expect(order.itemCount, 3);
      expect(order.createdAt, DateTime.utc(2026, 10, 1, 9, 30).toLocal());
    });

    test('order number = first 8 chars of the checkout id, uppercased', () {
      expect(MarketOrder.fromJson(_orderJson()).orderNumber, '3F2A9C1E');
    });

    test('the incoming list: null pickup code; unknown status tolerated', () {
      final json = _orderJson(status: 'teleported')..['pickupCode'] = null;
      final order = MarketOrder.fromJson(json);
      expect(order.pickupCode, isNull);
      expect(order.status, MarketOrderStatus.unknown);
    });

    test('every wire status maps', () {
      for (final (wire, status) in [
        ('placed', MarketOrderStatus.placed),
        ('confirmed', MarketOrderStatus.confirmed),
        ('handed_over', MarketOrderStatus.handedOver),
        ('at_branch', MarketOrderStatus.atBranch),
        ('picked_up', MarketOrderStatus.pickedUp),
        ('cancelled', MarketOrderStatus.cancelled),
      ]) {
        expect(MarketOrderStatus.parse(wire), status);
      }
    });
  });

  group('normalizePickupCode', () {
    test('keeps exactly 6 digits from a scan or typing', () {
      expect(normalizePickupCode('482913'), '482913');
      expect(normalizePickupCode(' 482 913\r\n'), '482913');
      expect(normalizePickupCode('\t482913'), '482913');
    });

    test('anything else is refused', () {
      expect(normalizePickupCode('48291'), isNull);
      expect(normalizePickupCode('4829130'), isNull);
      expect(normalizePickupCode('abc'), isNull);
      expect(normalizePickupCode(''), isNull);
    });
  });

  group('MarketPickupCubit', () {
    test('a malformed code makes no request', () async {
      final adapter = _RoutedAdapter({});
      final cubit = MarketPickupCubit(_repo(adapter));
      await cubit.lookup('123');
      expect(cubit.state.errorCode, marketCodeInvalid);
      expect(adapter.calls, isEmpty);
    });

    test('not found surfaces the server message', () async {
      final adapter = _RoutedAdapter({
        'GET /v1/pos/market/pickups/482913': (
          404,
          {
            'statusCode': 404,
            'code': 'MARKET_PICKUP_NOT_FOUND',
            'message': {'uz': 'Topilmadi', 'ru': 'Нет', 'en': 'None'},
          },
        ),
      });
      final cubit = MarketPickupCubit(_repo(adapter));
      await cubit.lookup('482913');
      expect(cubit.state.errorCode, 'MARKET_PICKUP_NOT_FOUND');
      expect(cubit.state.errorMessage, 'Topilmadi');
      expect(cubit.state.orders, isEmpty);
    });

    test('receive, then hand over the at-branch orders', () async {
      final adapter = _RoutedAdapter({
        'GET /v1/pos/market/pickups/482913': (
          200,
          [
            _orderJson(id: 'o1', status: 'handed_over'),
            _orderJson(id: 'o2', status: 'handed_over'),
          ],
        ),
        'POST /v1/pos/market/orders/o1/receive': (
          200,
          _orderJson(id: 'o1', status: 'at_branch'),
        ),
        'POST /v1/pos/market/pickups/482913/hand-over': (
          200,
          [_orderJson(id: 'o1', status: 'picked_up')],
        ),
      });
      final cubit = MarketPickupCubit(_repo(adapter));

      await cubit.lookup('482913');
      expect(cubit.state.canHandOver, isFalse);
      expect(cubit.state.hasUnreceived, isTrue);

      await cubit.receive('o1');
      expect(cubit.state.orders.first.status, MarketOrderStatus.atBranch);
      expect(cubit.state.canHandOver, isTrue);

      await cubit.handOver();
      expect(cubit.state.handed.single.id, 'o1');
      // o2 was never received, so it stays on screen.
      expect(cubit.state.orders.single.id, 'o2');
      expect(cubit.state.hasError, isFalse);
    });

    test('a failed hand-over keeps the orders and shows the error', () async {
      final adapter = _RoutedAdapter({
        'GET /v1/pos/market/pickups/482913': (200, [_orderJson()]),
      });
      final cubit = MarketPickupCubit(_repo(adapter));
      await cubit.lookup('482913');
      await cubit.handOver();
      expect(cubit.state.orders, hasLength(1));
      expect(cubit.state.handingOver, isFalse);
      expect(cubit.state.hasError, isTrue);
    });
  });

  test('repository errors become ServerException', () async {
    final repo = _repo(
      _RoutedAdapter({
        'GET /v1/pos/market/incoming': (
          401,
          {
            'statusCode': 401,
            'code': 'UNAUTHORIZED',
            'message': {'uz': 'Kirish kerak'},
          },
        ),
      }),
    );
    expect(
      repo.incoming(),
      throwsA(
        isA<ServerException>().having((e) => e.code, 'code', 'UNAUTHORIZED'),
      ),
    );
  });

  group('MarketPage', () {
    tearDown(() => sl.reset());

    testWidgets('a scan + Enter shows the order; Topshirildi hands it over', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final adapter = _RoutedAdapter({
        'GET /v1/pos/market/incoming': (200, <Object>[]),
        'GET /v1/pos/market/pickups/482913': (200, [_orderJson()]),
        'POST /v1/pos/market/pickups/482913/hand-over': (
          200,
          [_orderJson(status: 'picked_up')],
        ),
      });
      final repo = _repo(adapter);
      sl.registerFactory(() => MarketPickupCubit(repo));
      sl.registerFactory(() => MarketIncomingCubit(repo));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalization.delegate],
          supportedLocales: AppLocalization.delegate.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: MarketPage()),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalization.current;

      // The scanner gun types the digits into the focused field + Enter.
      await tester.enterText(find.byType(TextField), '482913');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Aziza'), findsWidgets);
      expect(find.text('Toys Bazaar'), findsOneWidget);
      expect(find.text(l10n.marketOrderNumber('3F2A9C1E')), findsWidgets);
      expect(find.text('×2'), findsOneWidget);

      await tester.tap(find.text(l10n.marketHandOver));
      await tester.pumpAndSettle();

      expect(find.text(l10n.marketHandedTitle), findsOneWidget);
      expect(
        adapter.calls,
        contains('POST /v1/pos/market/pickups/482913/hand-over'),
      );
    });

    testWidgets('a Tab suffix from the scanner submits too', (tester) async {
      final adapter = _RoutedAdapter({
        'GET /v1/pos/market/incoming': (200, <Object>[]),
        'GET /v1/pos/market/pickups/482913': (200, [_orderJson()]),
      });
      final repo = _repo(adapter);
      sl.registerFactory(() => MarketPickupCubit(repo));
      sl.registerFactory(() => MarketIncomingCubit(repo));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalization.delegate],
          supportedLocales: AppLocalization.delegate.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: MarketPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '482913');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(adapter.calls, contains('GET /v1/pos/market/pickups/482913'));
    });
  });
}
