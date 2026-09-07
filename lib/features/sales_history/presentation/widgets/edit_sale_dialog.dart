import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/sale_edit_plan.dart';
import '../../domain/sale_history.dart';
import '../bloc/sales_history_bloc.dart';

/// Opens the receipt editor for [sale]. Returns true once the edit ran.
Future<bool?> showEditSaleDialog(BuildContext context, SaleHistoryEntry sale) {
  final bloc = context.read<SalesHistoryBloc>();
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: _EditSaleDialog(sale: sale),
    ),
  );
}

/// One place to fix a mis-rung receipt: the cashier says what the total and
/// the method SHOULD have been, and the steps needed to get there are derived
/// and spelled out before anything is written. Under the hood those steps are
/// the existing column move and refund, each separately audited.
class _EditSaleDialog extends StatefulWidget {
  const _EditSaleDialog({required this.sale});

  final SaleHistoryEntry sale;

  @override
  State<_EditSaleDialog> createState() => _EditSaleDialogState();
}

class _EditSaleDialogState extends State<_EditSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _totalController = TextEditingController();
  final _reasonController = TextEditingController();
  late SalePaymentMoveMethod _method;

  int get _physicalUzs => widget.sale.cashUzs + widget.sale.cardUzs;

  @override
  void initState() {
    super.initState();
    _totalController.text = '$_physicalUzs';
    _method = widget.sale.cardUzs > 0
        ? SalePaymentMoveMethod.card
        : SalePaymentMoveMethod.cash;
  }

  @override
  void dispose() {
    _totalController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  int get _target => int.tryParse(_totalController.text) ?? 0;

  SaleEditPlan get _plan => planSaleEdit(
    sale: widget.sale,
    targetTotalUzs: _target,
    targetMethod: _method,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final plan = _plan;
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
                  PhosphorIconsRegular.pencilSimple,
                  color: NocturneColors.neutral200,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.editSaleTitle)),
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
                    _Note(text: l10n.editSaleHint),
                    const SizedBox(height: 12),
                    _Note(
                      icon: PhosphorIconsRegular.receipt,
                      text: l10n.editSaleCurrent(
                        formatUzs(widget.sale.cashUzs),
                        formatUzs(widget.sale.cardUzs),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _totalController,
                      enabled: !submitting,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.editSaleTotal,
                        suffixText: "so'm",
                        helperText: '1 — ${formatUzs(_physicalUzs)}',
                      ),
                      validator: (value) {
                        final amount = int.tryParse(value ?? '');
                        if (amount == null ||
                            amount < 1 ||
                            amount > _physicalUzs) {
                          return '1 — ${formatUzs(_physicalUzs)}';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.editSaleMethod,
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
                            icon: Icon(_icon(method), size: 18),
                            label: Text(_label(l10n, method)),
                          ),
                      ],
                      selected: {_method},
                      onSelectionChanged: submitting
                          ? null
                          : (selection) =>
                                setState(() => _method = selection.first),
                    ),
                    const SizedBox(height: 16),
                    _PlanPreview(plan: plan, sale: widget.sale),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _reasonController,
                      enabled: !submitting,
                      minLines: 2,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: l10n.editSaleReason,
                        hintText: l10n.editSaleReasonHint,
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
                      const SizedBox(height: 6),
                      Text(
                        l10n.editSalePartialFailure,
                        style: AppTextStyles.muted(
                          AppTextStyles.body,
                        ).copyWith(fontSize: 11),
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
              onPressed: submitting || plan.isBlocked || plan.isNoop
                  ? null
                  : _submit,
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(PhosphorIconsRegular.check, size: 18),
              label: Text(l10n.editSaleAction),
            ),
          ],
        );
      },
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<SalesHistoryBloc>().add(
      SalesHistoryEditRequested(
        saleId: widget.sale.id,
        plan: _plan,
        reason: _reasonController.text.trim(),
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

/// Spells the derived steps out in words, so the cashier confirms an outcome
/// rather than trusting a calculation they cannot see.
class _PlanPreview extends StatelessWidget {
  const _PlanPreview({required this.plan, required this.sale});

  final SaleEditPlan plan;
  final SaleHistoryEntry sale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    String label(SalePaymentMoveMethod method) =>
        method == SalePaymentMoveMethod.cash
        ? l10n.paymentCash.toLowerCase()
        : l10n.paymentCard.toLowerCase();

    if (plan.isBlocked) {
      return _Note(
        icon: PhosphorIconsRegular.warning,
        danger: true,
        text: switch (plan.blocker!) {
          SaleEditBlocker.increaseNotSupported => l10n.editSaleBlockedIncrease,
          SaleEditBlocker.methodLockedByRefund => l10n.editSaleBlockedMethod,
          SaleEditBlocker.balanceTooLow => l10n.editSaleBlockedBalance,
          SaleEditBlocker.notEditable => l10n.editSaleBlockedNotEditable,
        },
      );
    }
    if (plan.isNoop) {
      return _Note(
        icon: PhosphorIconsRegular.equals,
        text: l10n.editSalePlanNoop,
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NocturneColors.neutral900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: NocturneColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.editSalePlanTitle,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (plan.needsCorrection)
            _Step(
              icon: PhosphorIconsRegular.arrowsLeftRight,
              text: l10n.editSalePlanCorrection(
                formatUzs(plan.correctionUzs),
                label(plan.correctionFrom!),
                label(plan.targetMethod),
              ),
            ),
          if (plan.needsRefund)
            _Step(
              icon: PhosphorIconsRegular.arrowUDownLeft,
              text: l10n.editSalePlanRefund(
                formatUzs(plan.refundUzs),
                label(plan.targetMethod),
              ),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: NocturneColors.accent300),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppTextStyles.body.copyWith(fontSize: 12)),
        ),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({
    required this.text,
    this.icon = PhosphorIconsRegular.info,
    this.danger = false,
  });

  final String text;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: danger
          ? NocturneColors.danger.withValues(alpha: .12)
          : NocturneColors.accent900,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: danger ? NocturneColors.danger : NocturneColors.accent700,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: danger ? NocturneColors.danger : NocturneColors.accent300,
        ),
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
