part of 'pos_sale_bloc.dart';

class PosSaleState extends Equatable {
  const PosSaleState({
    this.isLoadingProducts = false,
    this.products = const [],
    this.selectedCategory,
    this.searchQuery = '',
    this.cart = const {},
    this.isCheckingOut = false,
    this.errorMessage,
    this.lastReceipt,
  });

  final bool isLoadingProducts;
  final List<Product> products;
  final String? selectedCategory;

  /// Barcode/name search box above the category chips — filters
  /// [visibleProducts] client-side alongside the category filter.
  final String searchQuery;

  /// productId → qty.
  final Map<String, int> cart;
  final bool isCheckingOut;
  final String? errorMessage;
  final SaleReceipt? lastReceipt;

  List<String> get categories =>
      products.map((p) => p.category).toSet().toList()..sort();

  List<Product> get visibleProducts {
    final query = searchQuery.trim().toLowerCase();
    return products.where((p) {
      final matchesCategory =
          selectedCategory == null || p.category == selectedCategory;
      final matchesQuery = query.isEmpty || p.name.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

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
    String? searchQuery,
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
      searchQuery: searchQuery ?? this.searchQuery,
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
    searchQuery,
    cart,
    isCheckingOut,
    errorMessage,
    lastReceipt,
  ];
}
