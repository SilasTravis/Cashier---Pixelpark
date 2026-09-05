import 'package:cashier_app/features/products/data/products_remote_data_source.dart';
import 'package:cashier_app/features/products/data/products_repository_impl.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/sales_history/data/sales_history_remote_data_source.dart';
import 'package:cashier_app/features/sales_history/data/sales_history_repository.dart';
import 'package:cashier_app/features/sales_history/domain/sale_history.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
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
  refundedBalanceUzs: 0,
  netUzs: netUzs,
  refundableUzs: refundableUzs,
  refundableCashUzs: refundableUzs,
  refundableCardUzs: 0,
  refundableBalanceUzs: 0,
  canRefund: refundableUzs > 0,
  createdAt: DateTime(2026, 8, 31, 10),
  items: const [],
  refunds: const [],
  passes: const [],
);

class _FakeSalesRemote extends SalesHistoryRemoteDataSource {
  _FakeSalesRemote() : super(Dio());

  SaleRefundMethod? lastMethod;
  List<String> lastGatePassIds = const [];

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
    refundedUzs: 0,
  );

  @override
  Future<SaleHistoryEntry> refund({
    required String saleId,
    required int amountUzs,
    required SaleRefundMethod method,
    required String reason,
    required String requestId,
    List<String> gatePassIds = const [],
  }) async {
    lastMethod = method;
    lastGatePassIds = gatePassIds;
    return _sale(
      refundedUzs: amountUzs,
      netUzs: 100000 - amountUzs,
      refundableUzs: 100000 - amountUzs,
    );
  }
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

  test(
    'the selected entrance passes reach the server with the refund',
    () async {
      final remote = _FakeSalesRemote();
      final bloc = SalesHistoryBloc(
        SalesHistoryRepository(remote),
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
          amountUzs: 40000,
          method: SaleRefundMethod.cash,
          reason: 'Chipta ishlatilmadi',
          requestId: 'request-2',
          gatePassIds: ['pass-1', 'pass-2'],
        ),
      );
      await bloc.stream.firstWhere(
        (state) => state.refundStatus == SaleRefundSubmissionStatus.success,
      );

      expect(remote.lastGatePassIds, ['pass-1', 'pass-2']);
    },
  );

  test(
    'money returned to a balance never shrinks the drawer takings',
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
          amountUzs: 20000,
          method: SaleRefundMethod.balance,
          reason: 'Xato mahsulot yechilgan',
          requestId: 'request-3',
        ),
      );
      final success = await bloc.stream.firstWhere(
        (state) => state.refundStatus == SaleRefundSubmissionStatus.success,
      );

      expect(success.summary.cashUzs, 100000);
      expect(success.summary.cardUzs, 0);
      expect(success.summary.refundedUzs, 0);
    },
  );

  test('a top-up refund is capped by what the balance still holds', () {
    final spent = _topupSale(balance: 40000);
    final untouched = _topupSale(balance: 100000);

    expect(spent.refundCeilingFor(SaleRefundMethod.cash), 40000);
    expect(untouched.refundCeilingFor(SaleRefundMethod.cash), 100000);
  });
}

SaleHistoryEntry _topupSale({required int balance}) => SaleHistoryEntry(
  id: 'topup-1',
  type: 'ACCOUNT_TOPUP',
  totalUzs: 100000,
  cashUzs: 100000,
  cardUzs: 0,
  balanceUzs: 0,
  refundedUzs: 0,
  refundedCashUzs: 0,
  refundedCardUzs: 0,
  refundedBalanceUzs: 0,
  netUzs: 100000,
  refundableUzs: 100000,
  refundableCashUzs: 100000,
  refundableCardUzs: 0,
  refundableBalanceUzs: 0,
  canRefund: true,
  createdAt: DateTime(2026, 8, 31, 10),
  items: const [],
  refunds: const [],
  passes: const [],
  customer: Customer(
    id: 42,
    phoneNumber: '+998900000000',
    firstName: 'Ota',
    lastName: 'Ona',
    balance: balance,
    children: const [],
  ),
);
