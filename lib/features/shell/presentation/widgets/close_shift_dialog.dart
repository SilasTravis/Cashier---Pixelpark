import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../shift/domain/shift.dart';
import '../../../shift/presentation/bloc/shift_bloc.dart';
import '../../../../generated/l10n.dart';

Future<void> showCloseShiftDialog(BuildContext context, Shift shift) {
  final bloc = context.read<ShiftBloc>();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final l10n = AppLocalization.of(dialogContext);
      return BlocProvider.value(
        value: bloc,
        child: BlocListener<ShiftBloc, ShiftState>(
          listenWhen: (previous, current) =>
              previous.lastClosed != current.lastClosed &&
              current.lastClosed != null,
          listener: (context, state) => Navigator.of(dialogContext).pop(),
          child: AlertDialog(
            backgroundColor: NocturneColors.surface,
            title: Text(l10n.shiftClose, style: AppTextStyles.h4),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(
                    label: l10n.receiptCount,
                    value: '${shift.totals.salesCount}',
                  ),
                  _SummaryRow(
                    label: l10n.paymentCash,
                    value: _uzs(shift.totals.cashUzs),
                  ),
                  _SummaryRow(
                    label: l10n.paymentCard,
                    value: _uzs(shift.totals.cardUzs),
                  ),
                  _SummaryRow(
                    label: l10n.balanceSalesNotIncome,
                    value: _uzs(shift.totals.balanceSalesUzs),
                  ),
                  const Divider(height: 20),
                  _SummaryRow(
                    label: l10n.shiftTotalIncome,
                    value: _uzs(shift.totals.grandTotalUzs),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
              BlocBuilder<ShiftBloc, ShiftState>(
                builder: (context, state) {
                  return FilledButton(
                    onPressed: state.isLoading
                        ? null
                        : () {
                            bloc.add(const ShiftCloseRequested());
                          },
                    child: state.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.close),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _uzs(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final posFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(' ');
  }
  return "${buffer.toString()} so'm";
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.muted(
              AppTextStyles.body,
            ).copyWith(fontSize: 13),
          ),
          Text(
            value,
            style: emphasize
                ? AppTextStyles.h5.copyWith(color: NocturneColors.accent)
                : AppTextStyles.body.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
