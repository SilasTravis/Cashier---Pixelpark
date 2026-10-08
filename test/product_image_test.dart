import 'dart:io';

import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/features/offline/application/offline_checkout.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/pos_sale/data/pos_sale_remote_data_source.dart';
import 'package:cashier_app/features/pos_sale/data/pos_sale_repository_impl.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';
import 'package:cashier_app/features/pos_sale/presentation/bloc/pos_sale_bloc.dart';
import 'package:cashier_app/features/pos_sale/presentation/widgets/product_grid.dart';
import 'package:cashier_app/features/products/data/products_remote_data_source.dart';
import 'package:cashier_app/features/products/data/products_repository_impl.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _popcorn = Product(
  id: 'p1',
  name: 'Popkorn katta stakan, sho‘r yoki shirin',
  priceUzs: 25000,
  category: 'Snack',
  icon: 'ph-popcorn',
  // Unreachable in tests → exercises the error fallback.
  imageUrl: 'https://img.invalid/popcorn.jpg',
);
const _water = Product(
  id: 'p2',
  name: 'Suv',
  priceUzs: 5000,
  category: 'Drink',
  icon: 'ph-drop',
);

class _Products extends ProductsRemoteDataSourceImpl {
  _Products() : super(Dio());
  @override
  Future<List<Product>> listProducts() async => [
    for (var i = 0; i < 12; i++) i.isEven ? _popcorn : _water,
  ];
}

class _Sales extends PosSaleRemoteDataSourceImpl {
  _Sales() : super(Dio());
  @override
  Future<List<Discount>> fetchDiscounts() async => const [];
}

void main() {
  group('Product.imageUrl', () {
    Map<String, dynamic> json(Object? imageUrl) => {
      'id': 'p1',
      'name': 'Popkorn',
      'priceUzs': 25000,
      'category': 'Snack',
      'icon': 'ph-popcorn',
      'imageUrl': imageUrl,
    };

    test('a valid http(s) URL is kept and survives the offline cache', () {
      final product = Product.fromJson(json('https://cdn.x.uz/uploads/a.jpg'));
      expect(product.imageUrl, 'https://cdn.x.uz/uploads/a.jpg');
      expect(Product.fromJson(product.toJson()), product);
    });

    test('missing, blank or bad values cost only the photo', () {
      for (final bad in [null, '', '  ', 'not a url', '/uploads/a.jpg', 42]) {
        expect(Product.fromJson(json(bad)).imageUrl, isNull, reason: '$bad');
      }
      // A cache written before photos existed has no key at all.
      final legacy = json(null)..remove('imageUrl');
      expect(Product.fromJson(legacy).imageUrl, isNull);
    });
  });

  group('ProductImage', () {
    Future<void> pump(WidgetTester tester, Product product) =>
        tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox.square(
                dimension: 120,
                child: ProductImage(product: product),
              ),
            ),
          ),
        );

    testWidgets('no photo → the icon', (tester) async {
      await pump(tester, _water);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('a photo that fails to load → the icon, no error', (
      tester,
    ) async {
      await pump(tester, _popcorn);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Icon), findsOneWidget);
    });
  });

  group('ProductGrid tiles fit', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('cashier_product_image');
      Hive.init(temp.path);
    });

    tearDown(() async {
      await Hive.close();
      await temp.delete(recursive: true);
    });

    for (final size in [const Size(800, 600), const Size(480, 600)]) {
      testWidgets('at $size, with and without photos', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        late PosSaleBloc bloc;
        await tester.runAsync(() async {
          final store = OfflineStore(
            await Hive.openBox<dynamic>(OfflineStore.boxName),
          );
          final local = LocalSource(await Hive.openBox<dynamic>('app_test'));
          bloc = PosSaleBloc(
            PosSaleRepository(_Sales(), store),
            ProductsRepository(_Products(), store, local),
            OfflineCheckout(store, local),
          )..add(const PosSaleStarted());
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        addTearDown(bloc.close);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [AppLocalization.delegate],
            supportedLocales: AppLocalization.delegate.supportedLocales,
            home: Scaffold(
              body: BlocProvider.value(value: bloc, child: const ProductGrid()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ProductImage), findsWidgets);
        // The name is never cut short with "…".
        final name = tester.widget<Text>(find.text(_popcorn.name).first);
        expect(name.maxLines, isNull);
        expect(name.overflow, isNot(TextOverflow.ellipsis));
      });
    }
  });
}
