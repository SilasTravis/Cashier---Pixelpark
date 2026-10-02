import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../../generated/l10n.dart';
import '../../domain/customer.dart';

/// Asks the cashier to confirm a balance top-up before the money moves.
///
/// The button used to fire straight into the request. Money that lands on a
/// customer's balance can only be taken off again with a refund, so the last
/// step now restates who is being credited, how much, by which method, and
/// what the balance becomes — and takes a second, deliberate tap.
Future<bool?> showConfirmTopupDialog(
  BuildContext context, {
  required Customer customer,
  required int amountUzs,
  required int cashUzs,
  required int cardUzs,
  required PaymentMethod method,
}) {
  final l10n = AppLocalization.of(context);
  final methodLabel = switch (method) {
    PaymentMethod.cash => l10n.paymentCash,
    PaymentMethod.card => l10n.paymentCard,
    PaymentMethod.split =>
      '${l10n.paymentCash} ${formatUzs(cashUzs)} + '
          '${l10n.paymentCard} ${formatUzs(cardUzs)}',
  };

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: NocturneColors.accent900,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              PhosphorIconsRegular.wallet,
              color: NocturneColors.neutral200,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.topupConfirmTitle)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Row(label: l10n.topupConfirmCustomer, value: customer.fullName),
            _Row(label: l10n.phoneNumber, value: customer.phoneNumber),
            const Divider(height: 22),
            _Row(
              label: l10n.topupConfirmAmount,
              value: formatUzs(amountUzs),
              emphasized: true,
            ),
            _Row(label: l10n.topupConfirmMethod, value: methodLabel),
            _Row(label: l10n.balance, value: formatUzs(customer.balance)),
            _Row(
              label: l10n.topupConfirmNewBalance,
              value: formatUzs(customer.balance + amountUzs),
              emphasized: true,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NocturneColors.accent900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NocturneColors.accent700),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    PhosphorIconsRegular.info,
                    size: 19,
                    color: NocturneColors.accent300,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.topupConfirmWarning,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        color: NocturneColors.neutral200,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(PhosphorIconsRegular.check, size: 18),
          label: Text(l10n.topupConfirmAction),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.muted(AppTextStyles.body)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: emphasized
                ? AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: NocturneColors.accent,
                  )
                : AppTextStyles.body,
          ),
        ),
      ],
    ),
  );
}
