import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../shift/domain/shift.dart';
import '../model/shell_tab.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key, required this.tab, required this.shift});

  final ShellTab tab;
  final Shift? shift;

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
                style: AppTextStyles.kicker.copyWith(
                  color: NocturneColors.text.withValues(alpha: 0.45),
                ),
              ),
              Text(
                formatUzs(totals.grandTotalUzs),
                style: AppTextStyles.h4.copyWith(color: NocturneColors.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
