import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/offline_sale.dart';

/// One queued offline sale — used by the Unsynced page (with Retry and the
/// support code) and by the history section (with a "not synced" badge).
class OfflineSaleTile extends StatelessWidget {
  const OfflineSaleTile({
    super.key,
    required this.sale,
    this.onRetry,
    this.badgeLabel,
    this.showSupportDetails = true,
    this.retryEnabled = true,
  });

  final OfflineSale sale;
  final VoidCallback? onRetry;

  /// Overrides the pending/failed chip (history shows "Sinxronlanmagan").
  final String? badgeLabel;
  final bool showSupportDetails;

  /// False renders Retry disabled (offline) instead of hiding it.
  final bool retryEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final chipColor = sale.isFailed
        ? NocturneColors.danger
        : NocturneColors.warning;
    final chipText =
        badgeLabel ??
        (sale.isFailed ? l10n.unsyncedFailed : l10n.unsyncedPending);
    final items = sale.lines.map((l) => '${l.name} ×${l.qty}').join(', ');
    final payment = [
      if (sale.cashUzs > 0) l10n.paymentCash,
      if (sale.cardUzs > 0) l10n.paymentCard,
    ].join(' + ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: chipColor.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat(
                        'dd.MM.yyyy HH:mm',
                      ).format(sale.createdAt.toLocal()),
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        chipText,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 11,
                          color: chipColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(items, style: AppTextStyles.body),
                if (showSupportDetails) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SelectableText(
                        l10n.unsyncedSupportCode(sale.supportCode),
                        style: AppTextStyles.body.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        icon: const Icon(PhosphorIconsRegular.copy),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: sale.supportCode),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.unsyncedCodeCopied)),
                          );
                        },
                      ),
                    ],
                  ),
                ],
                if (sale.isFailed && sale.failureMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    sale.failureMessage!,
                    style: AppTextStyles.body.copyWith(
                      color: NocturneColors.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatUzs(sale.totalUzs),
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(payment, style: AppTextStyles.body.copyWith(fontSize: 11)),
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: retryEnabled ? onRetry : null,
                  icon: const Icon(
                    PhosphorIconsRegular.arrowClockwise,
                    size: 14,
                  ),
                  label: Text(l10n.unsyncedRetry),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
