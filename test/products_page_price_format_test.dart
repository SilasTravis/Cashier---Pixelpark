import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/features/products/data/products_remote_data_source.dart';
import 'package:cashier_app/features/products/data/products_repository_impl.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/products/presentation/bloc/products_bloc.dart';
import 'package:cashier_app/features/products/presentation/pages/products_page.dart';
import 'package:cashier_app/injector_container.dart';

class _FakeProductsRemote implements ProductsRemoteDataSource {
  @override
  Future<List<Product>> listProducts() async => const [
    Product(
      id: 'p1',
      name: 'Paypoq',
      priceUzs: 150000,
      category: 'kiyim',
      icon: 'sock',
    ),
  ];
}

void main() {
  testWidgets('product catalog cards show grouped so\'m prices', (
    tester,
  ) async {
    sl.registerFactory<ProductsBloc>(
      () => ProductsBloc(ProductsRepository(_FakeProductsRemote())),
    );
    addTearDown(sl.reset);

    await tester.pumpWidget(const MaterialApp(home: Material(child: ProductsPage())));
    await tester.pumpAndSettle();

    expect(find.text("150 000 so'm"), findsOneWidget);
    expect(find.text("150000 so'm"), findsNothing);
  });
}
