import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/offline/app_mode_cubit.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../../../router/app_navigator.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

/// Settings' sign-out action, guarded by the offline queue: pending sales
/// (still sendable) block it; failed ones — which are never deleted and so
/// could block it forever — only ask for confirmation. Either way the
/// queue lives in its own Hive box and survives the sign-out.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _logout(BuildContext context) async {
    final l10n = AppLocalization.of(context);
    final mode = context.read<AppModeCubit>().state;
    if (mode.pendingCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.logoutBlockedUnsynced(mode.pendingCount))),
      );
      return;
    }
    if (mode.failedCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: NocturneColors.surface,
          icon: const Icon(
            PhosphorIconsRegular.warning,
            color: NocturneColors.warning,
            size: 32,
          ),
          content: SizedBox(
            width: 360,
            child: Text(
              l10n.logoutFailedSalesConfirm(mode.failedCount),
              style: AppTextStyles.body,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.logoutAnyway),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    await sl<AuthRepository>().logout();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(Routes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: OutlinedButton.icon(
      onPressed: () => _logout(context),
      icon: const Icon(PhosphorIconsRegular.signOut, size: 16),
      label: Text(AppLocalization.of(context).logout),
    ),
  );
}
