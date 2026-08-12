import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../shift/presentation/bloc/shift_bloc.dart';

/// Blocks POS actions until a shift is open — shown as a non-dismissible
/// overlay right after login (and after a shift close) rather than a modal
/// dialog, since there is nothing useful to see behind it yet.
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

  @override
  Widget build(BuildContext context) {
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
                    const Text('Smenani boshlash', style: AppTextStyles.h3),
                    const SizedBox(height: 4),
                    Text(
                      "Ishni boshlash uchun kassadagi boshlang'ich naqd summani kiriting",
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
                      decoration: const InputDecoration(
                        labelText: "Boshlang'ich naqd (so'm)",
                        prefixIcon: Icon(PhosphorIconsRegular.wallet, size: 18),
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
                            : const Text('Smenani ochish'),
                      ),
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
