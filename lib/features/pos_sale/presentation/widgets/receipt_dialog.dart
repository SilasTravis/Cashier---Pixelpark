import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/sale_receipt.dart';

Future<void> showReceiptDialog(BuildContext context, SaleReceipt receipt) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: NocturneColors.surface,
        title: const Text('Chek', style: AppTextStyles.h4),
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
                label: 'Jami',
                value: formatUzs(receipt.subtotalUzs),
                emphasize: true,
              ),
              _SummaryRow(label: 'Naqd', value: formatUzs(receipt.cashUzs)),
              _SummaryRow(label: 'Karta', value: formatUzs(receipt.cardUzs)),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Yopish'),
          ),
        ],
      );
    },
  );
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
