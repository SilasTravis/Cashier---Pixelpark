import 'package:flutter/material.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';

/// "Balansdan yechish" as a tappable row: switch and the current balance —
/// how much it pays is a line on the receipt below. Shared by the checkout
/// panel and the birthday sale sheet.
class BalanceSwitch extends StatelessWidget {
  const BalanceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.balance,
    this.unknown = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final int balance;

  /// The balance could not be read: shown as such and the switch is off and
  /// disabled (never a silent 0).
  final bool unknown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final radius = BorderRadius.circular(12);
    return Material(
      color: value && !unknown ? p.accentSoft : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: value && !unknown ? p.accent : p.border,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: unknown ? null : () => onChanged(!value),
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          child: Row(
            children: [
              Switch(
                value: value && !unknown,
                onChanged: unknown ? null : onChanged,
              ),
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
                      unknown
                          ? l10n.bdBalanceUnknown
                          : l10n.currentBalanceValue(formatUzs(balance)),
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
