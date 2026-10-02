import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../generated/l10n.dart';
import '../../data/offline_store.dart';
import '../../domain/offline_sale.dart';
import 'offline_sale_tile.dart';

/// Queued offline sales at the top of the history tab (spec D9), badged
/// "Sinxronlanmagan". [expand]: offline, this IS the whole history.
class OfflineHistorySection extends StatelessWidget {
  const OfflineHistorySection({
    super.key,
    required this.store,
    required this.cashierId,
    this.expand = false,
  });

  final OfflineStore store;
  final String? cashierId;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final sales = cashierId == null
            ? const <OfflineSale>[]
            : store.sales(cashierId: cashierId).reversed.toList();
        if (sales.isEmpty && !expand) return const SizedBox.shrink();
        final list = ListView.separated(
          shrinkWrap: !expand,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          itemCount: sales.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, index) => OfflineSaleTile(
            sale: sales[index],
            badgeLabel: l10n.notSyncedBadge,
            showSupportDetails: false,
          ),
        );
        final header = Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(
                PhosphorIconsRegular.cloudArrowUp,
                size: 16,
                color: NocturneColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                '${l10n.notSyncedBadge} (${sales.length})',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
        return expand
            ? Column(
                children: [
                  header,
                  Expanded(child: list),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  header,
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: list,
                  ),
                ],
              );
      },
    );
  }
}
