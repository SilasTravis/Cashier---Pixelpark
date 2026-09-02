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

Future<int?> showSaleRefundDialog(BuildContext context, SaleHistoryEntry sale) {
  final bloc = context.read<SalesHistoryBloc>();
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: _RefundSaleDialog(sale: sale),
    ),
  );
}

class _RefundSaleDialog extends StatefulWidget {
  const _RefundSaleDialog({required this.sale});

  final SaleHistoryEntry sale;

  @override
  State<_RefundSaleDialog> createState() => _RefundSaleDialogState();
}

class _RefundSaleDialogState extends State<_RefundSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  late SaleRefundMethod _method;
  int? _submittedAmount;

  @override
  void initState() {
    super.initState();
    _method = widget.sale.refundableCashUzs > 0
        ? SaleRefundMethod.cash
        : SaleRefundMethod.card;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  int get _limit => widget.sale.refundableFor(_method);
  int? get _amount => int.tryParse(_amountController.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return BlocConsumer<SalesHistoryBloc, SalesHistoryState>(
      listenWhen: (previous, current) =>
          previous.refundStatus != current.refundStatus ||
          previous.lastRefundedSaleId != current.lastRefundedSaleId,
      listener: (context, state) {
        if (state.refundStatus == SaleRefundSubmissionStatus.success &&
            state.lastRefundedSaleId == widget.sale.id) {
          Navigator.of(context).pop(_submittedAmount);
        }
      },
      builder: (context, state) {
        final submitting =
            state.refundStatus == SaleRefundSubmissionStatus.submitting &&
            state.refundingSaleId == widget.sale.id;
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
                  color: NocturneColors.danger.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  PhosphorIconsRegular.arrowUDownLeft,
                  color: NocturneColors.neutral200,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.refundTitle)),
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
                    Row(
                      children: [
                        Expanded(
                          child: _AmountSummary(
                            label: l10n.refundOriginalAmount,
                            value: widget.sale.totalUzs,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AmountSummary(
                            label: l10n.refundAlreadyAmount,
                            value: widget.sale.refundedUzs,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AmountSummary(
                            label: l10n.refundRemainingAmount,
                            value: widget.sale.refundableUzs,
                            emphasized: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.refundMethod,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<SaleRefundMethod>(
                      segments: [
                        if (widget.sale.refundableCashUzs > 0)
                          ButtonSegment(
                            value: SaleRefundMethod.cash,
                            icon: const Icon(
                              PhosphorIconsRegular.money,
                              size: 18,
                            ),
                            label: Text(
                              '${l10n.paymentCash} · ${formatUzs(widget.sale.refundableCashUzs)}',
                            ),
                          ),
                        if (widget.sale.refundableCardUzs > 0)
                          ButtonSegment(
                            value: SaleRefundMethod.card,
                            icon: const Icon(
                              PhosphorIconsRegular.creditCard,
                              size: 18,
                            ),
                            label: Text(
                              '${l10n.paymentCard} · ${formatUzs(widget.sale.refundableCardUzs)}',
                            ),
                          ),
                      ],
                      selected: {_method},
                      onSelectionChanged: submitting
                          ? null
                          : (selection) => setState(() {
                              _method = selection.first;
                              _amountController.clear();
                            }),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      enabled: !submitting,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l10n.refundAmount,
                        suffixText: "so'm",
                        helperText: '1 — ${formatUzs(_limit)}',
                        suffixIcon: TextButton(
                          onPressed: submitting
                              ? null
                              : () => setState(
                                  () => _amountController.text = '$_limit',
                                ),
                          child: Text(l10n.refundMax),
                        ),
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
                    TextFormField(
                      controller: _reasonController,
                      enabled: !submitting,
                      minLines: 2,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: l10n.refundReason,
                        hintText: l10n.refundReasonHint,
                        alignLabelWithHint: true,
                      ),
                      validator: (value) => (value ?? '').trim().length < 5
                          ? l10n.refundReasonValidation
                          : null,
                    ),
                    if (_method == SaleRefundMethod.card) ...[
                      const SizedBox(height: 4),
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
                              PhosphorIconsRegular.warning,
                              size: 19,
                              color: NocturneColors.accent300,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.refundCardWarning,
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
                    if (state.refundStatus ==
                            SaleRefundSubmissionStatus.failure &&
                        state.refundError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.refundError!,
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
              style: FilledButton.styleFrom(
                backgroundColor: NocturneColors.danger,
              ),
              onPressed: submitting ? null : _confirmAndSubmit,
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(PhosphorIconsRegular.arrowUDownLeft, size: 18),
              label: Text(l10n.refundAction),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = _amount!;
    final l10n = AppLocalization.of(context);
    final methodLabel = _method == SaleRefundMethod.cash
        ? l10n.paymentCash.toLowerCase()
        : l10n.paymentCard.toLowerCase();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmationContext) => AlertDialog(
        title: Text(l10n.refundConfirmTitle),
        content: Text(
          l10n.refundConfirmMessage(formatUzs(amount), methodLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmationContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NocturneColors.danger,
            ),
            onPressed: () => Navigator.pop(confirmationContext, true),
            child: Text(l10n.refundAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _submittedAmount = amount;
    context.read<SalesHistoryBloc>().add(
      SalesHistoryRefundRequested(
        saleId: widget.sale.id,
        amountUzs: amount,
        method: _method,
        reason: _reasonController.text.trim(),
        requestId: const Uuid().v4(),
      ),
    );
  }
}

class _AmountSummary extends StatelessWidget {
  const _AmountSummary({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: emphasized ? NocturneColors.accent900 : NocturneColors.neutral900,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: emphasized ? NocturneColors.accent700 : NocturneColors.divider,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.muted(AppTextStyles.body).copyWith(fontSize: 11),
        ),
        const SizedBox(height: 5),
        Text(
          formatUzs(value),
          maxLines: 1,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
