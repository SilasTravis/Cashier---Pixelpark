import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../generated/l10n.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/nocturne_colors.dart';
import '../app_mode_cubit.dart';

/// Amber strip above the header whenever the till isn't online: how many
/// sales wait, and the manual "Onlaynni tekshirish" button (spec D12).
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    final reachable = await context.read<AppModeCubit>().checkOnlineNow();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!reachable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalization.of(context).stillOffline)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return BlocBuilder<AppModeCubit, AppModeState>(
      builder: (context, state) {
        if (!state.isOffline) return const SizedBox.shrink();
        final syncing = state.mode == AppMode.syncing;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: NocturneColors.warning.withValues(alpha: .14),
            border: const Border(
              bottom: BorderSide(color: NocturneColors.warning),
            ),
          ),
          child: Row(
            children: [
              syncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NocturneColors.warning,
                      ),
                    )
                  : const Icon(
                      PhosphorIconsRegular.wifiSlash,
                      size: 16,
                      color: NocturneColors.warning,
                    ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  syncing
                      ? l10n.offlineBannerSyncing
                      : l10n.offlineBanner(state.queuedCount),
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: NocturneColors.warning,
                  ),
                ),
              ),
              if (!syncing)
                TextButton.icon(
                  onPressed: _checking ? null : _check,
                  icon: _checking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          PhosphorIconsRegular.arrowClockwise,
                          size: 16,
                        ),
                  label: Text(l10n.checkOnline),
                ),
            ],
          ),
        );
      },
    );
  }
}
