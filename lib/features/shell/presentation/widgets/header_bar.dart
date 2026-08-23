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
    final l10n = AppLocalization.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Container(
          height: compact ? 74 : 82,
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 22),
          decoration: const BoxDecoration(
            color: NocturneColors.bg,
            border: Border(bottom: BorderSide(color: NocturneColors.divider)),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: compact ? 26 : 30,
                decoration: BoxDecoration(
                  color: NocturneColors.accent,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: NocturneColors.accent.withValues(alpha: .24),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 180 : 320),
                child: Text(
                  tab.label(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4.copyWith(
                    fontSize: compact ? 19 : 22,
                    letterSpacing: -.25,
                  ),
                ),
              ),
              const Spacer(),
              const LanguageSwitcher(),
              const SizedBox(width: 12),
              Container(
                height: compact ? 54 : 60,
                padding: const EdgeInsets.fromLTRB(12, 6, 7, 6),
                decoration: BoxDecoration(
                  color: NocturneColors.accent900.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: NocturneColors.accent.withValues(alpha: .28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      PhosphorIconsRegular.wallet,
                      size: 18,
                      color: NocturneColors.accent300,
                    ),
                    const SizedBox(width: 9),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: compact ? 108 : 130,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.shiftRevenue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.kicker.copyWith(
                              fontSize: 10,
                              color: NocturneColors.neutral400,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            formatUzs(totals.grandTotalUzs),
                            maxLines: 1,
                            style: AppTextStyles.h4.copyWith(
                              color: NocturneColors.accent200,
                              fontSize: compact ? 17 : 20,
                              letterSpacing: .15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    IconButton(
                      tooltip: l10n.refresh,
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: NocturneColors.accent300,
                      ),
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
              ),
            ],
          ),
        );
      },
    );
  }
}
