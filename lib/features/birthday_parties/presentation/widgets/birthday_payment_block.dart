import 'package:flutter/material.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../pos_account/presentation/widgets/balance_switch.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_payment.dart';

/// "Balansdan yechish" + Naqd / Karta / Aralash for one birthday payment —
/// shared by the sale sheet and (C6) the party's "+ To'lov" sheet.
///
/// Stateless: the owner keeps [payFromBalance], [method] and the two
/// controllers, and recomputes [payment] ([BirthdayPayment.compute]) on every
/// change reported through [onChanged] / [onMethod] / [onPayFromBalance].
/// The cash / card pills and split fields only show while something is left to
/// collect after the balance.
class BirthdayPaymentBlock extends StatelessWidget {
  const BirthdayPaymentBlock({
    super.key,
    required this.payment,
    required this.balanceUzs,
    required this.payFromBalance,
    required this.onPayFromBalance,
    required this.method,
    required this.onMethod,
    required this.cashController,
    required this.cardController,
    required this.onChanged,
    this.balanceUnknown = false,
  });

  final BirthdayPayment payment;
  final int balanceUzs;
  final bool payFromBalance;
  final ValueChanged<bool> onPayFromBalance;
  final PaymentMethod method;
  final ValueChanged<PaymentMethod> onMethod;
  final TextEditingController cashController;
  final TextEditingController cardController;

  /// The split fields changed (typed text).
  final VoidCallback onChanged;

  /// The balance lookup failed: the switch is disabled, not a silent 0.
  final bool balanceUnknown;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final l10n = AppLocalization.of(context);
    final collect = payment.collectUzs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BalanceSwitch(
          value: payFromBalance,
          onChanged: onPayFromBalance,
          balance: balanceUzs,
          unknown: balanceUnknown,
        ),
        if (payment.fromBalanceUzs > 0) ...[
          const SizedBox(height: 6),
          _line(
            p,
            l10n.bdFromBalanceLine(formatUzs(payment.fromBalanceUzs)),
            '',
            key: const ValueKey('bd-from-balance'),
          ),
        ],
        const SizedBox(height: 10),
        _takeNow(p, l10n, collect),
        if (collect > 0) ...[
          const SizedBox(height: 12),
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
      ],
    );
  }

  Widget _line(PosPalette p, String label, String value, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: p.bodyMuted),
        if (value.isNotEmpty) Text(value, style: p.body),
      ],
    ),
  );

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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              how == null ? l10n.bdTakeNow : '${l10n.bdTakeNow} · $how',
              style: p.heading.copyWith(color: p.accent),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatUzs(collect),
                key: const ValueKey('bd-take-now-amount'),
                style: p.title.copyWith(fontSize: 26, color: p.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
