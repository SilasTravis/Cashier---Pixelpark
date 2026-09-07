import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/sale_history.dart';
import '../bloc/sales_history_bloc.dart';

/// Opens the payment-method correction for [sale]. Returns true once the
/// correction has been recorded.
Future<bool?> showCorrectPaymentDialog(
  BuildContext context,
  SaleHistoryEntry sale,
) {
  final bloc = context.read<SalesHistoryBloc>();
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: _CorrectPaymentDialog(sale: sale),
    ),
  );
}

/// Fixes a receipt rung up under the wrong method: the cashier took cash and
/// marked it card, or the reverse. Nothing is handed back and the total never
/// moves — only which column holds the money, which is what the shift cash-up
/// is reconciled against.
class _CorrectPaymentDialog extends StatefulWidget {
  const _CorrectPaymentDialog({required this.sale});

  final SaleHistoryEntry sale;

  @override
  State<_CorrectPaymentDialog> createState() => _CorrectPaymentDialogState();
}

class _CorrectPaymentDialogState extends State<_CorrectPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  late SalePaymentMoveMethod _from;

  @override
  void initState() {
    super.initState();
    // Default to whichever column actually holds money — usually the one rung
    // up by mistake, so the cashier only has to confirm.
    _from = widget.sale.cardUzs > 0
        ? SalePaymentMoveMethod.card
        : SalePaymentMoveMethod.cash;
    _amountController.text = '${widget.sale.movableFor(_from)}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  SalePaymentMoveMethod get _to => _from == SalePaymentMoveMethod.cash
      ? SalePaymentMoveMethod.card
      : SalePaymentMoveMethod.cash;

  int get _limit => widget.sale.movableFor(_from);
  int get _amount => int.tryParse(_amountController.text) ?? 0;

  int get _resultCash =>
      widget.sale.cashUzs +
      (_to == SalePaymentMoveMethod.cash ? _amount : -_amount);

  int get _resultCard =>
      widget.sale.cardUzs +
      (_to == SalePaymentMoveMethod.card ? _amount : -_amount);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return BlocConsumer<SalesHistoryBloc, SalesHistoryState>(
      listenWhen: (previous, current) =>
          previous.actionStatus != current.actionStatus ||
          previous.lastActedSaleId != current.lastActedSaleId,
      listener: (context, state) {
        if (state.actionStatus == SaleActionStatus.success &&
            state.lastActedSaleId == widget.sale.id) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting =
            state.actionStatus == SaleActionStatus.submitting &&
            state.actingSaleId == widget.sale.id;
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                  PhosphorIconsRegular.arrowsLeftRight,
                  color: NocturneColors.neutral200,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.correctPaymentTitle)),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Banner(text: l10n.correctPaymentHint),
                    const SizedBox(height: 16),
                    Text(
                      l10n.correctPaymentFrom,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<SalePaymentMoveMethod>(
                      segments: [
                        for (final method in SalePaymentMoveMethod.values)
                          ButtonSegment(
                            value: method,
                            enabled: widget.sale.movableFor(method) > 0,
                            icon: Icon(_icon(method), size: 18),
                            label: Text(
                              '${_label(l10n, method)} · '
                              '${formatUzs(widget.sale.movableFor(method))}',
                            ),
                          ),
                      ],
                      selected: {_from},
                      onSelectionChanged: submitting
                          ? null
                          : (selection) => setState(() {
                              _from = selection.first;
                              _amountController.text = '$_limit';
                            }),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _amountController,
                      enabled: !submitting,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.correctPaymentAmount,
                        suffixText: "so'm",
                        helperText:
                            '${l10n.correctPaymentTo}: ${_label(l10n, _to)} · 1 — ${formatUzs(_limit)}',
                      ),
                      validator: (value) {
                        final amount = int.tryParse(value ?? '');
                        if (amount == null || amount < 1 || amount > _limit) {
                          return '1 — ${formatUzs(_limit)}';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _Banner(
                      icon: PhosphorIconsRegular.equals,
                      text: l10n.correctPaymentResult(
                        formatUzs(_resultCash),
                        formatUzs(_resultCard),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _reasonController,
                      enabled: !submitting,
                      minLines: 2,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: l10n.correctPaymentReason,
                        hintText: l10n.correctPaymentReasonHint,
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => (value ?? '').trim().length < 5
                          ? l10n.refundReasonValidation
                          : null,
                    ),
                    if (state.actionStatus == SaleActionStatus.failure &&
                        state.actionError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.actionError!,
                        style: const TextStyle(color: NocturneColors.danger),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton.icon(
              onPressed: submitting ? null : _confirmAndSubmit,
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(PhosphorIconsRegular.check, size: 18),
              label: Text(l10n.correctPaymentAction),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndSubmit() async {
    final l10n = AppLocalization.of(context);
    if (!_formKey.currentState!.validate()) return;
    final amount = _amount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmationContext) => AlertDialog(
        title: Text(l10n.correctPaymentConfirmTitle),
        content: Text(
          l10n.correctPaymentConfirmMessage(
            formatUzs(amount),
            _label(l10n, _from).toLowerCase(),
            _label(l10n, _to).toLowerCase(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmationContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(confirmationContext, true),
            child: Text(l10n.correctPaymentAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    context.read<SalesHistoryBloc>().add(
      SalesHistoryPaymentCorrectionRequested(
        saleId: widget.sale.id,
        fromMethod: _from,
        toMethod: _to,
        amountUzs: amount,
        reason: _reasonController.text.trim(),
        requestId: const Uuid().v4(),
      ),
    );
  }

  IconData _icon(SalePaymentMoveMethod method) => switch (method) {
    SalePaymentMoveMethod.cash => PhosphorIconsRegular.money,
    SalePaymentMoveMethod.card => PhosphorIconsRegular.creditCard,
  };

  String _label(AppLocalization l10n, SalePaymentMoveMethod method) =>
      switch (method) {
        SalePaymentMoveMethod.cash => l10n.paymentCash,
        SalePaymentMoveMethod.card => l10n.paymentCard,
      };
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.icon = PhosphorIconsRegular.info});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: NocturneColors.accent900,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: NocturneColors.accent700),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: NocturneColors.accent300),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(
              fontSize: 12,
              color: NocturneColors.neutral200,
            ),
          ),
        ),
      ],
    ),
  );
}
