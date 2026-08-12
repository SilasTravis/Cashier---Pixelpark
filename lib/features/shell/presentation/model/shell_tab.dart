import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum ShellTab {
  posAccount(label: 'Hisob va QR', icon: PhosphorIconsRegular.qrCode),
  posSale(label: 'Savdo', icon: PhosphorIconsRegular.shoppingCartSimple),
  products(label: 'Mahsulotlar', icon: PhosphorIconsRegular.package);

  const ShellTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
