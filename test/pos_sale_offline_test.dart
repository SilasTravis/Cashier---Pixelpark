import 'dart:io';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/features/offline/application/offline_checkout.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:cashier_app/features/pos_sale/data/pos_sale_remote_data_source.dart';
import 'package:cashier_app/features/pos_sale/data/pos_sale_repository_impl.dart';
import 'package:cashier_app/features/pos_sale/domain/cart_line.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';
import 'package:cashier_app/features/pos_sale/domain/sale_receipt.dart';
import 'package:cashier_app/features/pos_sale/presentation/bloc/pos_sale_bloc.dart';
import 'package:cashier_app/features/products/data/products_remote_data_source.dart';
import 'package:cashier_app/features/products/data/products_repository_impl.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _popcorn = Product(
  id: 'popcorn',
  name: 'Popkorn',
  priceUzs: 12000,
  category: 'Gazak',
  icon: 'ph-popcorn',
);
const _vip = Product(
  id: 'vip',
  name: 'VIP',
  priceUzs: 75000,
  category: 'Tariflar',
  icon: 'ph-crown',
  offlineOnly: true,
);

class _Products extends ProductsRemoteDataSourceImpl {
  _Products() : super(Dio());
  @override
  Future<List<Product>> listProducts() async => const [_popcorn, _vip];
}

class _Sales extends PosSaleRemoteDataSourceImpl {
  _Sales() : super(Dio());
  int checkouts = 0;
  @override
  Future<List<Discount>> fetchDiscounts() async => const [];
  @override
  Future<SaleReceipt> checkout({
    required List<CheckoutLine> lines,
    required int cashUzs,
    required int cardUzs,
    String? discountId,
  }) async {
    checkouts++;
    throw UnimplementedError();
  }
}

/// A malformed response body: `SaleReceipt.fromJson`/`ServerException.fromJson`
/// throwing a `FormatException`/`TypeError` that `PosSaleRepository._call`
/// doesn't catch.
class _MalformedResponseSales extends PosSaleRemoteDataSourceImpl {
  _MalformedResponseSales() : super(Dio());
  int calls = 0;
  @override
  Future<List<Discount>> fetchDiscounts() async => const [];
  @override
  Future<SaleReceipt> checkout({
    required List<CheckoutLine> lines,
    required int cashUzs,
    required int cardUzs,
    String? discountId,
  }) async {
    calls++;
    throw const FormatException('unexpected character');
  }
}

/// The POST timed out / lost the connection: the server may or may not have
/// saved the sale.
class _LostConnectionSales extends PosSaleRemoteDataSourceImpl {
  _LostConnectionSales() : super(Dio());
  int calls = 0;
  @override
  Future<List<Discount>> fetchDiscounts() async => const [];
  @override
  Future<SaleReceipt> checkout({
    required List<CheckoutLine> lines,
    required int cashUzs,
    required int cardUzs,
    String? discountId,
  }) async {
    calls++;
    throw NoInternetException();
  }
}

/// `record` succeeds (the sale IS saved) but building the receipt throws.
class _BadReceiptSale extends OfflineSale {
  _BadReceiptSale(OfflineSale sale)
    : super(
        offlineRequestId: sale.offlineRequestId,
        cashierId: sale.cashierId,
        createdAt: sale.createdAt,
        shiftId: sale.shiftId,
        shiftOfflineRequestId: sale.shiftOfflineRequestId,
        lines: sale.lines,
        cashUzs: sale.cashUzs,
        cardUzs: sale.cardUzs,
      );

  @override
  SaleReceipt toReceipt() => throw StateError('receipt build failed');
}

class _SavedButNoReceiptCheckout extends OfflineCheckout {
  _SavedButNoReceiptCheckout(super.store, super.local);

  @override
  Future<OfflineSale> record({
    required List<CartLine> lines,
    required Discount? discount,
    required int cashUzs,
    required int cardUzs,
  }) async => _BadReceiptSale(
    await super.record(
      lines: lines,
      discount: discount,
      cashUzs: cashUzs,
      cardUzs: cardUzs,
    ),
  );
}

Dio _dioFailingWith(DioExceptionType type, {Response<dynamic>? response}) =>
    Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: type,
              response: response,
            ),
          ),
        ),
      );

/// A Hive write failure, a corrupt cached shift — anything not one of
/// `OfflineCheckout`'s two documented exceptions.
class _ThrowingOfflineCheckout extends OfflineCheckout {
  _ThrowingOfflineCheckout(super.store, super.local);

  @override
  Future<OfflineSale> record({
    required List<CartLine> lines,
    required Discount? discount,
    required int cashUzs,
    required int cardUzs,
  }) async {
    throw Exception('Hive write failed');
  }
}

/// Holds `record` open so a second checkout dispatched before the first
/// settles has a window to slip through (see topup_double_submit_test.dart).
class _SlowOfflineCheckout extends OfflineCheckout {
  _SlowOfflineCheckout(super.store, super.local);

  int calls = 0;

  @override
  Future<OfflineSale> record({
    required List<CartLine> lines,
    required Discount? discount,
    required int cashUzs,
    required int cardUzs,
  }) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    return super.record(
      lines: lines,
      discount: discount,
      cashUzs: cashUzs,
      cardUzs: cardUzs,
    );
  }
}

void main() {
  late Directory temp;
  late OfflineStore store;
  late LocalSource local;
  late ProductsRepository products;
  late _Sales sales;
  late PosSaleBloc Function({bool offlineMode}) build;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_pos_offline');
    Hive.init(temp.path);
    store = OfflineStore(await Hive.openBox<dynamic>(OfflineStore.boxName));
    local = LocalSource(await Hive.openBox<dynamic>('app_test'))
      ..setCashier(
        id: 'cashier-1',
        fullName: 'Zaira',
        username: 'z',
        branchId: 'b',
        branchName: 'B',
      );
    await store.cacheShift(
      'cashier-1',
      Shift(
        id: 'shift-1',
        openedAt: DateTime.utc(2026, 9, 23, 8),
        closedAt: null,
        status: 'open',
        totals: ShiftTotals.zero,
      ),
    );
    sales = _Sales();
    products = ProductsRepository(_Products(), store, local);
    await products
        .listProducts(); // warm the cache like an online session would
    build = ({bool offlineMode = false}) => PosSaleBloc(
      PosSaleRepository(sales, store),
      products,
      OfflineCheckout(store, local),
      offlineMode: offlineMode,
    );
  });

  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test(
    'offline-only plan items are hidden online and sellable offline',
    () async {
      final online = build();
      addTearDown(online.close);
      online.add(const PosSaleStarted());
      await settle();
      expect(online.state.visibleProducts.map((p) => p.id), ['popcorn']);

      await store.setOfflineMode(true);
      final offline = build(offlineMode: true);
      addTearDown(offline.close);
      offline.add(const PosSaleStarted());
      await settle();
      expect(
        offline.state.visibleProducts.map((p) => p.id),
        containsAll(['popcorn', 'vip']),
      );
    },
  );

  test(
    'offline checkout queues the sale and yields an offline receipt, no server call',
    () async {
      await store.setOfflineMode(true);
      final bloc = build(offlineMode: true);
      addTearDown(bloc.close);
      bloc.add(const PosSaleStarted());
      await settle();

      bloc
        ..add(const PosSaleProductAdded(_vip))
        ..add(const PosSaleProductAdded(_vip))
        ..add(const PosSaleCheckoutRequested(cashUzs: 150000, cardUzs: 0));
      await settle();

      expect(sales.checkouts, 0);
      expect(bloc.state.lastReceipt?.isOffline, isTrue);
      expect(bloc.state.lastReceipt?.subtotalUzs, 150000);
      expect(bloc.state.cart, isEmpty);
      expect(store.sales().single.lines.single.qty, 2);
    },
  );

  test('going back online drops offline-only items from the cart', () async {
    await store.setOfflineMode(true);
    final bloc = build(offlineMode: true);
    addTearDown(bloc.close);
    bloc.add(const PosSaleStarted());
    await settle();
    bloc
      ..add(const PosSaleProductAdded(_vip))
      ..add(const PosSaleProductAdded(_popcorn));
    await settle();

    await store.setOfflineMode(false);
    bloc.add(const PosSaleModeChanged(false));
    await settle();

    expect(bloc.state.offlineMode, isFalse);
    expect(bloc.state.cart.keys, ['popcorn']);
  });

  test(
    'a non-specific offline checkout failure stops the spinner and shows a message',
    () async {
      final bloc = PosSaleBloc(
        PosSaleRepository(sales, store),
        products,
        _ThrowingOfflineCheckout(store, local),
        offlineMode: true,
      );
      addTearDown(bloc.close);
      bloc.add(const PosSaleStarted());
      await settle();

      bloc
        ..add(const PosSaleProductAdded(_vip))
        ..add(const PosSaleCheckoutRequested(cashUzs: 75000, cardUzs: 0));
      await settle();

      expect(bloc.state.isCheckingOut, isFalse);
      expect(
        bloc.state.errorMessage,
        "Savdo saqlanmadi. Qayta urinib ko'ring.",
      );
      expect(store.sales(), isEmpty);
    },
  );

  test('a saved offline sale whose receipt fails to build is never reported as '
      'not saved', () async {
    final bloc = PosSaleBloc(
      PosSaleRepository(sales, store),
      products,
      _SavedButNoReceiptCheckout(store, local),
      offlineMode: true,
    );
    addTearDown(bloc.close);
    bloc.add(const PosSaleStarted());
    await settle();

    bloc
      ..add(const PosSaleProductAdded(_vip))
      ..add(const PosSaleCheckoutRequested(cashUzs: 75000, cardUzs: 0));
    await settle();

    expect(store.sales(), hasLength(1));
    expect(bloc.state.isCheckingOut, isFalse);
    expect(
      bloc.state.errorMessage,
      isNot("Savdo saqlanmadi. Qayta urinib ko'ring."),
    );
    expect(bloc.state.errorMessage, "Savdo saqlandi, lekin chek chiqmadi.");
    // Saved, so the cart must not invite ringing it up again.
    expect(bloc.state.cart, isEmpty);
  });

  group('online checkout that loses the connection', () {
    test('the remote maps a connection/timeout error to NoInternet', () async {
      await expectLater(
        PosSaleRemoteDataSourceImpl(
          _dioFailingWith(DioExceptionType.receiveTimeout),
        ).checkout(
          lines: const [CheckoutLine(productId: 'popcorn', qty: 1)],
          cashUzs: 12000,
          cardUzs: 0,
        ),
        throwsA(isA<NoInternetException>()),
      );
      await expectLater(
        PosSaleRemoteDataSourceImpl(
          _dioFailingWith(DioExceptionType.connectionError),
        ).checkout(
          lines: const [CheckoutLine(productId: 'popcorn', qty: 1)],
          cashUzs: 12000,
          cardUzs: 0,
        ),
        throwsA(isA<NoInternetException>()),
      );
    });

    test('an HTTP error answer is still a ServerException', () async {
      final options = RequestOptions(path: '/v1/pos/sales');
      await expectLater(
        PosSaleRemoteDataSourceImpl(
          _dioFailingWith(
            DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 500,
              data: {'message': 'Server xatosi'},
            ),
          ),
        ).checkout(
          lines: const [CheckoutLine(productId: 'popcorn', qty: 1)],
          cashUzs: 12000,
          cardUzs: 0,
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            'Server xatosi',
          ),
        ),
      );
    });

    test(
      'warns the sale may have reached the server and keeps the cart',
      () async {
        final remote = _LostConnectionSales();
        final bloc = PosSaleBloc(
          PosSaleRepository(remote, store),
          products,
          OfflineCheckout(store, local),
        );
        addTearDown(bloc.close);
        bloc.add(const PosSaleStarted());
        await settle();

        bloc
          ..add(const PosSaleProductAdded(_popcorn))
          ..add(const PosSaleCheckoutRequested(cashUzs: 12000, cardUzs: 0));
        await settle();

        expect(remote.calls, 1);
        expect(bloc.state.isCheckingOut, isFalse);
        expect(
          bloc.state.errorMessage,
          'Aloqa uzildi. Savdo serverga yetgan bo‘lishi mumkin — Sotuv '
          'tarixini tekshiring, keyin qayta urining.',
        );
        expect(bloc.state.cart, {'popcorn': 1});
        expect(store.sales(), isEmpty);
      },
    );
  });

  test('double-tapping checkout offline queues exactly one sale', () async {
    final checkout = _SlowOfflineCheckout(store, local);
    final bloc = PosSaleBloc(
      PosSaleRepository(sales, store),
      products,
      checkout,
      offlineMode: true,
    );
    addTearDown(bloc.close);
    bloc.add(const PosSaleStarted());
    await settle();

    bloc.add(const PosSaleProductAdded(_vip));
    await settle();

    bloc
      ..add(const PosSaleCheckoutRequested(cashUzs: 75000, cardUzs: 0))
      ..add(const PosSaleCheckoutRequested(cashUzs: 75000, cardUzs: 0));
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(checkout.calls, 1);
    expect(store.sales(), hasLength(1));
  });

  test(
    'a malformed checkout response online stops the spinner, warns instead of '
    'clearing the cart, and a later tap still reaches the server',
    () async {
      final remote = _MalformedResponseSales();
      final bloc = PosSaleBloc(
        PosSaleRepository(remote, store),
        products,
        OfflineCheckout(store, local),
      );
      addTearDown(bloc.close);
      bloc.add(const PosSaleStarted());
      await settle();

      bloc
        ..add(const PosSaleProductAdded(_popcorn))
        ..add(const PosSaleCheckoutRequested(cashUzs: 12000, cardUzs: 0));
      await settle();

      expect(bloc.state.isCheckingOut, isFalse);
      expect(
        bloc.state.errorMessage,
        "Server javobini o'qib bo'lmadi. Savdo tarixini tekshiring, keyin "
        "qayta urining.",
      );
      // The sale may already have been committed server-side — never clear
      // the cart on a blind guess that it wasn't.
      expect(bloc.state.cart, isNotEmpty);
      expect(remote.calls, 1);

      // The earlier "stuck spinner" bug left isCheckingOut true forever,
      // silently dropping every later tap — confirm this one actually
      // reaches the remote instead of being swallowed by that guard.
      bloc.add(const PosSaleCheckoutRequested(cashUzs: 12000, cardUzs: 0));
      await settle();
      expect(remote.calls, 2);
    },
  );
}
