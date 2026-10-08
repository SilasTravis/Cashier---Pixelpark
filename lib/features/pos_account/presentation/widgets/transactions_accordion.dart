import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/customer_transaction.dart';
import '../bloc/pos_account_bloc.dart';
import 'account_ui.dart';

/// Rows per page — the same size the bloc asks the backend for.
const transactionsPageSize = 10;

/// "Amallar tarixi": everything that moved this customer's balance, folded
/// away until opened so it never gets in the cashier's way. The first open
/// loads page 1; the footer pages through the rest.
///
/// Key it by the customer's id: another customer starts folded again.
class TransactionsAccordion extends StatefulWidget {
  const TransactionsAccordion({super.key});

  @override
  State<TransactionsAccordion> createState() => _TransactionsAccordionState();
}

class _TransactionsAccordionState extends State<TransactionsAccordion> {
  bool _open = false;

  void _toggle(PosAccountState state) {
    setState(() => _open = !_open);
    // Never loaded for this customer yet → fetch on the first open.
    if (_open && state.transactionsPage == 0 && !state.isLoadingTransactions) {
      context.read<PosAccountBloc>().add(
        const PosAccountTransactionsRequested(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    return BlocBuilder<PosAccountBloc, PosAccountState>(
      buildWhen: (a, b) =>
          a.transactions != b.transactions ||
          a.transactionsTotal != b.transactionsTotal ||
          a.transactionsPage != b.transactionsPage ||
          a.isLoadingTransactions != b.isLoadingTransactions ||
          a.transactionsFailed != b.transactionsFailed,
      builder: (context, state) {
        return AccountCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _toggle(state),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.receipt,
                        size: 18,
                        color: p.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.accountTxTitle,
                        style: p.heading.copyWith(fontSize: 15),
                      ),
                      if (state.transactionsPage > 0) ...[
                        const SizedBox(width: 8),
                        StatusChip(
                          label: l10n.accountTxCount(state.transactionsTotal),
                          tone: ChipTone.neutral,
                        ),
                      ],
                      const Spacer(),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 160),
                        child: Icon(
                          PhosphorIconsRegular.caretDown,
                          size: 18,
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_open) ...[
                Divider(height: 1, color: p.border),
                _Body(state: state),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final PosAccountState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final items = state.transactions;
    if (items.isEmpty) {
      final loading =
          state.isLoadingTransactions ||
          (state.transactionsPage == 0 && !state.transactionsFailed);
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : state.transactionsFailed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.accountTxFailed,
                      style: p.bodyMuted.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => context.read<PosAccountBloc>().add(
                        PosAccountTransactionsRequested(
                          page: state.transactionsPage == 0
                              ? 1
                              : state.transactionsPage,
                        ),
                      ),
                      icon: const Icon(
                        PhosphorIconsRegular.arrowsClockwise,
                        size: 15,
                      ),
                      label: Text(l10n.refresh),
                    ),
                  ],
                )
              : Text(
                  l10n.accountTxEmpty,
                  style: p.bodyMuted.copyWith(fontSize: 13),
                ),
        ),
      );
    }
    final page = state.transactionsPage;
    final total = state.transactionsTotal;
    final pages = (total / transactionsPageSize).ceil();
    final from = (page - 1) * transactionsPageSize + 1;
    final to = from + items.length - 1;
    void go(int target) => context.read<PosAccountBloc>().add(
      PosAccountTransactionsRequested(page: target),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Keeps the rows in place while the next page loads.
        SizedBox(
          height: 2,
          child: state.isLoadingTransactions
              ? const LinearProgressIndicator(minHeight: 2)
              : null,
        ),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Divider(height: 1, color: p.border),
          _TransactionRow(items[i]),
        ],
        Divider(height: 1, color: p.border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: page > 1 && !state.isLoadingTransactions
                    ? () => go(page - 1)
                    : null,
                icon: const Icon(PhosphorIconsRegular.caretLeft, size: 14),
                label: Text(l10n.accountTxPrev),
              ),
              Expanded(
                child: Text(
                  l10n.accountTxRange(from, to, total),
                  textAlign: TextAlign.center,
                  style: p.bodyMuted.copyWith(fontSize: 12.5),
                ),
              ),
              TextButton.icon(
                onPressed: page < pages && !state.isLoadingTransactions
                    ? () => go(page + 1)
                    : null,
                iconAlignment: IconAlignment.end,
                icon: const Icon(PhosphorIconsRegular.caretRight, size: 14),
                label: Text(l10n.accountTxNext),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow(this.tx);

  final CustomerTransaction tx;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final detail = [
      _stamp(tx.createdAt),
      if (tx.cashierName != null && tx.cashierName!.isNotEmpty) tx.cashierName!,
      if (tx.note != null && tx.note!.isNotEmpty) tx.note!,
    ].join(' · ');
    final statusLabel = switch (tx.status) {
      'pending' => l10n.txStatusPending,
      'failed' => l10n.txStatusFailed,
      'cancelled' => l10n.txStatusCancelled,
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tx.isDebit ? p.surfaceMuted : p.positiveSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              tx.isDebit
                  ? PhosphorIconsRegular.arrowUpRight
                  : PhosphorIconsRegular.arrowDownLeft,
              size: 16,
              color: tx.isDebit ? p.textMuted : p.positive,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transactionTypeLabel(l10n, tx.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.heading.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.bodyMuted.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (statusLabel != null) ...[
            StatusChip(label: statusLabel, tone: ChipTone.warning),
            const SizedBox(width: 10),
          ],
          Text(
            '${tx.isDebit ? '−' : '+'}${formatUzs(tx.amountUzs)}',
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: !tx.isSettled
                  ? p.textFaint
                  : tx.isDebit
                  ? p.text
                  : p.positive,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// "07.10.2026 14:05" — written out by hand so it never depends on locale
/// date data being loaded.
String _stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
}

/// The ledger's own wording for a backend `transactionType`.
String transactionTypeLabel(AppLocalization l10n, String type) =>
    switch (type) {
      'BONUS' => l10n.txBonus,
      'PAYMENT' => l10n.txPayment,
      'MANUAL_ADJUSTMENT' => l10n.txManualAdjustment,
      'KIDS_CHARGE' => l10n.txKidsCharge,
      'CASHIER_TOPUP' => l10n.txCashierTopup,
      'POS_PURCHASE' => l10n.txPosPurchase,
      'CASHIER_TOPUP_REFUND' => l10n.txCashierTopupRefund,
      'POS_PURCHASE_REFUND' => l10n.txPosPurchaseRefund,
      'LEGACY' => l10n.txLegacy,
      'GAME_REWARD' => l10n.txGameReward,
      'MARKET_PURCHASE' => l10n.txMarketPurchase,
      'MARKET_REFUND' => l10n.txMarketRefund,
      _ => type,
    };
