import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../data/birthday_parties_repository.dart';
import '../../domain/birthday_party.dart';
import '../birthday_error_text.dart';
import '../model/cancel_refund_form.dart';

/// "Bekor qilish": a reason and what happens to the money already paid.
/// Resolves with the cancelled party, null when the cashier went back.
Future<BirthdayParty?> showCancelPartyDialog(
  BuildContext context,
  BirthdayParty party,
) {
  final theme = Theme.of(context);
  return showDialog<BirthdayParty>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Theme(
      data: theme,
      child: CancelPartyDialog(party: party),
    ),
  );
}

class CancelPartyDialog extends StatefulWidget {
  const CancelPartyDialog({super.key, required this.party});
  final BirthdayParty party;

  @override
  State<CancelPartyDialog> createState() => _CancelPartyDialogState();
}

class _CancelPartyDialogState extends State<CancelPartyDialog> {
  /// Fixed for the life of the dialog: a retry is the same cancellation.
  final _requestId = const Uuid().v4();
  final _reason = TextEditingController();
  final _balance = TextEditingController();
  final _cash = TextEditingController();

  /// null = the cashier has not decided yet (only asked when money was paid).
  bool? _refund;
  bool _busy = false;
  String? _errorCode;
  String? _errorMessage;

  int get _net => widget.party.paidUzs - widget.party.refundedUzs;
  bool get _hasMoney => _net > 0;
  bool get _decided => !_hasMoney || _refund != null;
  bool get _doRefund => _hasMoney && _refund == true;
  int get _balanceUzs => parseUzs(_balance.text) ?? 0;
  int get _cashUzs => parseUzs(_cash.text) ?? 0;

  String? get _formError => CancelRefundForm.validate(
    netUzs: _net,
    maxCashRefundUzs: widget.party.maxCashRefundUzs,
    refund: _doRefund,
    balanceUzs: _balanceUzs,
    cashUzs: _cashUzs,
  );

  bool get _canSubmit =>
      !_busy &&
      _reason.text.trim().length >= 3 &&
      _decided &&
      _formError == null;

  @override
  void dispose() {
    _reason.dispose();
    _balance.dispose();
    _cash.dispose();
    super.dispose();
  }

  void _choose(bool refund) => setState(() {
    _refund = refund;
    if (refund && _balance.text.isEmpty && _cash.text.isEmpty) {
      _balance.text = groupDigits(_net);
    }
  });

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final refundBalance = _doRefund ? _balanceUzs : 0;
    final refundCash = _doRefund ? _cashUzs : 0;
    setState(() {
      _busy = true;
      _errorCode = null;
      _errorMessage = null;
    });
    try {
      final party = await sl<BirthdayPartiesRepository>().cancel(
        widget.party.id,
        reason: _reason.text.trim(),
        refundBalanceUzs: refundBalance,
        refundCashUzs: refundCash,
        requestId: _requestId,
      );
      if (mounted) Navigator.of(context).pop(party);
    } on ServerException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorCode = e.code ?? 'UNKNOWN';
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorCode = 'UNKNOWN';
        });
      }
    }
  }

  String? _errorText(AppLocalization l10n) => switch (_formError) {
    CancelRefundForm.cashTooLarge => l10n.bdCashTooLarge(
      groupDigits(widget.party.maxCashRefundUzs),
    ),
    CancelRefundForm.totalTooLarge => l10n.bdTotalTooLarge(groupDigits(_net)),
    CancelRefundForm.empty => l10n.bdRefundEmpty,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final reason = _reason.text.trim();
    final formError = _errorText(l10n);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.bdCancelTitle, style: p.title.copyWith(fontSize: 19)),
                const SizedBox(height: 2),
                Text(widget.party.customerName, style: p.bodyMuted),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('bd-cancel-reason'),
                  controller: _reason,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.bdCancelReason,
                    errorText: reason.isNotEmpty && reason.length < 3
                        ? l10n.bdCancelReasonShort
                        : null,
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_hasMoney) ...[
                  const SizedBox(height: 14),
                  Text(l10n.bdNetPaid(formatUzs(_net)), style: p.heading),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    emptySelectionAllowed: true,
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text(
                          l10n.bdRefund,
                          key: const ValueKey('bd-cancel-refund'),
                        ),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text(
                          l10n.bdNoRefund,
                          key: const ValueKey('bd-cancel-norefund'),
                        ),
                      ),
                    ],
                    selected: {?_refund},
                    onSelectionChanged: (s) {
                      if (s.isNotEmpty) _choose(s.first);
                    },
                  ),
                  if (_doRefund) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _field(
                            'bd-cancel-balance',
                            _balance,
                            l10n.bdToBalance,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field('bd-cancel-cash', _cash, l10n.bdToCash),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (formError != null)
                      Text(
                        formError,
                        key: const ValueKey('bd-cancel-form-error'),
                        style: TextStyle(color: p.danger, fontSize: 12.5),
                      )
                    else
                      Text(
                        l10n.bdKept(formatUzs(_net - _balanceUzs - _cashUzs)),
                        style: p.bodyMuted,
                      ),
                  ],
                ],
                if (_errorCode != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const ValueKey('bd-cancel-error'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: p.dangerSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      birthdayErrorText(l10n, _errorCode, _errorMessage),
                      style: TextStyle(color: p.danger, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Text(l10n.bdBack),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          key: const ValueKey('bd-cancel-confirm'),
                          style: FilledButton.styleFrom(
                            backgroundColor: p.danger,
                          ),
                          onPressed: _canSubmit ? _submit : null,
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.bdCancelConfirm),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String key, TextEditingController c, String label) => TextField(
    key: ValueKey(key),
    controller: c,
    keyboardType: TextInputType.number,
    inputFormatters: const [ThousandsInputFormatter()],
    decoration: InputDecoration(labelText: label, isDense: true),
    onChanged: (_) => setState(() {}),
  );
}
