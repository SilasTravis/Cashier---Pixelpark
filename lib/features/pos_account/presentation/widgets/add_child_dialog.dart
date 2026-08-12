import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../bloc/pos_account_bloc.dart';

void showAddChildDialog(BuildContext context) {
  final bloc = context.read<PosAccountBloc>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  DateTime? birthDate;

  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return BlocProvider.value(
            value: bloc,
            child: BlocListener<PosAccountBloc, PosAccountState>(
              listenWhen: (previous, current) =>
                  previous.selectedCustomer?.children.length !=
                  current.selectedCustomer?.children.length,
              listener: (context, state) => Navigator.of(dialogContext).pop(),
              child: AlertDialog(
                backgroundColor: NocturneColors.surface,
                title: const Text('Farzand qo\'shish', style: AppTextStyles.h4),
                content: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: firstNameController,
                        autofocus: true,
                        style: AppTextStyles.body,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Ismi'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: lastNameController,
                        style: AppTextStyles.body,
                        decoration: const InputDecoration(
                          labelText: 'Familiyasi (ixtiyoriy)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().subtract(
                              const Duration(days: 365 * 4),
                            ),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365 * 18),
                            ),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => birthDate = picked);
                          }
                        },
                        child: Text(
                          birthDate == null
                              ? 'Tug\'ilgan sana'
                              : '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Bekor qilish'),
                  ),
                  BlocBuilder<PosAccountBloc, PosAccountState>(
                    builder: (context, state) {
                      final canSubmit =
                          !state.isBusy &&
                          firstNameController.text.trim().isNotEmpty &&
                          birthDate != null;
                      return FilledButton(
                        onPressed: canSubmit
                            ? () {
                                final birth = birthDate!;
                                final iso =
                                    '${birth.year}-${birth.month.toString().padLeft(2, '0')}-${birth.day.toString().padLeft(2, '0')}';
                                bloc.add(
                                  PosAccountChildAddRequested(
                                    firstName: firstNameController.text.trim(),
                                    lastName:
                                        lastNameController.text.trim().isEmpty
                                        ? null
                                        : lastNameController.text.trim(),
                                    birthDate: iso,
                                  ),
                                );
                              }
                            : null,
                        child: state.isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Qo\'shish'),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
