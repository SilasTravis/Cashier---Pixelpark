part of 'pos_sale_bloc.dart';

class PosSaleState extends Equatable {
  const PosSaleState({
    this.isLoadingProducts = false,
    this.products = const [],
    this.selectedCategory,
    this.searchQuery = '',
    this.cart = const {},
    this.discounts = const [],
    this.selectedDiscountId,
    this.isCheckingOut = false,
    this.errorMessage,
    this.errorCode,
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

  /// Active discount catalog (`GET /v1/pos/discounts`) — best-effort, like
  /// products: empty on fetch failure, which just hides the picker.
  final List<Discount> discounts;

  /// At most one discount per receipt. Reset whenever the cart is cleared,
  /// a checkout succeeds, or the server reports it is no longer available.
  final String? selectedDiscountId;
  final bool isCheckingOut;
  final String? errorMessage;

  /// Machine-readable code paired with [errorMessage] — same reset-on-every-
  /// copyWith lifecycle (not `?? this.errorCode`), so it never lingers past
  /// the action that set it. Lets the widget react to a specific failure
  /// (`DISCOUNT_NOT_AVAILABLE`) without parsing the localized message text.
  final String? errorCode;
  final SaleReceipt? lastReceipt;

  List<String> get categories =>
      products.map((p) => p.category).toSet().toList()..sort();

  Discount? get selectedDiscount => selectedDiscountId == null
      ? null
      : discounts.where((d) => d.id == selectedDiscountId).firstOrNull;

  List<Product> get visibleProducts {
    final query = searchQuery.trim().toLowerCase();
    return products.where((p) {
      final normalizedCategory = p.category.trim().toLowerCase();
      final matchesCategory =
          selectedCategory == null ||
          normalizedCategory == selectedCategory!.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          normalizedCategory.contains(query);
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

  /// Undiscounted sum of line totals (was named `subtotalUzs` before this
  /// feature — every call site has been checked and updated; see
  /// `cart_panel.dart`).
  int get grossUzs => cartLines.fold(0, (sum, line) => sum + line.lineTotalUzs);

  /// PREVIEW ONLY (see `Discount.appliedDiscountUzs` doc comment) — the
  /// printed receipt / history / shift totals always come from the
  /// server's response instead.
  int get discountUzs => selectedDiscount?.appliedDiscountUzs(grossUzs) ?? 0;

  /// Net total shown on-screen and used to size the payment split. Can be
  /// exactly 0 when a discount is applied — that is a valid checkout (see
  /// `PaymentSplit.compute`'s `allowZeroTotal`).
  int get totalUzs => grossUzs - discountUzs;

  PosSaleState copyWith({
    bool? isLoadingProducts,
    List<Product>? products,
    String? selectedCategory,
    bool clearCategory = false,
    String? searchQuery,
    Map<String, int>? cart,
    List<Discount>? discounts,
    String? selectedDiscountId,
    bool clearSelectedDiscountId = false,
    bool? isCheckingOut,
    String? errorMessage,
    String? errorCode,
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
      discounts: discounts ?? this.discounts,
      selectedDiscountId: clearSelectedDiscountId
          ? null
          : (selectedDiscountId ?? this.selectedDiscountId),
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      errorMessage: errorMessage,
      errorCode: errorCode,
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
    discounts,
    selectedDiscountId,
    isCheckingOut,
    errorMessage,
    errorCode,
    lastReceipt,
  ];
}
