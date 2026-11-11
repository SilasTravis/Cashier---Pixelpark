import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_wallet.dart';
import 'birthday_ui.dart';

/// "Balansdan yechish" for a birthday payment: only the real money of the
/// balance may pay ([BirthdayWallet.usableUzs]); the bonus is named beside it
/// as not usable. Loading shows a skeleton; a failed lookup or no real money
/// disables the switch with the reason (cash / card still work).
class BirthdayBalanceRow extends StatelessWidget {
  const BirthdayBalanceRow({
    super.key,
    required this.wallet,
    required this.loading,
    required this.value,
    required this.onChanged,
  });

  /// Null while [loading], or when the lookup failed.
  final BirthdayWallet? wallet;
  final bool loading;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final w = wallet;
    final usable = w?.usableUzs ?? 0;
    final enabled = !loading && w != null && usable > 0;
    final on = enabled && value;
    final radius = BorderRadius.circular(16);

    final Widget detail;
    if (loading) {
      detail = const Padding(
        key: ValueKey('bd-balance-skeleton'),
        padding: EdgeInsets.only(top: 6),
        child: SkeletonBar(width: 190, height: 11),
      );
    } else if (w == null) {
      detail = _reason(p, l10n.bdWalletFailed, key: 'bd-balance-failed');
    } else {
      detail = Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.bdWalletUsable(formatUzs(usable)),
            key: const ValueKey('bd-balance-usable'),
            style: tabular(
              p.body.copyWith(
                fontSize: 13,
                color: usable > 0 ? p.text : p.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (w.bonusUzs > 0) _BonusPill(amountUzs: w.bonusUzs),
          if (usable == 0)
            _reason(p, l10n.bdWalletNoUsable, key: 'bd-balance-none'),
        ],
      );
    }

    return Material(
      key: const ValueKey('bd-balance-row'),
      color: on ? p.accentSoft : p.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: on ? p.accentBorder : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
          child: Row(
            children: [
              Switch(value: on, onChanged: enabled ? onChanged : null),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.payFromBalance,
                      style: p.heading.copyWith(
                        fontSize: 14.5,
                        color: enabled ? p.text : p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    detail,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reason(PosPalette p, String text, {required String key}) => Text(
    text,
    key: ValueKey(key),
    style: p.bodyMuted.copyWith(fontSize: 12.5),
  );
}

/// Amber "Bonus 300 000 — ishlatib bo'lmaydi".
class _BonusPill extends StatelessWidget {
  const _BonusPill({required this.amountUzs});

  final int amountUzs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    return Container(
      key: const ValueKey('bd-balance-bonus'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: p.warningSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsRegular.gift, size: 13, color: p.warning),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              l10n.bdWalletBonus(groupDigits(amountUzs)),
              style: tabular(
                p.body.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: p.warning,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
