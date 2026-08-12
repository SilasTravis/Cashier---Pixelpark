import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../bloc/pos_account_bloc.dart';

void showNewCustomerDialog(BuildContext context) {
  final bloc = context.read<PosAccountBloc>();
  final controller = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return BlocProvider.value(
        value: bloc,
        child: BlocListener<PosAccountBloc, PosAccountState>(
          listenWhen: (previous, current) =>
              previous.selectedCustomer != current.selectedCustomer &&
              current.selectedCustomer != null,
          listener: (context, state) => Navigator.of(dialogContext).pop(),
          child: AlertDialog(
            backgroundColor: NocturneColors.surface,
            title: const Text('Yangi mijoz', style: AppTextStyles.h4),
            content: SizedBox(
              width: 320,
              child: TextField(
                controller: controller,
                autofocus: true,
                style: AppTextStyles.body,
                decoration: const InputDecoration(labelText: 'Ism familiya'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Bekor qilish'),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  return BlocBuilder<PosAccountBloc, PosAccountState>(
                    builder: (context, state) {
                      return FilledButton(
                        onPressed: state.isBusy || value.text.trim().isEmpty
                            ? null
                            : () => bloc.add(
                                PosAccountNewCustomerRequested(
                                  value.text.trim(),
                                ),
                              ),
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
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
