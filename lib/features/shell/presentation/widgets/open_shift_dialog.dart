import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../injector_container.dart';
import '../../../../router/app_navigator.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../shift/presentation/bloc/shift_bloc.dart';
import '../../../../generated/l10n.dart';

/// Blocks POS actions until a shift is open — shown as a non-dismissible
/// overlay right after login (and after a shift close) rather than a modal
/// dialog, since there is nothing useful to see behind it yet. The sidebar
/// (and its Settings/logout tab) isn't reachable while this is showing, so
/// logout lives here too — otherwise a cashier stuck on the wrong account
/// has no way out short of force-quitting.
class OpenShiftPrompt extends StatefulWidget {
  const OpenShiftPrompt({super.key});

  @override
  State<OpenShiftPrompt> createState() => _OpenShiftPromptState();
}

class _OpenShiftPromptState extends State<OpenShiftPrompt> {
  final _cashController = TextEditingController();

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    await sl<AuthRepository>().logout();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(Routes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Container(
      color: NocturneColors.bg,
      child: Center(
        child: BlocBuilder<ShiftBloc, ShiftState>(
          builder: (context, state) {
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: NocturneColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        PhosphorIconsRegular.cashRegister,
                        color: NocturneColors.accent,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.shiftStart, style: AppTextStyles.h3),
                    const SizedBox(height: 4),
                    Text(
                      l10n.shiftStartHint,
                      style: AppTextStyles.body.copyWith(
                        color: NocturneColors.text.withValues(alpha: 0.55),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _cashController,
                      style: AppTextStyles.body,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.shiftOpeningCash,
                        prefixIcon: const Icon(
                          PhosphorIconsRegular.wallet,
                          size: 18,
                        ),
                      ),
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          color: NocturneColors.danger,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: state.isLoading
                            ? null
                            : () {
                                final raw = _cashController.text.trim();
                                context.read<ShiftBloc>().add(
                                  ShiftOpenRequested(
                                    openingCashUzs: raw.isEmpty
                                        ? null
                                        : int.parse(raw),
                                  ),
                                );
                              },
                        child: state.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: NocturneColors.accent,
                                ),
                              )
                            : Text(l10n.shiftOpen),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : () => _logout(context),
                      icon: const Icon(PhosphorIconsRegular.signOut, size: 14),
                      label: Text(l10n.logout),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
