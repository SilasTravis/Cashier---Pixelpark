import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../products/data/products_repository_impl.dart';
import '../../../products/domain/product.dart';
import '../../data/sales_history_repository.dart';
import '../../domain/sale_edit_plan.dart';
import '../../domain/sale_history.dart';

part 'sales_history_event.dart';
part 'sales_history_state.dart';

class SalesHistoryBloc extends Bloc<SalesHistoryEvent, SalesHistoryState> {
  SalesHistoryBloc(this.repository, this.productsRepository)
    : super(const SalesHistoryState()) {
    on<SalesHistoryStarted>(_load);
    on<SalesHistoryPeriodChanged>(_changePeriod);
    on<SalesHistoryPageChanged>(_changePage);
    on<SalesHistoryProductChanged>(_changeProduct);
    on<SalesHistoryDateRangeChanged>(_changeDateRange);
    on<SalesHistoryRefundRequested>(_refundSale);
    on<SalesHistoryPaymentCorrectionRequested>(_correctSalePayment);
    on<SalesHistoryEditRequested>(_editSale);
  }
  final SalesHistoryRepository repository;
  final ProductsRepository productsRepository;

  Future<void> _load(
    SalesHistoryStarted event,
    Emitter<SalesHistoryState> emit,
  ) async {
    if (state.products.isEmpty) {
      final products = await productsRepository.listProducts();
      products.fold((_) {}, (items) => emit(state.copyWith(products: items)));
    }
    await _fetch(page: state.page, emit: emit);
  }

  Future<void> _changePeriod(
    SalesHistoryPeriodChanged event,
    Emitter<SalesHistoryState> emit,
  ) => _fetch(period: event.period, clearDates: true, page: 1, emit: emit);

  Future<void> _changePage(
    SalesHistoryPageChanged event,
    Emitter<SalesHistoryState> emit,
  ) => _fetch(page: event.page, emit: emit);

  Future<void> _changeProduct(
    SalesHistoryProductChanged event,
    Emitter<SalesHistoryState> emit,
  ) => _fetch(
    productId: event.productId,
    clearProduct: event.productId == null,
    page: 1,
    emit: emit,
  );

  Future<void> _changeDateRange(
    SalesHistoryDateRangeChanged event,
    Emitter<SalesHistoryState> emit,
  ) => _fetch(
    from: event.from,
    to: event.to,
    clearPeriod: true,
    page: 1,
    emit: emit,
  );

  Future<void> _fetch({
    SaleHistoryPeriod? period,
    DateTime? from,
    DateTime? to,
    String? productId,
    bool clearPeriod = false,
    bool clearDates = false,
    bool clearProduct = false,
    required int page,
    required Emitter<SalesHistoryState> emit,
  }) async {
    final nextPeriod = clearPeriod ? null : (period ?? state.period);
    final nextFrom = clearDates ? null : (from ?? state.from);
    final nextTo = clearDates ? null : (to ?? state.to);
    final nextProductId = clearProduct
        ? null
        : (productId ?? state.selectedProductId);
    emit(
      state.copyWith(
        isLoading: true,
        period: nextPeriod,
        clearPeriod: clearPeriod,
        from: nextFrom,
        to: nextTo,
        clearDates: clearDates,
        selectedProductId: nextProductId,
        clearProduct: clearProduct,
        page: page,
        clearError: true,
      ),
    );
    try {
      final result = await repository.load(
        period: nextPeriod,
        from: nextFrom,
        to: nextTo,
        productId: nextProductId,
        page: page,
      );
      emit(
        state.copyWith(
          isLoading: false,
          items: result.$1.items,
          total: result.$1.total,
          summary: result.$2,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(isLoading: false, error: repository.errorMessage(error)),
      );
    }
  }

  Future<void> _refundSale(
    SalesHistoryRefundRequested event,
    Emitter<SalesHistoryState> emit,
  ) async {
    if (state.actionStatus == SaleActionStatus.submitting) return;
    emit(
      state.copyWith(
        actionStatus: SaleActionStatus.submitting,
        actingSaleId: event.saleId,
        clearActionError: true,
        clearLastActedSale: true,
      ),
    );
    try {
      final updated = await repository.refund(
        saleId: event.saleId,
        amountUzs: event.amountUzs,
        method: event.method,
        reason: event.reason,
        requestId: event.requestId,
        gatePassIds: event.gatePassIds,
      );
      // Money returned to a stored balance never leaves the drawer, so it
      // must not shrink the shift's cash/card takings.
      final drawerRefund = event.method == SaleRefundMethod.balance
          ? 0
          : event.amountUzs;
      emit(
        state.copyWith(
          actionStatus: SaleActionStatus.success,
          clearActingSale: true,
          lastActedSaleId: event.saleId,
          items: [
            for (final item in state.items)
              if (item.id == event.saleId) updated else item,
          ],
          summary: SalesHistorySummary(
            count: state.summary.count,
            totalUzs: state.summary.totalUzs - event.amountUzs,
            cashUzs:
                state.summary.cashUzs -
                (event.method == SaleRefundMethod.cash ? event.amountUzs : 0),
            cardUzs:
                state.summary.cardUzs -
                (event.method == SaleRefundMethod.card ? event.amountUzs : 0),
            balanceUzs:
                state.summary.balanceUzs -
                (event.method == SaleRefundMethod.balance
                    ? event.amountUzs
                    : 0),
            refundedUzs: state.summary.refundedUzs + drawerRefund,
          ),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          actionStatus: SaleActionStatus.failure,
          clearActingSale: true,
          actionError: repository.errorMessage(error),
        ),
      );
    }
  }

  /// A mis-rung method moves money between the two physical columns of one
  /// receipt. The takings do not change, so the period summary keeps its
  /// totals and only the cash/card split shifts.
  Future<void> _correctSalePayment(
    SalesHistoryPaymentCorrectionRequested event,
    Emitter<SalesHistoryState> emit,
  ) async {
    if (state.actionStatus == SaleActionStatus.submitting) return;
    emit(
      state.copyWith(
        actionStatus: SaleActionStatus.submitting,
        actingSaleId: event.saleId,
        clearActionError: true,
        clearLastActedSale: true,
      ),
    );
    try {
      final updated = await repository.correctPayment(
        saleId: event.saleId,
        fromMethod: event.fromMethod,
        toMethod: event.toMethod,
        amountUzs: event.amountUzs,
        reason: event.reason,
        requestId: event.requestId,
      );
      final toCash = event.toMethod == SalePaymentMoveMethod.cash;
      final delta = event.amountUzs;
      emit(
        state.copyWith(
          actionStatus: SaleActionStatus.success,
          clearActingSale: true,
          lastActedSaleId: event.saleId,
          items: [
            for (final item in state.items)
              if (item.id == event.saleId) updated else item,
          ],
          summary: SalesHistorySummary(
            count: state.summary.count,
            totalUzs: state.summary.totalUzs,
            cashUzs: state.summary.cashUzs + (toCash ? delta : -delta),
            cardUzs: state.summary.cardUzs + (toCash ? -delta : delta),
            balanceUzs: state.summary.balanceUzs,
            refundedUzs: state.summary.refundedUzs,
          ),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          actionStatus: SaleActionStatus.failure,
          clearActingSale: true,
          actionError: repository.errorMessage(error),
        ),
      );
    }
  }

  /// Runs the column move and then the refund, in that order because the
  /// server refuses to shift columns underneath a refund.
  ///
  /// If the second write fails, the first one STAYS — and that is deliberate:
  /// re-planning against the receipt's new state derives only what is still
  /// missing, so a retry finishes the edit instead of doubling it. The error
  /// surfaces so the cashier knows the drawer has not been touched yet.
  Future<void> _editSale(
    SalesHistoryEditRequested event,
    Emitter<SalesHistoryState> emit,
  ) async {
    if (state.actionStatus == SaleActionStatus.submitting) return;
    final plan = event.plan;
    emit(
      state.copyWith(
        actionStatus: SaleActionStatus.submitting,
        actingSaleId: event.saleId,
        clearActionError: true,
        clearLastActedSale: true,
      ),
    );
    try {
      SaleHistoryEntry? updated;
      if (plan.needsCorrection) {
        updated = await repository.correctPayment(
          saleId: event.saleId,
          fromMethod: plan.correctionFrom!,
          toMethod: plan.targetMethod,
          amountUzs: plan.correctionUzs,
          reason: event.reason,
          requestId: const Uuid().v4(),
        );
      }
      if (plan.needsRefund) {
        updated = await repository.refund(
          saleId: event.saleId,
          amountUzs: plan.refundUzs,
          method: plan.refundMethod,
          reason: event.reason,
          requestId: const Uuid().v4(),
        );
      }
      if (updated == null) return;

      final toCash = plan.targetMethod == SalePaymentMoveMethod.cash;
      final moved = plan.correctionUzs;
      final handedBack = plan.refundUzs;
      emit(
        state.copyWith(
          actionStatus: SaleActionStatus.success,
          clearActingSale: true,
          lastActedSaleId: event.saleId,
          items: [
            for (final item in state.items)
              if (item.id == event.saleId) updated else item,
          ],
          summary: SalesHistorySummary(
            count: state.summary.count,
            totalUzs: state.summary.totalUzs - handedBack,
            cashUzs:
                state.summary.cashUzs + (toCash ? moved - handedBack : -moved),
            cardUzs:
                state.summary.cardUzs + (toCash ? -moved : moved - handedBack),
            balanceUzs: state.summary.balanceUzs,
            refundedUzs: state.summary.refundedUzs + handedBack,
          ),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          actionStatus: SaleActionStatus.failure,
          clearActingSale: true,
          actionError: repository.errorMessage(error),
        ),
      );
    }
  }
}
