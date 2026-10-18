import 'package:flutter/material.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';

/// "Balansdan yechish" as a tappable row: switch and the current balance —
/// how much it pays is a line on the receipt below. Shared by the
/// checkout panel and the "Obuna sotish" modal.
class BalanceSwitch extends StatelessWidget {
  const BalanceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.balance,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final radius = BorderRadius.circular(12);
    return Material(
      color: value ? p.accentSoft : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: value ? p.accent : p.border, width: 1.5),
      ),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          child: Row(
            children: [
              Switch(value: value, onChanged: onChanged),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.payFromBalance,
                      style: p.heading.copyWith(fontSize: 13.5),
                    ),
                    Text(
                      l10n.currentBalanceValue(formatUzs(balance)),
                      style: p.bodyMuted.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
