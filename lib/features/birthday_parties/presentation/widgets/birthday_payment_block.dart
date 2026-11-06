import 'package:flutter/material.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../pos_account/presentation/widgets/balance_switch.dart';
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

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final collect = payment.collectUzs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BalanceSwitch(
          value: payFromBalance,
          onChanged: onPayFromBalance,
          balance: balanceUzs,
        ),
        if (payment.fromBalanceUzs > 0) ...[
          const SizedBox(height: 6),
          _line(p, '−', formatUzs(payment.fromBalanceUzs)),
        ],
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

  Widget _line(PosPalette p, String sign, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(sign, style: p.bodyMuted),
        Text(value, style: p.body),
      ],
    ),
  );
}
