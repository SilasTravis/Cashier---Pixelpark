import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../theme/app_text_styles.dart';
import '../theme/nocturne_colors.dart';
import '../utils/currency.dart';
import '../../generated/l10n.dart';

/// How a charge is funded — mirrors the design's `Naqd` / `Karta` / `Aralash`
/// pills. `cash`/`card` send the whole total to one method with no typing;
/// `split` gives two independently editable fields (cash and card), both
/// typed by the cashier, that must add up to the total.
enum PaymentMethod { cash, card, split }

/// Cash/card breakdown for a given [total], derived from [method] and — for
/// [PaymentMethod.split] — the cashier's typed cash and card amounts.
/// Centralizes the split math so `cart_panel.dart`, `customer_detail_panel.dart`
/// (both the children/QR card and the balance card) don't each re-derive it.
class PaymentSplit {
  const PaymentSplit({
    required this.cashUzs,
    required this.cardUzs,
    required this.isValid,
  });

  final int cashUzs;
  final int cardUzs;

  /// Whether this split can be submitted — total > 0 and, for `split`, the
  /// typed cash + card exactly equal the total.
  final bool isValid;

  static PaymentSplit compute({
    required PaymentMethod method,
    required int totalUzs,
    required String cashInput,
    String cardInput = '',
  }) {
    if (totalUzs <= 0) {
      return const PaymentSplit(cashUzs: 0, cardUzs: 0, isValid: false);
    }
    switch (method) {
      case PaymentMethod.cash:
        return PaymentSplit(cashUzs: totalUzs, cardUzs: 0, isValid: true);
      case PaymentMethod.card:
        return PaymentSplit(cashUzs: 0, cardUzs: totalUzs, isValid: true);
      case PaymentMethod.split:
        final cash = int.tryParse(cashInput.replaceAll(' ', '')) ?? 0;
        final card = int.tryParse(cardInput.replaceAll(' ', '')) ?? 0;
        return PaymentSplit(
          cashUzs: cash,
          cardUzs: card,
          isValid: cash >= 0 && card >= 0 && cash + card == totalUzs,
        );
    }
  }
}

const _methods = [
  (method: PaymentMethod.cash, icon: PhosphorIconsRegular.money),
  (method: PaymentMethod.card, icon: PhosphorIconsRegular.creditCard),
  (method: PaymentMethod.split, icon: PhosphorIconsRegular.arrowsLeftRight),
];

/// The `Naqd` / `Karta` / `Aralash` pill row — equal-width, icon + label,
/// accent-tinted when selected. Matches `category_filter.dart`'s chip look.
class PaymentMethodPills extends StatelessWidget {
  const PaymentMethodPills({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Row(
      children: [
        for (final m in _methods) ...[
          if (m.method != _methods.first.method) const SizedBox(width: 6),
          Expanded(
            child: _Pill(
              label: switch (m.method) {
                PaymentMethod.cash => l10n.paymentCash,
                PaymentMethod.card => l10n.paymentCard,
                PaymentMethod.split => l10n.paymentSplit,
              },
              icon: m.icon,
              selected: selected == m.method,
              onTap: () => onChanged(m.method),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? NocturneColors.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? NocturneColors.accent : NocturneColors.divider,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? NocturneColors.accent : NocturneColors.text,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      color: selected
                          ? NocturneColors.accent
                          : NocturneColors.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The `split` mode's cash/card row — both fields are independently typed
/// by the cashier (e.g. 10 000 cash + 10 000 card). A running-total line
/// below shows what's been entered against what's owed, so the cashier
/// doesn't have to do the arithmetic themselves.
class SplitAmountFields extends StatelessWidget {
  const SplitAmountFields({
    super.key,
    required this.cashController,
    required this.cardController,
    required this.split,
    required this.totalUzs,
    this.onChanged,
  });

  final TextEditingController cashController;
  final TextEditingController cardController;
  final PaymentSplit split;
  final int totalUzs;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final entered = split.cashUzs + split.cardUzs;
    final remaining = totalUzs - entered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: cashController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.body,
                onChanged: (_) => onChanged?.call(),
                decoration: InputDecoration(labelText: l10n.paymentCash),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: cardController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.body,
                onChanged: (_) => onChanged?.call(),
                decoration: InputDecoration(labelText: l10n.paymentCard),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              remaining == 0
                  ? l10n.paymentMatched
                  : remaining > 0
                  ? l10n.paymentMissing
                  : l10n.paymentExcess,
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                color: remaining == 0
                    ? NocturneColors.accent300
                    : NocturneColors.text.withValues(alpha: 0.55),
              ),
            ),
            const Spacer(),
            Text(
              remaining == 0 ? formatUzs(entered) : formatUzs(remaining.abs()),
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: remaining == 0
                    ? NocturneColors.accent300
                    : NocturneColors.danger,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
