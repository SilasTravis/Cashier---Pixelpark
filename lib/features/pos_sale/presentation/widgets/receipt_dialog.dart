import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/local_source/local_source.dart';
import '../../../../core/printing/sale_receipt_printer.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/receipt_id.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../domain/sale_receipt.dart';

Future<void> showReceiptDialog(BuildContext context, SaleReceipt receipt) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _ReceiptDialog(receipt: receipt);
    },
  );
}

Future<bool> printSaleReceiptDirect(
  BuildContext context,
  SaleReceipt receipt,
) async {
  try {
    final local = sl<LocalSource>();
    final printed = await SaleReceiptPrinter.printDirect(
      receipt,
      branchName: local.getBranchName() ?? '',
      cashierName: local.getCashierFullName() ?? '',
      preferredPrinterName: local.getReceiptPrinterName(),
    );
    if (!printed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalization.of(context).receiptPrintFailed)),
      );
    }
    return printed;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalization.of(context).receiptPrintFailed)),
      );
    }
    return false;
  }
}

class _ReceiptDialog extends StatefulWidget {
  const _ReceiptDialog({required this.receipt});

  final SaleReceipt receipt;

  @override
  State<_ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<_ReceiptDialog> {
  bool _isPrinting = false;

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    await printSaleReceiptDirect(context, widget.receipt);
    if (mounted) setState(() => _isPrinting = false);
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    return AlertDialog(
      backgroundColor: NocturneColors.surface,
      title: Text(
        '${AppLocalization.of(context).receipt}  #${formatReceiptId(receipt.id)}',
        style: AppTextStyles.h4,
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in receipt.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.nameSnapshot} × ${item.qty}',
                        style: AppTextStyles.body.copyWith(fontSize: 13),
                      ),
                    ),
                    Text(
                      formatUzs(item.lineTotalUzs),
                      style: AppTextStyles.body.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            const Divider(height: 20),
            _SummaryRow(
              label: AppLocalization.of(context).total,
              value: formatUzs(receipt.subtotalUzs),
              emphasize: true,
            ),
            _SummaryRow(
              label: AppLocalization.of(context).paymentCash,
              value: formatUzs(receipt.cashUzs),
            ),
            _SummaryRow(
              label: AppLocalization.of(context).paymentCard,
              value: formatUzs(receipt.cardUzs),
            ),
          ],
        ),
      ),
      actions: [
        if (SaleReceiptPrinter.hasPrintableProducts(receipt))
          OutlinedButton.icon(
            onPressed: _isPrinting ? null : _print,
            icon: _isPrinting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(PhosphorIconsRegular.printer, size: 16),
            label: Text(
              _isPrinting
                  ? AppLocalization.of(context).printing
                  : AppLocalization.of(context).printReceipt,
            ),
          ),
        FilledButton(
          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalization.of(context).close),
        ),
      ],
    );
  }
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
      padding: const EdgeInsets.symmetric(vertical: 3),
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
