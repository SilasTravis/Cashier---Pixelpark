import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../../generated/l10n.dart';
import '../model/shell_tab.dart';

/// The till's one top bar: brand mark, the section tabs, then — pinned
/// right — the shift takings, language, who is on the till and "Smenani
/// yopish". Replaces the old left rail + page header.
///
/// Wide windows show every tab with its label; narrower ones keep only the
/// selected tab's label and turn the rest into icons (with tooltips).
class TopNav extends StatelessWidget {
  const TopNav({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.cashierName,
    required this.shiftOpenedAt,
    required this.onCloseShift,
    required this.updateAvailable,
    this.revenue,
    this.tabs = ShellTab.primary,
    this.disabledTabs = const {},
    this.counts = const {},
    this.closeShiftDisabledReason,
  });

  final ShellTab selected;
  final ValueChanged<ShellTab> onSelect;
  final String cashierName;
  final DateTime? shiftOpenedAt;
  final VoidCallback? onCloseShift;

  /// True while a background check has found a newer release. Drives the dot
  /// on the Settings tab so nobody has to remember to look.
  final ValueListenable<bool> updateAvailable;

  /// The shift-takings card (see `ShiftRevenueChip`); null hides it.
  final Widget? revenue;

  /// Tabs to show, in order. The shell appends [ShellTab.unsynced] only
  /// while sales are queued.
  final List<ShellTab> tabs;

  /// Tabs that ignore taps and explain why (offline: internet-only tabs).
  final Set<ShellTab> disabledTabs;

  /// A count pill per tab; zero or missing renders nothing.
  final Map<ShellTab, int> counts;

  /// Tooltip on the close-shift button while [onCloseShift] is null, so a
  /// greyed-out button explains itself (offline: shifts close online only).
  final String? closeShiftDisabledReason;

  /// Width of the tab row with every label shown: padding, icon, gap, the
  /// label as drawn, and the count pill.
  double _labelsWidth(BuildContext context, AppLocalization l10n) {
    final style = AppTextStyles.body.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    var total = 0.0;
    for (final tab in tabs) {
      final painter = TextPainter(
        text: TextSpan(text: tab.label(l10n), style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      total += 4 + 24 + 19 + 9 + painter.width;
      if ((counts[tab] ?? 0) > 0) total += 8 + 30;
    }
    return total;
  }

  String _time(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // The cashier block returns only on a wide window (it is always in
        // the brand mark's tooltip); the close button drops its label on a
        // narrow one.
        final showWho = width >= 1560;
        final wideClose = width >= 1180;
        // Every tab keeps its label while they all fit next to the right
        // cluster — measured, so a long "Sinxronlanmagan" tab or a longer
        // language never pushes the last tab off screen. Otherwise only
        // the selected tab is labelled.
        final rightCluster =
            (revenue != null ? 210 : 0) +
            10 +
            90 +
            (showWho ? 214 : 0) +
            12 +
            (wideClose ? 150 : 44);
        final tabsRoom = width - 32 - 36 - 14 - 12 - rightCluster;
        final allLabels = _labelsWidth(context, l10n) <= tabsRoom;
        final disabledReason = onCloseShift == null
            ? closeShiftDisabledReason
            : null;
        final closeButton = wideClose
            ? OutlinedButton.icon(
                onPressed: onCloseShift,
                icon: const Icon(PhosphorIconsRegular.signOut, size: 16),
                label: Text(l10n.shiftClose),
              )
            : IconButton.outlined(
                tooltip: disabledReason == null ? l10n.shiftClose : null,
                onPressed: onCloseShift,
                icon: const Icon(PhosphorIconsRegular.signOut, size: 17),
              );
        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: NocturneColors.surface,
            border: Border(bottom: BorderSide(color: NocturneColors.divider)),
          ),
          child: Row(
            children: [
              Tooltip(
                message: [
                  cashierName.isEmpty ? l10n.cashDesk : cashierName,
                  if (shiftOpenedAt != null)
                    l10n.shiftOpenedAt(_time(shiftOpenedAt!)),
                ].join(' · '),
                child: const _BrandMark(),
              ),
              const SizedBox(width: 14),
              // Tabs scroll sideways instead of overflowing on a tiny window.
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tab in tabs)
                        ValueListenableBuilder<bool>(
                          valueListenable: updateAvailable,
                          builder: (context, hasUpdate, _) => _NavTab(
                            tab: tab,
                            selected: tab == selected,
                            showLabel: allLabels || tab == selected,
                            badge: hasUpdate && tab == ShellTab.settings,
                            disabled: disabledTabs.contains(tab),
                            count: counts[tab] ?? 0,
                            onTap: () => onSelect(tab),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (revenue != null) ...[revenue!, const SizedBox(width: 10)],
              const LanguageSwitcher(),
              if (showWho) ...[
                const SizedBox(width: 14),
                _WhoIsOnTill(
                  cashierName: cashierName,
                  shiftOpened: shiftOpenedAt == null
                      ? null
                      : l10n.shiftOpenedAt(_time(shiftOpenedAt!)),
                ),
              ],
              const SizedBox(width: 12),
              if (disabledReason != null)
                Tooltip(message: disabledReason, child: closeButton)
              else
                closeButton,
            ],
          ),
        );
      },
    );
  }
}

/// The blue "P" square that opens the bar — the till's brand mark.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: NocturneColors.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'P',
        style: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Cashier name over "● Smena 01:07 da ochildi" — a green dot says the
/// till is open.
class _WhoIsOnTill extends StatelessWidget {
  const _WhoIsOnTill({required this.cashierName, required this.shiftOpened});

  final String cashierName;
  final String? shiftOpened;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            cashierName.isEmpty ? l10n.cashDesk : cashierName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h5.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (shiftOpened != null)
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: NocturneColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    shiftOpened!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 11.5,
                      color: NocturneColors.neutral600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.tab,
    required this.selected,
    required this.showLabel,
    required this.onTap,
    this.badge = false,
    this.disabled = false,
    this.count = 0,
  });

  final ShellTab tab;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;
  final bool badge;
  final bool disabled;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final color = selected ? NocturneColors.accent : NocturneColors.neutral600;
    final tile = Opacity(
      opacity: disabled ? .38 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: selected ? NocturneColors.accent900 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(10),
            hoverColor: NocturneColors.neutral900,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(tab.icon, size: 19, color: color),
                      if (badge)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            // Keyed per tab (not just for Settings) so tests
                            // can assert which tab the badge renders on,
                            // rather than merely that it renders somewhere.
                            key: Key('nav-update-badge-${tab.name}'),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: NocturneColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (showLabel) ...[
                    const SizedBox(width: 9),
                    Text(
                      tab.label(l10n),
                      maxLines: 1,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: selected
                            ? NocturneColors.accent
                            : NocturneColors.neutral300,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      key: Key('nav-count-${tab.name}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: NocturneColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (disabled) return Tooltip(message: l10n.needsInternet, child: tile);
    return showLabel ? tile : Tooltip(message: tab.label(l10n), child: tile);
  }
}
