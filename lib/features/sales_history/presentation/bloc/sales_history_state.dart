part of 'sales_history_bloc.dart';

class SalesHistoryState extends Equatable {
  const SalesHistoryState({
    this.isLoading = false,
    this.period = SaleHistoryPeriod.today,
    this.page = 1,
    this.total = 0,
    this.items = const [],
    this.summary = SalesHistorySummary.zero,
    this.products = const [],
    this.selectedProductId,
    this.from,
    this.to,
    this.error,
  });
  static const pageSize = 20;
  final bool isLoading;
  final SaleHistoryPeriod? period;
  final int page;
  final int total;
  final List<SaleHistoryEntry> items;
  final SalesHistorySummary summary;
  final List<Product> products;
  final String? selectedProductId;
  final DateTime? from;
  final DateTime? to;
  final String? error;
  int get pageCount => total == 0 ? 1 : (total / pageSize).ceil();

  SalesHistoryState copyWith({
    bool? isLoading,
    SaleHistoryPeriod? period,
    bool clearPeriod = false,
    int? page,
    int? total,
    List<SaleHistoryEntry>? items,
    SalesHistorySummary? summary,
    List<Product>? products,
    String? selectedProductId,
    bool clearProduct = false,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    String? error,
    bool clearError = false,
  }) => SalesHistoryState(
    isLoading: isLoading ?? this.isLoading,
    period: clearPeriod ? null : (period ?? this.period),
    page: page ?? this.page,
    total: total ?? this.total,
    items: items ?? this.items,
    summary: summary ?? this.summary,
    products: products ?? this.products,
    selectedProductId: clearProduct
        ? null
        : (selectedProductId ?? this.selectedProductId),
    from: clearDates ? null : (from ?? this.from),
    to: clearDates ? null : (to ?? this.to),
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    isLoading,
    period,
    page,
    total,
    items,
    summary,
    products,
    selectedProductId,
    from,
    to,
    error,
  ];
}
