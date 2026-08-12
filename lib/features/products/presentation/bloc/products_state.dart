part of 'products_bloc.dart';

class ProductsState extends Equatable {
  const ProductsState({
    this.isLoading = false,
    this.products = const [],
    this.query = '',
    this.selectedCategory,
    this.errorMessage,
  });

  final bool isLoading;
  final List<Product> products;
  final String query;
  final String? selectedCategory;
  final String? errorMessage;

  List<String> get categories =>
      products.map((p) => p.category).toSet().toList()..sort();

  List<Product> get visibleProducts {
    final normalizedQuery = query.trim().toLowerCase();
    return products.where((product) {
      final matchesCategory =
          selectedCategory == null || product.category == selectedCategory;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          product.name.toLowerCase().contains(normalizedQuery);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  ProductsState copyWith({
    bool? isLoading,
    List<Product>? products,
    String? query,
    String? selectedCategory,
    bool clearCategory = false,
    String? errorMessage,
  }) {
    return ProductsState(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      query: query ?? this.query,
      selectedCategory: clearCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    products,
    query,
    selectedCategory,
    errorMessage,
  ];
}
