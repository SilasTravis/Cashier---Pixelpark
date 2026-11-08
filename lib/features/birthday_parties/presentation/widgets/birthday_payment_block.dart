import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_payment.dart';
import '../../domain/birthday_wallet.dart';
import 'birthday_balance_row.dart';
import 'birthday_ui.dart';

/// "Balansdan yechish" + Naqd / Karta / Aralash for one birthday payment —
/// shared by the sale screen and the party's "+ To'lov" sheet.
///
/// Stateless: the owner keeps [payFromBalance], [method] and the two
/// controllers, and recomputes [payment] ([BirthdayPayment.compute], with the
/// wallet's usable money as the balance) on every change reported through
/// [onChanged] / [onMethod] / [onPayFromBalance]. The cash / card pills and
/// split fields only show while something is left to collect after the
/// balance.
class BirthdayPaymentBlock extends StatelessWidget {
  const BirthdayPaymentBlock({
    super.key,
    required this.payment,
    required this.wallet,
    required this.walletLoading,
    required this.payFromBalance,
    required this.onPayFromBalance,
    required this.method,
    required this.onMethod,
    required this.cashController,
    required this.cardController,
    required this.onChanged,
    this.showTakeNow = true,
  });

  final BirthdayPayment payment;

  /// Null while [walletLoading] or when the lookup failed.
  final BirthdayWallet? wallet;
  final bool walletLoading;
  final bool payFromBalance;
  final ValueChanged<bool> onPayFromBalance;
  final PaymentMethod method;
  final ValueChanged<PaymentMethod> onMethod;
  final TextEditingController cashController;
  final TextEditingController cardController;

  /// The split fields changed (typed text).
  final VoidCallback onChanged;

  /// False when the owner pins its own "Hozir olinadi" (the sale screen).
  final bool showTakeNow;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final l10n = AppLocalization.of(context);
    final collect = payment.collectUzs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BirthdayBalanceRow(
          wallet: wallet,
          loading: walletLoading,
          value: payFromBalance,
          onChanged: onPayFromBalance,
        ),
        if (payment.fromBalanceUzs > 0) ...[
          const SizedBox(height: 8),
          Padding(
            key: const ValueKey('bd-from-balance'),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Icon(PhosphorIconsRegular.wallet, size: 15, color: p.accent),
                const SizedBox(width: 6),
                Text(
                  l10n.bdFromBalanceLine(formatUzs(payment.fromBalanceUzs)),
                  style: tabular(
                    p.body.copyWith(fontSize: 13.5, color: p.accent),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (collect > 0) ...[
          const SizedBox(height: 14),
          PaymentMethodPills(selected: method, onChanged: onMethod),
          if (method == PaymentMethod.split) ...[
            const SizedBox(height: 10),
            SplitAmountFields(
              cashController: cashController,
              cardController: cardController,
              split: PaymentSplit.compute(
                method: method,
                totalUzs: collect,
                cashInput: cashController.text,
                cardInput: cardController.text,
              ),
              totalUzs: collect,
              autoComplete: true,
              onChanged: onChanged,
            ),
          ],
        ],
        if (showTakeNow) ...[
          const SizedBox(height: 14),
          _takeNow(p, l10n, collect),
        ],
      ],
    );
  }

  /// What the cashier physically takes right now, and how.
  Widget _takeNow(PosPalette p, AppLocalization l10n, int collect) {
    final how = collect <= 0
        ? null
        : switch (method) {
            PaymentMethod.cash => l10n.paymentCash,
            PaymentMethod.card => l10n.paymentCard,
            PaymentMethod.split => l10n.bdSplitMethod(
              groupDigits(payment.cashUzs),
              groupDigits(payment.cardUzs),
            ),
          };
    return Container(
      key: const ValueKey('bd-take-now'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              how == null ? l10n.bdTakeNow : '${l10n.bdTakeNow} · $how',
              style: p.heading.copyWith(fontSize: 14.5, color: p.accent),
            ),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatUzs(collect),
                key: const ValueKey('bd-take-now-amount'),
                style: tabular(
                  p.title.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: p.accentStrong,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
