import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/local_source/local_source.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../injector_container.dart';
import '../../../../router/app_navigator.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

/// The design's sidebar has no logout affordance (just a bare "Kassa 2 ·
/// Zaira" label) — this app needs one, so it lives here instead: cashier +
/// branch identity, app version, and the sign-out action.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await sl<AuthRepository>().logout();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(Routes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final local = sl<LocalSource>();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NocturneColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadow.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: NocturneColors.accent.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          (local.getCashierFullName() ?? '?').isEmpty
                              ? '?'
                              : local.getCashierFullName()![0].toUpperCase(),
                          style: const TextStyle(
                            color: NocturneColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              local.getCashierFullName() ?? '',
                              style: AppTextStyles.h5,
                            ),
                            Text(
                              '@${local.getCashierUsername() ?? ''}',
                              style: AppTextStyles.muted(
                                AppTextStyles.body,
                              ).copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _InfoRow(label: 'Filial', value: local.getBranchName() ?? ''),
                  const SizedBox(height: 10),
                  _AppVersionRow(),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(PhosphorIconsRegular.signOut, size: 16),
                label: const Text("Chiqish"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.muted(AppTextStyles.body)),
        const Spacer(),
        Text(value, style: AppTextStyles.body.copyWith(fontSize: 14)),
      ],
    );
  }
}

class _AppVersionRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '—';
        return _InfoRow(label: 'Versiya', value: version);
      },
    );
  }
}
