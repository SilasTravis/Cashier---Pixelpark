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
  const _SummaryCard({required this.label, required this.value});
  final String label;
  final String value;
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
          Text(value, style: AppTextStyles.h6),
        ],
      ),
    ),
  );
}

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.sale, required this.onOpenCustomer});
  final SaleHistoryEntry sale;
  final ValueChanged<Customer> onOpenCustomer;

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
              Text(
                formatUzs(sale.totalUzs),
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
      title: Text(
        _saleTypeLabel(AppLocalization.of(context), sale.type),
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
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
          : Text(
              formatUzs(sale.totalUzs),
              style: AppTextStyles.h6.copyWith(color: NocturneColors.accent),
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
          child: Row(
            children: [
              if (sale.cashUzs > 0)
                Text(
                  AppLocalization.of(
                    context,
                  ).paymentCashValue(formatUzs(sale.cashUzs)),
                ),
              if (sale.cashUzs > 0 && sale.cardUzs > 0) const Text('  ·  '),
              if (sale.cardUzs > 0)
                Text(
                  AppLocalization.of(
                    context,
                  ).paymentCardValue(formatUzs(sale.cardUzs)),
                ),
              if (sale.balanceUzs > 0)
                Text(
                  '  ·  ${AppLocalization.of(context).paymentBalanceValue(formatUzs(sale.balanceUzs))}',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showTopupDetails(BuildContext context) async {
    final l10n = AppLocalization.of(context);
    final customer = sale.customer;
    final openProfile = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.close),
          ),
          FilledButton.icon(
            onPressed: customer == null
                ? null
                : () => Navigator.pop(dialogContext, true),
            icon: const Icon(PhosphorIconsRegular.userCircle, size: 18),
            label: Text(l10n.openCustomerProfile),
          ),
        ],
      ),
    );
    if (openProfile == true && customer != null) onOpenCustomer(customer);
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
