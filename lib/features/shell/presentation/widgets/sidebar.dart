import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../model/shell_tab.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.cashierName,
    required this.branchName,
    required this.onLogout,
  });

  final ShellTab selected;
  final ValueChanged<ShellTab> onSelect;
  final String cashierName;
  final String branchName;
  final VoidCallback onLogout;

  static const _width = ResponsivePanel(compact: 176, standard: 200, wide: 220);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width.of(context),
      decoration: const BoxDecoration(
        color: NocturneColors.surface,
        border: Border(right: BorderSide(color: NocturneColors.divider)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          for (final tab in ShellTab.values)
            _NavTile(tab: tab, selected: tab == selected, onTap: () => onSelect(tab)),
          const Spacer(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: NocturneColors.accent.withValues(alpha: 0.15),
                  child: Text(
                    cashierName.isEmpty ? '?' : cashierName[0].toUpperCase(),
                    style: const TextStyle(color: NocturneColors.accent, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cashierName,
                        style: AppTextStyles.body.copyWith(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        branchName,
                        style: AppTextStyles.muted(AppTextStyles.body).copyWith(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Chiqish',
                  onPressed: onLogout,
                  icon: const Icon(PhosphorIconsRegular.signOut, size: 18),
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
  const _NavTile({required this.tab, required this.selected, required this.onTap});

  final ShellTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? NocturneColors.accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  tab.icon,
                  size: 18,
                  color: selected ? NocturneColors.accent : NocturneColors.neutral500,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tab.label,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: selected ? NocturneColors.accent : NocturneColors.text,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
