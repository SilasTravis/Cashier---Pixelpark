import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../shift/domain/shift.dart';
import '../../../shift/presentation/bloc/shift_bloc.dart';
import '../model/shell_tab.dart';
import '../../../../generated/l10n.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key, required this.tab, required this.shift});

  final ShellTab tab;
  final Shift? shift;

  @override
  Widget build(BuildContext context) {
    final totals = shift?.totals ?? ShiftTotals.zero;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: NocturneColors.bg,
        border: Border(bottom: BorderSide(color: NocturneColors.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: NocturneColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              tab.label(AppLocalization.of(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h4,
            ),
          ),
          const Spacer(),
          const LanguageSwitcher(),
          const SizedBox(width: 10),
          // Totals are aggregated on the BACKEND per fetch — the app never
          // adds to them locally, so without a re-fetch the number goes
          // stale after every sale/top-up. Silent refresh: no page spinner.
          IconButton(
            tooltip: AppLocalization.of(context).refresh,
            onPressed: () =>
                context.read<ShiftBloc>().add(const ShiftRefreshed()),
            icon: const Icon(
              PhosphorIconsRegular.arrowsClockwise,
              size: 16,
              color: NocturneColors.accent,
            ),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalization.of(context).shiftRevenue,
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
