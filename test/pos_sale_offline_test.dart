import 'dart:io';

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
}
