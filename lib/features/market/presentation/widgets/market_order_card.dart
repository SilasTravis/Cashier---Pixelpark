import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/market_order.dart';

String marketStatusLabel(AppLocalization l10n, MarketOrderStatus status) =>
    switch (status) {
      MarketOrderStatus.placed => l10n.marketStatusPlaced,
      MarketOrderStatus.confirmed => l10n.marketStatusConfirmed,
      MarketOrderStatus.handedOver => l10n.marketStatusHandedOver,
      MarketOrderStatus.atBranch => l10n.marketStatusAtBranch,
      MarketOrderStatus.pickedUp => l10n.marketStatusPickedUp,
      MarketOrderStatus.cancelled => l10n.marketStatusCancelled,
      MarketOrderStatus.unknown => '—',
    };

class MarketStatusChip extends StatelessWidget {
  const MarketStatusChip({super.key, required this.status});
  final MarketOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MarketOrderStatus.atBranch ||
      MarketOrderStatus.pickedUp => NocturneColors.success,
      MarketOrderStatus.handedOver => NocturneColors.warning,
      MarketOrderStatus.cancelled => NocturneColors.danger,
      _ => NocturneColors.neutral400,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        marketStatusLabel(AppLocalization.of(context), status),
        style: AppTextStyles.body.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// One shop's part of the parent's pickup: shop, status, each line with its
/// quantity, the shop total, and "Qabul qilish" while the parcel is still
/// marked as sent by the shop.
class MarketPickupOrderCard extends StatelessWidget {
  const MarketPickupOrderCard({
    super.key,
    required this.order,
    required this.receiving,
    required this.onReceive,
  });

  final MarketOrder order;
  final bool receiving;

  /// Null while another action runs.
  final VoidCallback? onReceive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: order.status == MarketOrderStatus.handedOver
              ? NocturneColors.warning.withValues(alpha: .5)
              : NocturneColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.storefront,
                size: 20,
                color: NocturneColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h5,
                ),
              ),
              Text(
                l10n.marketOrderNumber(order.orderNumber),
                style: AppTextStyles.muted(
                  AppTextStyles.body.copyWith(fontSize: 12),
                ),
              ),
              const SizedBox(width: 10),
              MarketStatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: NocturneColors.accent900,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '×${item.quantity}',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: NocturneColors.accent300,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.variantLabel.isEmpty
                          ? item.productName
                          : '${item.productName} · ${item.variantLabel}',
                      style: AppTextStyles.body,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatUzs(item.lineTotalUzs),
                    style: AppTextStyles.muted(AppTextStyles.body),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          Row(
            children: [
              Text(
                '${l10n.marketTotal}: ${formatUzs(order.itemsTotalUzs)}',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (order.status == MarketOrderStatus.handedOver)
                FilledButton.tonalIcon(
                  onPressed: receiving ? null : onReceive,
                  icon: receiving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(PhosphorIconsRegular.package, size: 17),
                  label: Text(l10n.marketReceive),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
