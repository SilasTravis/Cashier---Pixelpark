import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../model/shell_tab.dart';

/// Matches the design's slim dark nav rail: a compact "Kassa · {cashier}"
/// kicker up top, the tab list, then shift-open time + close-shift pinned to
/// the bottom — no avatar/logout footer (that moved to the Settings tab).
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.selected,
    required this.collapsed,
    required this.onToggle,
    required this.onSelect,
    required this.cashierName,
    required this.shiftOpenedAt,
    required this.onCloseShift,
  });

  final ShellTab selected;
  final bool collapsed;
  final VoidCallback onToggle;
  final ValueChanged<ShellTab> onSelect;
  final String cashierName;
  final DateTime? shiftOpenedAt;
  final VoidCallback? onCloseShift;

  static const _width = ResponsivePanel(compact: 156, standard: 200, wide: 220);
  static const double _collapsedWidth = 68;

  String _time(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: collapsed ? _collapsedWidth : _width.of(context),
      decoration: const BoxDecoration(
        color: NocturneColors.surface,
        border: Border(right: BorderSide(color: NocturneColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (!collapsed)
                  Expanded(
                    child: Text(
                      cashierName.isEmpty ? 'Kassa' : 'Kassa · $cashierName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.kicker.copyWith(
                        color: NocturneColors.text.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: collapsed ? 'Menyuni ochish' : 'Menyuni yopish',
                  onPressed: onToggle,
                  icon: Icon(
                    collapsed
                        ? PhosphorIconsRegular.caretRight
                        : PhosphorIconsRegular.caretLeft,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (final tab in ShellTab.values)
            _NavTile(
              tab: tab,
              selected: tab == selected,
              collapsed: collapsed,
              onTap: () => onSelect(tab),
            ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 8 : 10,
              0,
              collapsed ? 8 : 10,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!collapsed && shiftOpenedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Smena ${_time(shiftOpenedAt!)} da ochildi",
                      style: AppTextStyles.body.copyWith(
                        fontSize: 11,
                        color: NocturneColors.text.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                if (collapsed)
                  IconButton.outlined(
                    tooltip: 'Smenani yopish',
                    onPressed: onCloseShift,
                    icon: const Icon(PhosphorIconsRegular.signOut, size: 16),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: onCloseShift,
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                    ),
                    icon: const Icon(PhosphorIconsRegular.signOut, size: 16),
                    label: const Text("Smenani yopish"),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.tab,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final ShellTab tab;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected
            ? NocturneColors.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 10,
              vertical: 10,
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  tab.icon,
                  size: 18,
                  color: selected
                      ? NocturneColors.accent
                      : NocturneColors.neutral500,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tab.label,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        color: selected
                            ? NocturneColors.accent
                            : NocturneColors.text,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return collapsed ? Tooltip(message: tab.label, child: tile) : tile;
  }
}
