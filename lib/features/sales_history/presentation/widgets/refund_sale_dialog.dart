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
  final _selectedPassIds = <String>{};
  late SaleRefundMethod _method;
  int? _submittedAmount;

  @override
  void initState() {
    super.initState();
    _method = _availableMethods.first;
  }

  /// Only the methods this receipt actually took money through. A top-up or a
  /// gate pass has no balance portion; a balance-paid checkout has no cash or
  /// card portion.
  List<SaleRefundMethod> get _availableMethods {
    final available = [
      for (final method in SaleRefundMethod.values)
        if (widget.sale.refundableFor(method) > 0) method,
    ];
    return available.isEmpty ? [SaleRefundMethod.cash] : available;
  }

  /// Gate-pass money maps one-to-one onto printed stickers, so the amount is
  /// derived from the selection instead of being typed in freely.
  bool get _picksPasses =>
      widget.sale.isGatePass && widget.sale.passes.isNotEmpty;

  int get _selectedPassTotal => widget.sale.passes
      .where((pass) => _selectedPassIds.contains(pass.id))
      .fold(0, (sum, pass) => sum + pass.priceUzs);

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  int get _limit => widget.sale.refundCeilingFor(_method);
  int? get _amount =>
      _picksPasses ? _selectedPassTotal : int.tryParse(_amountController.text);

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
                        for (final method in _availableMethods)
                          ButtonSegment(
                            value: method,
                            icon: Icon(_methodIcon(method), size: 18),
                            label: Text(
                              '${_methodLabel(l10n, method)} · '
                              '${formatUzs(widget.sale.refundableFor(method))}',
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
                    if (widget.sale.isTopup &&
                        widget.sale.customer != null) ...[
                      const SizedBox(height: 10),
                      _NoteBanner(
                        icon: PhosphorIconsRegular.wallet,
                        text:
                            '${l10n.refundCustomerBalance(formatUzs(widget.sale.customer!.balance))}'
                            '\n${l10n.refundBalanceLimitNote}',
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_picksPasses) ...[
                      _PassPicker(
                        passes: widget.sale.passes,
                        selected: _selectedPassIds,
                        enabled: !submitting,
                        onToggle: (id) => setState(() {
                          if (!_selectedPassIds.remove(id)) {
                            _selectedPassIds.add(id);
                          }
                        }),
                      ),
                      const SizedBox(height: 14),
                      _AmountSummary(
                        label: l10n.refundSelectedPassesTotal,
                        value: _selectedPassTotal,
                        emphasized: true,
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (!_picksPasses)
                      TextFormField(
                        controller: _amountController,
                        enabled: !submitting,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
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
                      _NoteBanner(
                        icon: PhosphorIconsRegular.warning,
                        text: l10n.refundCardWarning,
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
    final l10n = AppLocalization.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_picksPasses && _selectedPassIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.refundSelectPassesValidation)),
      );
      return;
    }
    final amount = _amount ?? 0;
    if (amount < 1) return;
    final methodLabel = _methodLabel(l10n, _method).toLowerCase();
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
        gatePassIds: _picksPasses ? _selectedPassIds.toList() : const [],
      ),
    );
  }

  IconData _methodIcon(SaleRefundMethod method) => switch (method) {
    SaleRefundMethod.cash => PhosphorIconsRegular.money,
    SaleRefundMethod.card => PhosphorIconsRegular.creditCard,
    SaleRefundMethod.balance => PhosphorIconsRegular.wallet,
  };

  String _methodLabel(AppLocalization l10n, SaleRefundMethod method) =>
      switch (method) {
        SaleRefundMethod.cash => l10n.paymentCash,
        SaleRefundMethod.card => l10n.paymentCard,
        SaleRefundMethod.balance => l10n.refundBalanceMethod,
      };
}

/// Checklist of the stickers this receipt printed. A pass the child already
/// walked in on, or one an earlier refund voided, is shown but cannot be
/// picked — the server refuses it either way.
class _PassPicker extends StatelessWidget {
  const _PassPicker({
    required this.passes,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final List<SaleGatePass> passes;
  final Set<String> selected;
  final bool enabled;
  final void Function(String passId) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final anyRefundable = passes.any((pass) => pass.refundable);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.refundSelectPasses,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (!anyRefundable)
          _NoteBanner(
            icon: PhosphorIconsRegular.warning,
            text: l10n.refundNoRefundablePasses,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: NocturneColors.neutral900,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NocturneColors.divider),
            ),
            child: Column(
              children: [
                for (final pass in passes)
                  CheckboxListTile(
                    dense: true,
                    value: selected.contains(pass.id),
                    onChanged: enabled && pass.refundable
                        ? (_) => onToggle(pass.id)
                        : null,
                    title: Text(
                      '${pass.planLabel} · ${formatUzs(pass.priceUzs)}',
                      style: AppTextStyles.body,
                    ),
                    subtitle: Text(
                      pass.refundable
                          ? pass.code
                          : '${pass.code} · '
                                '${pass.enteredAt != null ? l10n.refundPassUsed : l10n.refundPassVoided}',
                      style: AppTextStyles.muted(
                        AppTextStyles.body,
                      ).copyWith(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NoteBanner extends StatelessWidget {
  const _NoteBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

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
