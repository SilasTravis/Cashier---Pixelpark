import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../../shift/domain/shift.dart';
import '../../../shift/presentation/bloc/shift_bloc.dart';

/// "Smena tushumi" in the top bar: the open shift's takings in a soft-blue
/// card, with a refresh button that reloads the shift.
class ShiftRevenueChip extends StatelessWidget {
  const ShiftRevenueChip({
    super.key,
    required this.shift,
    this.compact = false,
  });

  final Shift? shift;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final totals = shift?.totals ?? ShiftTotals.zero;
    final l10n = AppLocalization.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: NocturneColors.accent900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NocturneColors.accent800),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            const Icon(
              PhosphorIconsRegular.wallet,
              size: 18,
              color: NocturneColors.accent,
            ),
            const SizedBox(width: 9),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.shiftRevenue.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.kicker.copyWith(
                  fontSize: 9.5,
                  color: NocturneColors.accent,
                ),
              ),
              Text(
                formatUzs(totals.grandTotalUzs),
                maxLines: 1,
                style: AppTextStyles.h4.copyWith(
                  color: NocturneColors.accent300,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: l10n.refresh,
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                context.read<ShiftBloc>().add(const ShiftRefreshed()),
            icon: const Icon(
              PhosphorIconsRegular.arrowsClockwise,
              size: 16,
              color: NocturneColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
