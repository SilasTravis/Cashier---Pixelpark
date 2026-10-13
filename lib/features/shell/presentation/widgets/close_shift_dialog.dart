import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/local_source/local_source.dart';
import '../../../../core/offline/app_mode_cubit.dart';
import '../../../../core/printing/shift_report_printer.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../shift/domain/shift.dart';
import '../../../shift/presentation/bloc/shift_bloc.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';

Future<void> showCloseShiftDialog(BuildContext context, Shift shift) {
  final bloc = context.read<ShiftBloc>();
  final messenger = ScaffoldMessenger.of(context);
  // Fresh totals for the summary: the header's copy can lag a sale or two.
  bloc.add(const ShiftRefreshed());
  var printReport = true;
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
          listener: (context, state) {
            Navigator.of(dialogContext).pop();
            if (printReport) {
              _printShiftReport(state.lastClosed!, messenger, l10n);
            }
          },
          child: AlertDialog(
            backgroundColor: NocturneColors.surface,
            title: Text(l10n.shiftClose, style: AppTextStyles.h4),
            content: SizedBox(
              width: 340,
              child: BlocBuilder<ShiftBloc, ShiftState>(
                buildWhen: (previous, current) =>
                    previous.shift != current.shift ||
                    previous.errorMessage != current.errorMessage,
                builder: (context, state) => SingleChildScrollView(
                  child: _Summary(
                    shift: state.shift ?? shift,
                    errorMessage: state.errorMessage,
                  ),
                ),
              ),
            ),
            actions: [
              StatefulBuilder(
                builder: (context, setState) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      key: const Key('close-shift-print'),
                      value: printReport,
                      onChanged: (value) =>
                          setState(() => printReport = value ?? true),
                    ),
                    Text(l10n.shiftPrintReport, style: AppTextStyles.body),
                  ],
                ),
              ),
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

/// Prints the close-out check; the dialog is already gone, so a failure
/// is reported on the shell's snackbar.
Future<void> _printShiftReport(
  Shift closed,
  ScaffoldMessengerState messenger,
  AppLocalization l10n,
) async {
  var printed = false;
  try {
    final local = sl<LocalSource>();
    printed = await ShiftReportPrinter.printDirect(
      closed,
      branchName: local.getBranchName() ?? '',
      cashierName: local.getCashierFullName() ?? '',
      preferredPrinterName: local.getReceiptPrinterName(),
    );
  } catch (_) {
    printed = false;
  }
  if (!printed) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.receiptPrintFailed)));
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.shift, required this.errorMessage});

  final Shift shift;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final totals = shift.totals;
    final entries = totals.entries;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryRow(label: l10n.receiptCount, value: '${totals.salesCount}'),
        _SummaryRow(label: l10n.paymentCash, value: _uzs(totals.cashUzs)),
        _SummaryRow(label: l10n.paymentCard, value: _uzs(totals.cardUzs)),
        _SummaryRow(
          label: l10n.balanceSalesNotIncome,
          value: _uzs(totals.balanceSalesUzs),
        ),
        // Cash/card above already reflect the discounted (net) amounts —
        // this is purely informational, "how much was given away".
        if (totals.discountUzs > 0)
          _SummaryRow(
            label: l10n.discount,
            value: '−${_uzs(totals.discountUzs)}',
          ),
        // Cash and card above are already net of this; showing it explains
        // the gap when the cashier counts the drawer.
        if (totals.refundedUzs > 0)
          _SummaryRow(
            label: l10n.refundedTotal,
            value: '−${_uzs(totals.refundedUzs)}',
          ),
        const Divider(height: 20),
        _SummaryRow(
          label: l10n.shiftTotalIncome,
          value: _uzs(totals.grandTotalUzs),
          emphasize: true,
        ),
        if (entries != null) ...[
          const Divider(height: 20),
          _SummaryRow(
            label: l10n.shiftTicketsSold,
            value: l10n.shiftCountUnit(entries.ticketsCount),
            strong: true,
          ),
          for (final line in entries.tariffs)
            _SummaryRow(
              label: '   ${line.label}',
              value: l10n.shiftCountUnit(line.count),
            ),
          _SummaryRow(
            label: l10n.shiftVipTickets,
            value: l10n.shiftCountUnit(entries.vipCount),
          ),
          const Divider(height: 20),
          _SummaryRow(
            label: l10n.shiftUniqueChildren,
            value: l10n.shiftCountUnit(entries.uniqueChildren),
            strong: true,
          ),
          _SummaryRow(
            label: l10n.shiftEnteredChildren,
            value: l10n.shiftCountUnit(entries.enteredChildren),
          ),
        ],
        if (context.read<AppModeCubit>().state.failedCount case final failed
            when failed > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.closeShiftUnsyncedWarning(failed),
              style: AppTextStyles.body.copyWith(color: NocturneColors.warning),
            ),
          ),
        // Shows OFFLINE_SALES_PENDING (and any other close error), which
        // used to fail silently in this dialog.
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              errorMessage!,
              style: AppTextStyles.body.copyWith(color: NocturneColors.danger),
            ),
          ),
      ],
    );
  }
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
    this.strong = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  /// Bold section total (tickets, children) without the accent colour.
  final bool strong;

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
                : AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: strong ? FontWeight.w600 : null,
                  ),
          ),
        ],
      ),
    );
  }
}
