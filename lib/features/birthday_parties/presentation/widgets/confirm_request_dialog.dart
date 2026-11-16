import 'package:flutter/material.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_party.dart';
import '../bloc/birthday_requests_cubit.dart';
import '../birthday_error_text.dart';
import '../birthday_recovery.dart';

/// Server code: another till (or the parent) already decided the request.
const birthdayRequestAlreadyDecided = 'BIRTHDAY_REQUEST_ALREADY_DECIDED';

/// "Tasdiqlash": the cashier picks the party time. Resolves with the booked
/// party, null when the cashier went back (or it was already decided).
Future<BirthdayParty?> showConfirmRequestDialog(
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
      child: ConfirmRequestDialog(
        party: party,
        cubit: cubit,
        messenger: messenger,
      ),
    ),
  );
}

class ConfirmRequestDialog extends StatefulWidget {
  const ConfirmRequestDialog({
    super.key,
    required this.party,
    required this.cubit,
    required this.messenger,
  });
  final BirthdayParty party;
  final BirthdayRequestsCubit cubit;
  final ScaffoldMessengerState messenger;

  @override
  State<ConfirmRequestDialog> createState() => _ConfirmRequestDialogState();
}

class _ConfirmRequestDialogState extends State<ConfirmRequestDialog> {
  TimeOfDay? _time;
  bool _busy = false;
  String? _errorCode;
  String? _errorMessage;

  String? get _hhmm => _time == null
      ? null
      : '${_time!.hour.toString().padLeft(2, '0')}:'
            '${_time!.minute.toString().padLeft(2, '0')}';

  Future<void> _pick() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final time = _hhmm;
    if (time == null || _busy) return;
    setState(() {
      _busy = true;
      _errorCode = null;
      _errorMessage = null;
    });
    final l10n = AppLocalization.of(context);
    final navigator = Navigator.of(context);
    try {
      final party = await widget.cubit.confirm(widget.party.id, time);
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
        // The answer may have been lost after the server confirmed it.
        final fresh = await refetchParty(
          widget.cubit.repository,
          widget.party.id,
        );
        if (!mounted) return;
        if (fresh != null && fresh.status != BirthdayPartyStatus.requested) {
          widget.cubit.remove(widget.party.id);
          navigator.pop(
            fresh.status == BirthdayPartyStatus.booked ? fresh : null,
          );
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
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.bdRequestConfirmTitle,
                style: p.title.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 2),
              Text(widget.party.customerLabel, style: p.bodyMuted),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  key: const ValueKey('bd-confirm-time'),
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.schedule),
                  label: Text(_hhmm ?? l10n.bdRequestPickTime),
                ),
              ),
              if (_errorCode != null) ...[
                const SizedBox(height: 12),
                Container(
                  key: const ValueKey('bd-confirm-error'),
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
                        key: const ValueKey('bd-confirm-back'),
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
                        key: const ValueKey('bd-confirm-submit'),
                        onPressed: _time == null || _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.bdRequestConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
