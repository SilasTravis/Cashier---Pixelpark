part of 'sales_history_bloc.dart';

/// A pending write against ONE sale — a refund or a payment-method
/// correction. The cashier does one at a time, so a single tracker serves
/// both and the two dialogs share the same submit/settle shape.
enum SaleActionStatus { initial, submitting, success, failure }

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
    this.actionStatus = SaleActionStatus.initial,
    this.actingSaleId,
    this.actionError,
    this.lastActedSaleId,
  });
  static const pageSize = 100;
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
  final SaleActionStatus actionStatus;
  final String? actingSaleId;
  final String? actionError;
  final String? lastActedSaleId;
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
    SaleActionStatus? actionStatus,
    String? actingSaleId,
    bool clearActingSale = false,
    String? actionError,
    bool clearActionError = false,
    String? lastActedSaleId,
    bool clearLastActedSale = false,
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
    actionStatus: actionStatus ?? this.actionStatus,
    actingSaleId: clearActingSale ? null : (actingSaleId ?? this.actingSaleId),
    actionError: clearActionError ? null : (actionError ?? this.actionError),
    lastActedSaleId: clearLastActedSale
        ? null
        : (lastActedSaleId ?? this.lastActedSaleId),
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
    actionStatus,
    actingSaleId,
    actionError,
    lastActedSaleId,
  ];
}
