import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../shift/domain/shift.dart';
import '../model/shell_tab.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({
    super.key,
    required this.tab,
    required this.shift,
    required this.onCloseShift,
  });

  final ShellTab tab;
  final Shift? shift;
  final VoidCallback onCloseShift;

  String _formatUzs(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final posFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(' ');
    }
    return "${buffer.toString()} so'm";
  }

  @override
  Widget build(BuildContext context) {
    final totals = shift?.totals ?? ShiftTotals.zero;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: NocturneColors.bg,
        border: Border(bottom: BorderSide(color: NocturneColors.divider)),
      ),
      child: Row(
        children: [
          Text(tab.label, style: AppTextStyles.h4),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Smena tushumi',
                style: AppTextStyles.muted(
                  AppTextStyles.body,
                ).copyWith(fontSize: 11),
              ),
              Text(
                _formatUzs(totals.grandTotalUzs),
                style: AppTextStyles.h5.copyWith(color: NocturneColors.accent),
              ),
            ],
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: shift == null ? null : onCloseShift,
            icon: const Icon(PhosphorIconsRegular.lockKey, size: 16),
            label: const Text('Smenani yopish'),
          ),
        ],
      ),
    );
  }
}
