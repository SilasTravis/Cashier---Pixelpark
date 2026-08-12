part of 'pos_sale_bloc.dart';

class PosSaleState extends Equatable {
  const PosSaleState({
    this.isLoadingProducts = false,
    this.products = const [],
    this.selectedCategory,
    this.cart = const {},
    this.isCheckingOut = false,
    this.errorMessage,
    this.lastReceipt,
  });

  final bool isLoadingProducts;
  final List<Product> products;
  final String? selectedCategory;

  /// productId → qty.
  final Map<String, int> cart;
  final bool isCheckingOut;
  final String? errorMessage;
  final SaleReceipt? lastReceipt;

  List<String> get categories =>
      products.map((p) => p.category).toSet().toList()..sort();

  List<Product> get visibleProducts => selectedCategory == null
      ? products
      : products.where((p) => p.category == selectedCategory).toList();

  List<CartLine> get cartLines {
    final byId = {for (final product in products) product.id: product};
    return [
      for (final entry in cart.entries)
        if (byId[entry.key] case final product?)
          CartLine(product: product, qty: entry.value),
    ];
  }

  int get subtotalUzs =>
      cartLines.fold(0, (sum, line) => sum + line.lineTotalUzs);

  PosSaleState copyWith({
    bool? isLoadingProducts,
    List<Product>? products,
    String? selectedCategory,
    bool clearCategory = false,
    Map<String, int>? cart,
    bool? isCheckingOut,
    String? errorMessage,
    SaleReceipt? lastReceipt,
    bool clearLastReceipt = false,
  }) {
    return PosSaleState(
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      products: products ?? this.products,
      selectedCategory: clearCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      cart: cart ?? this.cart,
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      errorMessage: errorMessage,
      lastReceipt: clearLastReceipt ? null : (lastReceipt ?? this.lastReceipt),
    );
  }

  @override
  List<Object?> get props => [
    isLoadingProducts,
    products,
    selectedCategory,
    cart,
    isCheckingOut,
    errorMessage,
    lastReceipt,
  ];
}
