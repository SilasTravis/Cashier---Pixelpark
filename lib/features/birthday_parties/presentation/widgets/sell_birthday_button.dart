import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../generated/l10n.dart';

/// "Tug'ilgan kun sotish" in the account page's summary strip. [onPressed]
/// null disables it (offline / busy); [disabledReason] is the tooltip then.
class SellBirthdayButton extends StatelessWidget {
  const SellBirthdayButton({
    super.key,
    required this.onPressed,
    this.compact = false,
    this.disabledReason,
  });

  final VoidCallback? onPressed;
  final bool compact;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final style = OutlinedButton.styleFrom(
      foregroundColor: p.accent,
      side: BorderSide(
        color: onPressed == null ? p.border : p.accentBorder,
        width: 1.5,
      ),
    );
    const icon = Icon(PhosphorIconsRegular.cake, size: 16);
    final button = compact
        ? IconButton.outlined(
            key: const ValueKey('sell-birthday-button'),
            tooltip: l10n.birthdaySell,
            onPressed: onPressed,
            style: style,
            icon: icon,
          )
        : SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              key: const ValueKey('sell-birthday-button'),
              onPressed: onPressed,
              style: style,
              icon: icon,
              label: Text(l10n.birthdaySell),
            ),
          );
    if (onPressed == null && disabledReason != null) {
      return Tooltip(message: disabledReason!, child: button);
    }
    return button;
  }
}
