import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

enum ShellTab {
  posAccount(label: 'Hisob va QR', icon: PhosphorIconsRegular.qrCode),
  posSale(label: 'Savdo', icon: PhosphorIconsRegular.shoppingCartSimple),
  salesHistory(
    label: 'Sotuv tarixi',
    icon: PhosphorIconsRegular.clockCounterClockwise,
  ),
  settings(label: 'Sozlamalar', icon: PhosphorIconsRegular.gearSix);

  const ShellTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
