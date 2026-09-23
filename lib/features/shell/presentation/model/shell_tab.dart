import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../generated/l10n.dart';

enum ShellTab {
  posAccount(icon: PhosphorIconsRegular.qrCode),
  posSale(icon: PhosphorIconsRegular.shoppingCartSimple),
  salesHistory(icon: PhosphorIconsRegular.clockCounterClockwise),
  visitHistory(icon: PhosphorIconsRegular.arrowsLeftRight),
  inside(icon: PhosphorIconsRegular.personSimpleRun),
  settings(icon: PhosphorIconsRegular.gearSix),
  unsynced(icon: PhosphorIconsRegular.cloudArrowUp);

  const ShellTab({required this.icon});

  final IconData icon;

  /// Always-present tabs; [unsynced] appears only while sales are queued.
  static const List<ShellTab> primary = [
    posAccount,
    posSale,
    salesHistory,
    visitHistory,
    inside,
    settings,
  ];

  /// Tabs that can't work without the server — disabled in offline mode.
  bool get needsInternet => switch (this) {
    ShellTab.posAccount || ShellTab.visitHistory || ShellTab.inside => true,
    _ => false,
  };

  String label(AppLocalization l10n) => switch (this) {
    ShellTab.posAccount => l10n.tabAccount,
    ShellTab.posSale => l10n.tabSales,
    ShellTab.salesHistory => l10n.tabHistory,
    ShellTab.visitHistory => l10n.tabVisitHistory,
    ShellTab.inside => l10n.tabInside,
    ShellTab.settings => l10n.tabSettings,
    ShellTab.unsynced => l10n.tabUnsynced,
  };
}
