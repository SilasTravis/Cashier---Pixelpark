import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/receipt_id.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../injector_container.dart';
import '../../../../generated/l10n.dart';
import '../../domain/sale_history.dart';
import '../../../pos_account/domain/customer.dart';
import '../bloc/sales_history_bloc.dart';
import '../widgets/refund_sale_dialog.dart';

class SalesHistoryPage extends StatelessWidget {
  const SalesHistoryPage({super.key, required this.onOpenCustomer});

  final ValueChanged<Customer> onOpenCustomer;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<SalesHistoryBloc>()..add(const SalesHistoryStarted()),
    child: _SalesHistoryView(onOpenCustomer: onOpenCustomer),
  );
}

class _SalesHistoryView extends StatelessWidget {
  const _SalesHistoryView({required this.onOpenCustomer});

  final ValueChanged<Customer> onOpenCustomer;
  @override
  Widget build(BuildContext context) {
    final compact = breakpointOfContext(context) == Breakpoint.compact;
    return BlocBuilder<SalesHistoryBloc, SalesHistoryState>(
      builder: (context, state) => Column(
        children: [
          Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final period in SaleHistoryPeriod.values)
                            ChoiceChip(
                              label: Text(
                                _periodLabel(
                                  AppLocalization.of(context),
                                  period,
                                ),
                              ),
                              selected: state.period == period,
                              onSelected: state.isLoading
                                  ? null
                                  : (_) => context.read<SalesHistoryBloc>().add(
                                      SalesHistoryPeriodChanged(period),
                                    ),
                            ),
                          OutlinedButton.icon(
                            onPressed: state.isLoading
                                ? null
                                : () => _pickDateRange(context, state),
                            icon: const Icon(
                              PhosphorIconsRegular.calendarBlank,
                              size: 16,
                            ),
                            label: Text(
                              state.from == null || state.to == null
                                  ? AppLocalization.of(context).historyDateRange
                                  : '${DateFormat('dd.MM.yyyy').format(state.from!)} — '
                                        '${DateFormat('dd.MM.yyyy').format(state.to!)}',
                            ),
                          ),
                          SizedBox(
                            width: compact ? 200 : 230,
                            child: DropdownButtonFormField<String?>(
                              initialValue: state.selectedProductId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: AppLocalization.of(
                                  context,
                                ).historyProduct,
                                prefixIcon: const Icon(
                                  PhosphorIconsRegular.package,
                                  size: 17,
                                ),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    AppLocalization.of(
                                      context,
                                    ).historyAllProducts,
                                  ),
                                ),
                                for (final product in state.products)
                                  DropdownMenuItem<String?>(
                                    value: product.id,
                                    child: Text(
                                      product.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: state.isLoading
                                  ? null
                                  : (value) => context
                                        .read<SalesHistoryBloc>()
                                        .add(SalesHistoryProductChanged(value)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalization.of(context).refresh,
                      onPressed: state.isLoading
                          ? null
                          : () => context.read<SalesHistoryBloc>().add(
                              const SalesHistoryStarted(),
                            ),
                      icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 12),
                Row(
                  children: [
                    _SummaryCard(
                      label: AppLocalization.of(context).historySales,
                      value: AppLocalization.of(
                        context,
                      ).historyCount(state.summary.count),
                    ),
                    _SummaryCard(
                      label: AppLocalization.of(context).total,
                      value: formatUzs(state.summary.totalUzs),
                    ),
                    _SummaryCard(
                      label: AppLocalization.of(context).paymentCash,
                      value: formatUzs(state.summary.cashUzs),
                    ),
                    _SummaryCard(
                      label: AppLocalization.of(context).paymentCard,
                      value: formatUzs(state.summary.cardUzs),
                    ),
                    _SummaryCard(
                      label: AppLocalization.of(context).paymentBalance,
                      value: formatUzs(state.summary.balanceUzs),
                    ),
                    if (state.summary.refundedUzs > 0)
                      _SummaryCard(
                        label: AppLocalization.of(context).refundedTotal,
                        value: '−${formatUzs(state.summary.refundedUzs)}',
                        tone: NocturneColors.danger,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                state.error!,
                style: const TextStyle(color: NocturneColors.danger),
              ),
            ),
          Expanded(
            child: state.items.isEmpty && !state.isLoading
                ? Center(
                    child: Text(
                      AppLocalization.of(context).historyEmpty,
                      style: AppTextStyles.muted(AppTextStyles.body),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _SaleCard(
                      sale: state.items[index],
                      onOpenCustomer: onOpenCustomer,
                      refundEnabled: state.selectedProductId == null,
                    ),
                  ),
          ),
          if (state.total > SalesHistoryState.pageSize)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: state.page > 1 && !state.isLoading
                        ? () => context.read<SalesHistoryBloc>().add(
                            SalesHistoryPageChanged(state.page - 1),
                          )
                        : null,
                    icon: const Icon(PhosphorIconsRegular.caretLeft),
                  ),
                  Text('${state.page} / ${state.pageCount}'),
                  IconButton(
                    onPressed: state.page < state.pageCount && !state.isLoading
                        ? () => context.read<SalesHistoryBloc>().add(
                            SalesHistoryPageChanged(state.page + 1),
                          )
                        : null,
                    icon: const Icon(PhosphorIconsRegular.caretRight),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(
    BuildContext context,
    SalesHistoryState state,
  ) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: state.from != null && state.to != null
          ? DateTimeRange(start: state.from!, end: state.to!)
          : null,
      helpText: AppLocalization.of(context).historyChoosePeriod,
      cancelText: AppLocalization.of(context).cancel,
      confirmText: AppLocalization.of(context).historyChoose,
      saveText: AppLocalization.of(context).historyChoose,
    );
    if (range == null || !context.mounted) return;
    context.read<SalesHistoryBloc>().add(
      SalesHistoryDateRangeChanged(range.start, range.end),
    );
  }
}

String _periodLabel(AppLocalization l10n, SaleHistoryPeriod period) =>
    switch (period) {
      SaleHistoryPeriod.today => l10n.historyToday,
      SaleHistoryPeriod.sevenDays => l10n.history7Days,
      SaleHistoryPeriod.thirtyDays => l10n.history30Days,
      SaleHistoryPeriod.year => l10n.historyYear,
    };

String _saleTypeLabel(AppLocalization l10n, String type) => switch (type) {
  'GOODS_CHECKOUT' => l10n.saleGoods,
  'GATE_PASS' => l10n.saleGatePass,
  'ACCOUNT_TOPUP' => l10n.saleTopup,
  _ => l10n.saleGeneric,
};

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, this.tone});
  final String label;
  final String value;

  /// Colours the figure when it needs to read as money leaving, not arriving.
  final Color? tone;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NocturneColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.muted(
              AppTextStyles.body,
            ).copyWith(fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: tone == null
                ? AppTextStyles.h6
                : AppTextStyles.h6.copyWith(color: tone),
          ),
        ],
      ),
    ),
  );
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.sale,
    required this.onOpenCustomer,
    required this.refundEnabled,
  });
  final SaleHistoryEntry sale;
  final ValueChanged<Customer> onOpenCustomer;
  final bool refundEnabled;

  @override
  Widget build(BuildContext context) {
    if (sale.type == 'ACCOUNT_TOPUP') {
      return Material(
        color: NocturneColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: NocturneColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          onTap: () => _showTopupDetails(context),
          title: Text(
            _saleTypeLabel(AppLocalization.of(context), sale.type),
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${DateFormat('dd.MM.yyyy HH:mm').format(sale.createdAt)}  ·  #${formatReceiptId(sale.id)}'
            '${sale.customer == null ? '' : '\n${sale.customer!.fullName}  ·  ${sale.customer!.phoneNumber}'}',
            style: AppTextStyles.muted(
              AppTextStyles.body,
            ).copyWith(fontSize: 11),
          ),
          isThreeLine: sale.customer != null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sale.hasRefunds) ...[
                _RefundStatusBadge(sale: sale),
                const SizedBox(width: 10),
              ],
              Text(
                formatUzs(sale.hasRefunds ? sale.netUzs : sale.totalUzs),
                style: AppTextStyles.h6.copyWith(color: NocturneColors.accent),
              ),
              const SizedBox(width: 10),
              const Icon(PhosphorIconsRegular.caretRight, size: 16),
            ],
          ),
        ),
      );
    }
    return ExpansionTile(
      backgroundColor: NocturneColors.surface,
      collapsedBackgroundColor: NocturneColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: NocturneColors.divider),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: NocturneColors.divider),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              _saleTypeLabel(AppLocalization.of(context), sale.type),
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (sale.hasRefunds) ...[
            const SizedBox(width: 8),
            _RefundStatusBadge(sale: sale),
          ],
        ],
      ),
      subtitle: Text(
        '${DateFormat('dd.MM.yyyy HH:mm').format(sale.createdAt)}  ·  #${formatReceiptId(sale.id)}',
        style: AppTextStyles.muted(AppTextStyles.body).copyWith(fontSize: 11),
      ),
      trailing: sale.balanceUzs > 0 && sale.cashUzs == 0 && sale.cardUzs == 0
          ? Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                AppLocalization.of(
                  context,
                ).paymentBalanceValue(formatUzs(sale.balanceUzs)),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatUzs(sale.netUzs),
                  style: AppTextStyles.h6.copyWith(
                    color: NocturneColors.accent,
                  ),
                ),
                if (sale.hasRefunds)
                  Text(
                    formatUzs(sale.totalUzs),
                    style: AppTextStyles.muted(AppTextStyles.body).copyWith(
                      fontSize: 10,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
      children: [
        if (sale.items.isNotEmpty)
          for (final item in sale.items)
            ListTile(
              dense: true,
              title: Text(item.name),
              subtitle: Text('${item.qty} × ${formatUzs(item.priceUzs)}'),
              trailing: Text(formatUzs(item.totalUzs)),
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              if (sale.cashUzs > 0)
                Text(
                  AppLocalization.of(
                    context,
                  ).paymentCashValue(formatUzs(sale.cashUzs)),
                ),
              if (sale.cardUzs > 0)
                Text(
                  AppLocalization.of(
                    context,
                  ).paymentCardValue(formatUzs(sale.cardUzs)),
                ),
              if (sale.balanceUzs > 0)
                Text(
                  AppLocalization.of(
                    context,
                  ).paymentBalanceValue(formatUzs(sale.balanceUzs)),
                ),
            ],
          ),
        ),
        if (sale.refunds.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsRegular.clockCounterClockwise,
                  size: 17,
                  color: NocturneColors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalization.of(context).refundHistory,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (final refund in sale.refunds) _RefundAuditRow(refund: refund),
        ],
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${AppLocalization.of(context).refundRemainingAmount}: ${formatUzs(sale.refundableUzs)}',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (sale.refundedUzs > 0)
                      Text(
                        '${AppLocalization.of(context).refundAlreadyAmount}: ${formatUzs(sale.refundedUzs)}',
                        style: AppTextStyles.muted(AppTextStyles.body),
                      ),
                  ],
                ),
              ),
              if (_canRefundNow)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: NocturneColors.danger,
                  ),
                  onPressed: () => _openRefund(context),
                  icon: const Icon(
                    PhosphorIconsRegular.arrowUDownLeft,
                    size: 17,
                  ),
                  label: Text(AppLocalization.of(context).refundAction),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openRefund(BuildContext context) async {
    final amount = await showSaleRefundDialog(context, sale);
    if (amount == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalization.of(context).refundSuccess(formatUzs(amount)),
        ),
      ),
    );
  }

  bool get _canRefundNow =>
      refundEnabled && sale.canRefund && sale.refundableUzs > 0;

  Future<void> _showTopupDetails(BuildContext context) async {
    final l10n = AppLocalization.of(context);
    final customer = sale.customer;
    final action = await showDialog<_TopupDetailAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              PhosphorIconsRegular.wallet,
              color: NocturneColors.accent,
            ),
            const SizedBox(width: 10),
            Text(l10n.topupDetails),
          ],
        ),
        content: SizedBox(
          width: 470,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customer != null) ...[
                _DetailRow(label: l10n.accountOwner, value: customer.fullName),
                _DetailRow(
                  label: l10n.phoneNumber,
                  value: customer.phoneNumber,
                ),
                _DetailRow(
                  label: l10n.balance,
                  value: formatUzs(customer.balance),
                ),
                const Divider(height: 24),
              ],
              _DetailRow(
                label: l10n.total,
                value: formatUzs(sale.totalUzs),
                emphasized: true,
              ),
              _DetailRow(
                label: l10n.paymentCash,
                value: formatUzs(sale.cashUzs),
              ),
              _DetailRow(
                label: l10n.paymentCard,
                value: formatUzs(sale.cardUzs),
              ),
              if (sale.hasRefunds) ...[
                _DetailRow(
                  label: l10n.refundedTotal,
                  value: formatUzs(sale.refundedUzs),
                ),
                _DetailRow(
                  label: l10n.refundRemainingAmount,
                  value: formatUzs(sale.refundableUzs),
                ),
              ],
              _DetailRow(
                label: l10n.date,
                value: DateFormat('dd.MM.yyyy HH:mm:ss').format(sale.createdAt),
              ),
              _DetailRow(
                label: l10n.transactionId,
                value: '#${formatReceiptId(sale.id)}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: Text(l10n.close),
          ),
          if (_canRefundNow)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: NocturneColors.danger,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, _TopupDetailAction.refund),
              icon: const Icon(PhosphorIconsRegular.arrowUDownLeft, size: 18),
              label: Text(l10n.refundAction),
            ),
          FilledButton.icon(
            onPressed: customer == null
                ? null
                : () =>
                      Navigator.pop(dialogContext, _TopupDetailAction.profile),
            icon: const Icon(PhosphorIconsRegular.userCircle, size: 18),
            label: Text(l10n.openCustomerProfile),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case _TopupDetailAction.refund:
        await _openRefund(context);
      case _TopupDetailAction.profile:
        if (customer != null) onOpenCustomer(customer);
      case null:
        break;
    }
  }
}

/// What the cashier chose to do from a top-up receipt's detail dialog.
enum _TopupDetailAction { refund, profile }

class _RefundStatusBadge extends StatelessWidget {
  const _RefundStatusBadge({required this.sale});

  final SaleHistoryEntry sale;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: NocturneColors.accent900,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: NocturneColors.accent700),
    ),
    child: Text(
      sale.isFullyRefunded
          ? AppLocalization.of(context).refundFullBadge
          : AppLocalization.of(context).refundPartialBadge,
      style: AppTextStyles.body.copyWith(
        fontSize: 10,
        color: NocturneColors.accent200,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _RefundAuditRow extends StatelessWidget {
  const _RefundAuditRow({required this.refund});

  final SaleHistoryRefund refund;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final method = refund.method == SaleRefundMethod.cash
        ? l10n.paymentCash
        : l10n.paymentCard;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NocturneColors.neutral900,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NocturneColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: NocturneColors.accent900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                PhosphorIconsRegular.arrowUDownLeft,
                size: 17,
                color: NocturneColors.accent300,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    refund.reason,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.refundAuditBy(
                      DateFormat('dd.MM.yyyy HH:mm').format(refund.createdAt),
                      refund.refundedByName,
                    ),
                    style: AppTextStyles.muted(
                      AppTextStyles.body,
                    ).copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '−${formatUzs(refund.amountUzs)}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  method,
                  style: AppTextStyles.muted(
                    AppTextStyles.body,
                  ).copyWith(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: AppTextStyles.muted(AppTextStyles.body)),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: emphasized
              ? AppTextStyles.h5.copyWith(color: NocturneColors.accent)
              : AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
