import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../bloc/birthday_sell_cubit.dart' show maxExtraChildren;
import 'birthday_ui.dart';

/// Step "Qo'shimcha bola" at sale time: big round − and + around the count;
/// − stops at 0 (the package size already holds the booked children), + at
/// [maxExtraChildren]. Shows "× price = total" beside it.
///
/// (After the sale the party's "+ bola" stays add-only: the server can't
/// take children back.)
class ExtraChildrenStepper extends StatelessWidget {
  const ExtraChildrenStepper({
    super.key,
    required this.count,
    required this.extraChildUzs,
    required this.color,
    required this.onAdd,
    required this.onRemove,
  });

  final int count;

  /// What one extra child costs at the picked size.
  final int extraChildUzs;

  /// Tier colour for the + button and the count.
  final Color color;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final ink = tierInk(context, color);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 20, 12),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _RoundButton(
            buttonKey: const ValueKey('birthday-extra-minus'),
            icon: PhosphorIconsBold.minus,
            tooltip: l10n.birthdayExtraRemove,
            onPressed: count <= 0 ? null : onRemove,
            fill: p.surface,
            fg: p.text,
          ),
          SizedBox(
            width: 84,
            child: Text(
              count == 0 ? '0' : '+$count',
              key: const ValueKey('birthday-extra-count'),
              textAlign: TextAlign.center,
              style: tabular(
                p.title.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: count == 0 ? p.textFaint : ink,
                ),
              ),
            ),
          ),
          _RoundButton(
            buttonKey: const ValueKey('birthday-extra-plus'),
            icon: PhosphorIconsBold.plus,
            tooltip: l10n.birthdayExtraAdd,
            onPressed: count >= maxExtraChildren ? null : onAdd,
            fill: color,
            fg: Colors.white,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '× ${groupDigits(extraChildUzs)}',
                  style: tabular(p.bodyMuted.copyWith(fontSize: 13.5)),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '= ${formatUzs(count * extraChildUzs)}',
                    key: const ValueKey('birthday-extra-total'),
                    style: tabular(
                      p.heading.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: count == 0 ? p.textMuted : p.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.fill,
    required this.fg,
  });

  /// On the [IconButton] itself, so tests can read its `onPressed`.
  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color fill;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final enabled = onPressed != null;
    return SizedBox(
      width: 52,
      height: 52,
      child: IconButton(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: fg,
          disabledBackgroundColor: p.surface.withValues(alpha: 0.6),
          disabledForegroundColor: p.textFaint,
          shape: const CircleBorder(),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        icon: Icon(icon, size: 22, color: enabled ? fg : p.textFaint),
      ),
    );
  }
}
