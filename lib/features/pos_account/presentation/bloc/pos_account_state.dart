part of 'pos_account_bloc.dart';

class PosAccountState extends Equatable {
  const PosAccountState({
    this.phoneDigits = '',
    this.isSearching = false,
    this.results = const [],
    this.selectedCustomer,
    this.isLoadingProducts = false,
    this.products = const [],
    this.isBusy = false,
    this.errorMessage,
    this.lastIssuedPasses,
  });

  final String phoneDigits;
  final bool isSearching;
  final List<Customer> results;
  final Customer? selectedCustomer;
  final bool isLoadingProducts;
  final List<Product> products;
  final bool isBusy;
  final String? errorMessage;

  /// Set right after a successful pass issuance so the UI can pop the QR
  /// slip dialog; cleared once acknowledged.
  final IssuedPasses? lastIssuedPasses;

  PosAccountState copyWith({
    String? phoneDigits,
    bool? isSearching,
    List<Customer>? results,
    Customer? selectedCustomer,
    bool clearSelected = false,
    bool? isLoadingProducts,
    List<Product>? products,
    bool? isBusy,
    String? errorMessage,
    IssuedPasses? lastIssuedPasses,
    bool clearLastIssuedPasses = false,
  }) {
    return PosAccountState(
      phoneDigits: phoneDigits ?? this.phoneDigits,
      isSearching: isSearching ?? this.isSearching,
      results: results ?? this.results,
      selectedCustomer: clearSelected
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      products: products ?? this.products,
      isBusy: isBusy ?? this.isBusy,
      errorMessage: errorMessage,
      lastIssuedPasses: clearLastIssuedPasses
          ? null
          : (lastIssuedPasses ?? this.lastIssuedPasses),
    );
  }

  @override
  List<Object?> get props => [
    phoneDigits,
    isSearching,
    results,
    selectedCustomer,
    isLoadingProducts,
    products,
    isBusy,
    errorMessage,
    lastIssuedPasses,
  ];
}
