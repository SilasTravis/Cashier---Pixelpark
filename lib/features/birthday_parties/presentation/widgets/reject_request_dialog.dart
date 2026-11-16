import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_party.dart';
import '../bloc/birthday_requests_cubit.dart';
import '../birthday_error_text.dart';
import '../birthday_recovery.dart';
import '../model/request_money.dart';
import 'confirm_request_dialog.dart' show birthdayRequestAlreadyDecided;

/// "Rad etish": a reason; everything paid returns to the parent's balance.
/// Resolves with the decided party, null when the cashier went back.
Future<BirthdayParty?> showRejectRequestDialog(
  BuildContext context,
  BirthdayParty party,
  BirthdayRequestsCubit cubit,
) {
  final theme = Theme.of(context);
  final messenger = ScaffoldMessenger.of(context);
  return showDialog<BirthdayParty>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Theme(
      data: theme,
      child: RejectRequestDialog(
        party: party,
        cubit: cubit,
        messenger: messenger,
      ),
    ),
  );
}

class RejectRequestDialog extends StatefulWidget {
  const RejectRequestDialog({
    super.key,
    required this.party,
    required this.cubit,
    required this.messenger,
  });
  final BirthdayParty party;
  final BirthdayRequestsCubit cubit;
  final ScaffoldMessengerState messenger;

  @override
  State<RejectRequestDialog> createState() => _RejectRequestDialogState();
}

class _RejectRequestDialogState extends State<RejectRequestDialog> {
  /// Fixed for the life of the dialog: a retry is the same rejection.
  final _requestId = const Uuid().v4();
  final _reason = TextEditingController();
  bool _busy = false;
  String? _errorCode;
  String? _errorMessage;

  bool get _canSubmit => !_busy && _reason.text.trim().length >= 3;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _errorCode = null;
      _errorMessage = null;
    });
    final l10n = AppLocalization.of(context);
    final navigator = Navigator.of(context);
    try {
      final party = await widget.cubit.reject(
        widget.party.id,
        _reason.text.trim(),
        requestId: _requestId,
      );
      if (mounted) navigator.pop(party);
    } catch (error) {
      if (!mounted) return;
      final code = error is ServerException ? error.code : null;
      if (code == birthdayRequestAlreadyDecided) {
        widget.cubit.remove(widget.party.id);
        widget.messenger.showSnackBar(
          SnackBar(content: Text(l10n.bdRequestAlreadyDecided)),
        );
        navigator.pop();
        return;
      }
      if (isUnclearFailure(error)) {
        final fresh = await refetchParty(
          widget.cubit.repository,
          widget.party.id,
        );
        if (!mounted) return;
        if (fresh != null && fresh.status != BirthdayPartyStatus.requested) {
          widget.cubit.remove(widget.party.id);
          navigator.pop(fresh);
          return;
        }
      }
      setState(() {
        _busy = false;
        _errorCode = code ?? 'UNKNOWN';
        _errorMessage = error is ServerException ? error.message : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final reason = _reason.text.trim();
    final refund = requestRefundUzs(widget.party);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.bdRequestRejectTitle,
                  style: p.title.copyWith(fontSize: 19),
                ),
                const SizedBox(height: 2),
                Text(widget.party.customerLabel, style: p.bodyMuted),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('bd-reject-reason'),
                  controller: _reason,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.bdRequestRejectReason,
                    errorText: reason.isNotEmpty && reason.length < 3
                        ? l10n.bdCancelReasonShort
                        : null,
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (refund > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.bdRequestRefundNote(formatUzs(refund)),
                    key: const ValueKey('bd-reject-refund'),
                    style: p.heading,
                  ),
                ],
                if (_errorCode != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const ValueKey('bd-reject-error'),
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
                          key: const ValueKey('bd-reject-back'),
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
                          key: const ValueKey('bd-reject-submit'),
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
                              : Text(l10n.bdRequestReject),
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
}
