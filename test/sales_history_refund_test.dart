import 'package:cashier_app/features/products/data/products_remote_data_source.dart';
import 'package:cashier_app/features/products/data/products_repository_impl.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/sales_history/data/sales_history_remote_data_source.dart';
import 'package:cashier_app/features/sales_history/data/sales_history_repository.dart';
import 'package:cashier_app/features/sales_history/domain/sale_history.dart';
import 'package:cashier_app/features/sales_history/presentation/bloc/sales_history_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

SaleHistoryEntry _sale({
  int refundedUzs = 0,
  int netUzs = 100000,
  int refundableUzs = 100000,
}) => SaleHistoryEntry(
  id: 'sale-1',
  type: 'GOODS_CHECKOUT',
  totalUzs: 100000,
  cashUzs: 100000,
  cardUzs: 0,
  balanceUzs: 0,
  refundedUzs: refundedUzs,
  refundedCashUzs: refundedUzs,
  refundedCardUzs: 0,
  netUzs: netUzs,
  refundableUzs: refundableUzs,
  refundableCashUzs: refundableUzs,
  refundableCardUzs: 0,
  canRefund: refundableUzs > 0,
  createdAt: DateTime(2026, 8, 31, 10),
  items: const [],
  refunds: const [],
);

class _FakeSalesRemote extends SalesHistoryRemoteDataSource {
  _FakeSalesRemote() : super(Dio());

  @override
  Future<SalesHistoryPageData> list({
    SaleHistoryPeriod? period,
    DateTime? from,
    DateTime? to,
    String? productId,
    required int page,
    int limit = 100,
  }) async => SalesHistoryPageData(items: [_sale()], total: 1);

  @override
  Future<SalesHistorySummary> summary({
    SaleHistoryPeriod? period,
    DateTime? from,
    DateTime? to,
    String? productId,
  }) async => const SalesHistorySummary(
    count: 1,
    totalUzs: 100000,
    cashUzs: 100000,
    cardUzs: 0,
    balanceUzs: 0,
  );

  @override
  Future<SaleHistoryEntry> refund({
    required String saleId,
    required int amountUzs,
    required SaleRefundMethod method,
    required String reason,
    required String requestId,
  }) async => _sale(
    refundedUzs: amountUzs,
    netUzs: 100000 - amountUzs,
    refundableUzs: 100000 - amountUzs,
  );
}

class _FakeProductsRemote implements ProductsRemoteDataSource {
  @override
  Future<List<Product>> listProducts() async => const [];
}

void main() {
  test(
    '30 000 refund updates the sale and net shift summary to 70 000',
    () async {
      final bloc = SalesHistoryBloc(
        SalesHistoryRepository(_FakeSalesRemote()),
        ProductsRepository(_FakeProductsRemote()),
      );
      addTearDown(bloc.close);

      bloc.add(const SalesHistoryStarted());
      await bloc.stream.firstWhere(
        (state) => !state.isLoading && state.items.isNotEmpty,
      );

      bloc.add(
        const SalesHistoryRefundRequested(
          saleId: 'sale-1',
          amountUzs: 30000,
          method: SaleRefundMethod.cash,
          reason: 'Mijoz mahsulotni qaytardi',
          requestId: 'request-1',
        ),
      );
      final success = await bloc.stream.firstWhere(
        (state) => state.refundStatus == SaleRefundSubmissionStatus.success,
      );

      expect(success.items.single.refundedUzs, 30000);
      expect(success.items.single.netUzs, 70000);
      expect(success.summary.totalUzs, 70000);
      expect(success.summary.cashUzs, 70000);
    },
  );

  test('sale exposes per-method remaining refund limits', () {
    final sale = _sale(refundedUzs: 30000, netUzs: 70000, refundableUzs: 70000);

    expect(sale.refundableFor(SaleRefundMethod.cash), 70000);
    expect(sale.refundableFor(SaleRefundMethod.card), 0);
    expect(sale.hasRefunds, isTrue);
    expect(sale.isFullyRefunded, isFalse);
  });
}
