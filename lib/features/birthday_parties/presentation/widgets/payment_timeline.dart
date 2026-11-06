import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_party.dart';

/// Payments and refunds, oldest first: date · source · cashier · amount.
class PaymentTimeline extends StatelessWidget {
  const PaymentTimeline({super.key, required this.payments});

  final List<BirthdayPartyPayment> payments;

  String _source(AppLocalization l10n, BirthdayPartyPayment pay) {
    if (pay.kind == BirthdayPaymentKind.refund) {
      return pay.refundTo == 'cash'
          ? l10n.bdRefundToCash
          : l10n.bdRefundToBalance;
    }
    return [
      if (pay.fromBalanceUzs > 0) l10n.balance,
      if (pay.cashUzs > 0) l10n.paymentCash,
      if (pay.cardUzs > 0) l10n.paymentCard,
    ].join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final df = DateFormat('dd.MM HH:mm');
    final sorted = [...payments]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.bdPayments.toUpperCase(), style: p.kicker),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          Text(l10n.bdNoPayments, style: p.bodyMuted)
        else
          for (final pay in sorted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      df.format(pay.createdAt.toLocal()),
                      style: p.bodyMuted.copyWith(fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      [
                        _source(l10n, pay),
                        if (pay.cashierUsername != null) pay.cashierUsername!,
                      ].join(' · '),
                      style: p.body.copyWith(fontSize: 14),
                    ),
                  ),
                  Text(
                    pay.kind == BirthdayPaymentKind.refund
                        ? '− ${formatUzs(pay.amountUzs)}'
                        : '+ ${formatUzs(pay.amountUzs)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: pay.kind == BirthdayPaymentKind.refund
                          ? p.danger
                          : p.positive,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
