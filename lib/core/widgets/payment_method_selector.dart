import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../theme/app_text_styles.dart';
import '../theme/pos_palette.dart';
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
    // A 100%-off discount is a valid, zero-total sale (see the POS
    // discounts design doc's "zero-total sales" decision) — the caller
    // opts in only when a discount is actually selected, so a genuinely
    // empty cart's zero total stays invalid.
    bool allowZeroTotal = false,
  }) {
    if (totalUzs <= 0) {
      final zeroIsValid = allowZeroTotal && totalUzs == 0;
      return PaymentSplit(cashUzs: 0, cardUzs: 0, isValid: zeroIsValid);
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
    final p = PosPalette.of(context);
    // The light workspace gets roomier, bolder pills; Nocturne keeps its
    // compact 36px row.
    final light = Theme.of(context).brightness == Brightness.light;
    final radius = BorderRadius.circular(light ? 11 : 8);
    final fg = selected ? p.accent : (light ? p.textMuted : p.text);
    return Material(
      color: selected ? p.accentSoft : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: light ? 58 : 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? p.accent : p.border,
              width: light ? 1.5 : 1,
            ),
          ),
          // Light: icon stacked over the label, like a big tap target;
          // Nocturne: the compact inline pill.
          child: Flex(
            direction: light ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: light ? 20 : 14, color: fg),
              SizedBox(width: light ? 0 : 6, height: light ? 3 : 0),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppTextStyles.body.copyWith(
                      fontSize: light ? 13 : 12,
                      fontWeight: light ? FontWeight.w600 : null,
                      color: fg,
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
    this.autoComplete = false,
  });

  final TextEditingController cashController;
  final TextEditingController cardController;
  final PaymentSplit split;
  final int totalUzs;
  final VoidCallback? onChanged;

  /// Typing one half fills the other with what is left of [totalUzs], and
  /// the running-total line only shows while they don't add up.
  final bool autoComplete;

  void _fillOther(String typed, TextEditingController other) {
    if (!autoComplete) return;
    final value = int.tryParse(typed.replaceAll(' ', ''));
    if (value == null) return;
    final rest = totalUzs - value;
    other.text = groupDigits(rest < 0 ? 0 : rest);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
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
                inputFormatters: const [ThousandsInputFormatter()],
                style: p.body,
                onChanged: (value) {
                  _fillOther(value, cardController);
                  onChanged?.call();
                },
                decoration: InputDecoration(labelText: l10n.paymentCash),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: cardController,
                keyboardType: TextInputType.number,
                inputFormatters: const [ThousandsInputFormatter()],
                style: p.body,
                onChanged: (value) {
                  _fillOther(value, cashController);
                  onChanged?.call();
                },
                decoration: InputDecoration(labelText: l10n.paymentCard),
              ),
            ),
          ],
        ),
        if (!autoComplete || remaining != 0) ...[
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
                  color: remaining == 0 ? p.positive : p.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                remaining == 0
                    ? formatUzs(entered)
                    : formatUzs(remaining.abs()),
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: remaining == 0 ? p.positive : p.danger,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
