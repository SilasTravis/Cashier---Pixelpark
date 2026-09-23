import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/offline/app_mode_cubit.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../generated/l10n.dart';
import '../../data/offline_store.dart';
import '../../domain/offline_sale.dart';
import '../widgets/offline_sale_tile.dart';

/// Every sale of this cashier still on the till (spec D11): waiting or
/// rejected, with the reason and a code to read to support. Failed rows are
/// never deleted from here — only a successful Retry removes them.
class UnsyncedSalesPage extends StatelessWidget {
  const UnsyncedSalesPage({
    super.key,
    required this.store,
    required this.cashierId,
  });

  final OfflineStore store;
  final String? cashierId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return BlocBuilder<AppModeCubit, AppModeState>(
      buildWhen: (previous, current) => previous.mode != current.mode,
      builder: (context, mode) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final sales = cashierId == null
              ? const <OfflineSale>[]
              : store.sales(cashierId: cashierId).reversed.toList();
          if (sales.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsRegular.cloudCheck,
                    size: 40,
                    color: NocturneColors.success,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.unsyncedEmpty, style: AppTextStyles.h5),
                ],
              ),
            );
          }
          final online = !mode.isOffline;
          final cubit = context.read<AppModeCubit>();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        online
                            ? l10n.unsyncedHint
                            : l10n.unsyncedRetryNeedsOnline,
                        style: AppTextStyles.body,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: online ? () => cubit.retry() : null,
                      icon: const Icon(
                        PhosphorIconsRegular.cloudArrowUp,
                        size: 16,
                      ),
                      label: Text(l10n.unsyncedRetryAll),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: sales.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      return OfflineSaleTile(
                        sale: sale,
                        retryEnabled: online,
                        onRetry: () =>
                            cubit.retry(ids: {sale.offlineRequestId}),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
