import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../injector_container.dart';
import '../../domain/sale_history.dart';
import '../bloc/sales_history_bloc.dart';

class SalesHistoryPage extends StatelessWidget {
  const SalesHistoryPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<SalesHistoryBloc>()..add(const SalesHistoryStarted()),
    child: const _SalesHistoryView(),
  );
}

class _SalesHistoryView extends StatelessWidget {
  const _SalesHistoryView();
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SalesHistoryBloc, SalesHistoryState>(
      builder: (context, state) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    for (final period in SaleHistoryPeriod.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(period.label),
                          selected: state.period == period,
                          onSelected: state.isLoading
                              ? null
                              : (_) => context.read<SalesHistoryBloc>().add(
                                  SalesHistoryPeriodChanged(period),
                                ),
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Yangilash',
                      onPressed: state.isLoading
                          ? null
                          : () => context.read<SalesHistoryBloc>().add(
                              const SalesHistoryStarted(),
                            ),
                      icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SummaryCard(
                      label: 'Sotuvlar',
                      value: '${state.summary.count} ta',
                    ),
                    _SummaryCard(
                      label: 'Jami',
                      value: formatUzs(state.summary.totalUzs),
                    ),
                    _SummaryCard(
                      label: 'Naqd',
                      value: formatUzs(state.summary.cashUzs),
                    ),
                    _SummaryCard(
                      label: 'Karta',
                      value: formatUzs(state.summary.cardUzs),
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
                      'Bu davrda sotuvlar yo‘q',
                      style: AppTextStyles.muted(AppTextStyles.body),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) =>
                        _SaleCard(sale: state.items[index]),
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
}

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
  const _SaleCard({required this.sale});
  final SaleHistoryEntry sale;
  @override
  Widget build(BuildContext context) => ExpansionTile(
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
      sale.typeLabel,
      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      '${DateFormat('dd.MM.yyyy HH:mm').format(sale.createdAt)}  ·  #${sale.id.substring(0, 8)}',
      style: AppTextStyles.muted(AppTextStyles.body).copyWith(fontSize: 11),
    ),
    trailing: Text(
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
            if (sale.cashUzs > 0) Text('Naqd: ${formatUzs(sale.cashUzs)}'),
            if (sale.cashUzs > 0 && sale.cardUzs > 0) const Text('  ·  '),
            if (sale.cardUzs > 0) Text('Karta: ${formatUzs(sale.cardUzs)}'),
            if (sale.balanceUzs > 0)
              Text('  ·  Balans: ${formatUzs(sale.balanceUzs)}'),
          ],
        ),
      ),
    ],
  );
}
