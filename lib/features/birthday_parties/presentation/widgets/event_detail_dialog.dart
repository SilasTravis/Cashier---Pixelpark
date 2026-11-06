import 'package:flutter/material.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';

import '../../data/birthday_parties_repository.dart';
import '../../domain/birthday_party.dart';
import '../../domain/birthday_plan.dart' show colorOf;
import '../bloc/birthday_sell_cubit.dart' show birthdayDateString;
import '../birthday_error_text.dart';
import '../birthday_printing.dart';
import '../model/event_groups.dart';
import 'add_children_dialog.dart';
import 'add_payment_sheet.dart';
import 'cancel_party_dialog.dart';
import 'comments_section.dart';
import 'event_detail_sections.dart';
import 'payment_timeline.dart';

/// Opens the party detail. [onChanged] receives the party after every action
/// (payment, +bola, date, comment, complete, cancel) so the list can follow.
Future<void> showEventDetailDialog(
  BuildContext context,
  BirthdayParty party, {
  ValueChanged<BirthdayParty>? onChanged,
}) {
  final theme = Theme.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => Theme(
      data: theme,
      child: EventDetailDialog(party: party, onChanged: onChanged),
    ),
  );
}

class EventDetailDialog extends StatefulWidget {
  const EventDetailDialog({super.key, required this.party, this.onChanged});

  final BirthdayParty party;
  final ValueChanged<BirthdayParty>? onChanged;

  @override
  State<EventDetailDialog> createState() => _EventDetailDialogState();
}

class _EventDetailDialogState extends State<EventDetailDialog> {
  late BirthdayParty _party = widget.party;
  bool _busy = false;
  String? _errorCode;
  String? _errorMessage;

  BirthdayPartiesRepository get _repo => sl<BirthdayPartiesRepository>();

  bool get _booked => _party.status == BirthdayPartyStatus.booked;
  bool get _canComplete => _party.partyDate.compareTo(tashkentToday()) <= 0;

  /// Runs one repository call: locks the buttons, shows a refusal inline, and
  /// hands the updated party to the list. Resolves with it, null on failure.
  Future<BirthdayParty?> _run(Future<BirthdayParty> Function() call) async {
    setState(() {
      _busy = true;
      _errorCode = null;
      _errorMessage = null;
    });
    try {
      final updated = await call();
      _apply(updated);
      return updated;
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
    return null;
  }

  void _apply(BirthdayParty updated) {
    widget.onChanged?.call(updated);
    if (mounted) {
      setState(() {
        _party = updated;
        _busy = false;
      });
    }
  }

  /// The payment row [updated] gained over [old] (a payment or a refund).
  BirthdayPartyPayment? _added(
    BirthdayParty old,
    BirthdayParty updated,
    BirthdayPaymentKind kind,
  ) {
    final ids = old.payments.map((p) => p.id).toSet();
    return updated.payments
        .where((p) => p.kind == kind && !ids.contains(p.id))
        .lastOrNull;
  }

  Future<void> _addPayment() async {
    final old = _party;
    final updated = await showAddPaymentSheet(context, old);
    if (updated == null || !mounted) return;
    _apply(updated);
    await printBirthdayReceipt(
      context,
      updated,
      payment: _added(old, updated, BirthdayPaymentKind.payment),
    );
  }

  Future<void> _cancel() async {
    final old = _party;
    final updated = await showCancelPartyDialog(context, old);
    if (updated == null || !mounted) return;
    _apply(updated);
    final refund = _added(old, updated, BirthdayPaymentKind.refund);
    if (refund != null) {
      await printBirthdayReceipt(context, updated, payment: refund);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _complete() async {
    final l10n = AppLocalization.of(context);
    if (_party.debtUzs > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l10n.bdCompleteDebt(groupDigits(_party.debtUzs))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.bdBack),
            ),
            FilledButton(
              key: const ValueKey('bd-complete-confirm'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.bdCompleteAnyway),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final done = await _run(() => _repo.complete(_party.id));
    if (done != null && mounted) Navigator.of(context).pop();
  }

  Future<void> _addChildren() async {
    final count = await showAddChildrenDialog(context, _party);
    if (count == null || !mounted) return;
    await _run(() => _repo.addExtraChildren(_party.id, count));
  }

  Future<void> _changeDate() async {
    final current = DateTime.parse(_party.partyDate);
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: current.isBefore(today)
          ? DateTime(current.year - 1)
          : DateTime(today.year - 1),
      lastDate: DateTime(today.year + 3),
    );
    if (picked == null || !mounted) return;
    await _run(() => _repo.changeDate(_party.id, birthdayDateString(picked)));
  }

  Future<bool> _addComment(String text) async =>
      await _run(() => _repo.addComment(_party.id, text)) != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final party = _party;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 900),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(p, l10n, party),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IncludesBlock(items: party.includedItems),
                      const SizedBox(height: 16),
                      PaymentTimeline(payments: party.payments),
                      const SizedBox(height: 14),
                      PartySummary(party: party),
                      const SizedBox(height: 16),
                      CommentsSection(
                        comments: party.comments,
                        onAdd: _addComment,
                        enabled: !_busy,
                      ),
                      if (_errorCode != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          key: const ValueKey('bd-error'),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _footer(l10n, party),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(PosPalette p, AppLocalization l10n, BirthdayParty party) {
    final tier = colorOf(party.planColor, p.accent);
    final kids = party.extraChildren > 0
        ? '${party.childCount} + ${party.extraChildren}'
        : '${party.childCount}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                party.customerName,
                style: p.title.copyWith(fontSize: 21),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                [
                  party.partyDate,
                  if (party.soldByUsername != null) party.soldByUsername!,
                  party.customerPhone,
                ].join(' · '),
                style: p.bodyMuted.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          key: const ValueKey('bd-tier-chip'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: tier.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${party.planName} · $kids',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tier,
            ),
          ),
        ),
        if (_booked)
          PopupMenuButton<VoidCallback>(
            key: const ValueKey('bd-more'),
            enabled: !_busy,
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(value: _addChildren, child: Text(l10n.bdMoreChild)),
              PopupMenuItem(value: _changeDate, child: Text(l10n.bdChangeDate)),
              PopupMenuItem(
                value: _cancel,
                child: Text(
                  l10n.bdCancelParty,
                  style: TextStyle(color: p.danger),
                ),
              ),
            ],
          ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _footer(AppLocalization l10n, BirthdayParty party) {
    final booked = _booked;
    final canPay =
        party.debtUzs > 0 && party.status != BirthdayPartyStatus.cancelled;
    final complete = FilledButton.tonal(
      key: const ValueKey('bd-complete'),
      onPressed: _busy || !_canComplete ? null : _complete,
      child: Text(l10n.eventsComplete),
    );
    return Row(
      children: [
        if (booked)
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: _canComplete
                  ? complete
                  : Tooltip(
                      message: l10n.bdCompleteFrom(party.partyDate),
                      child: complete,
                    ),
            ),
          ),
        if (booked && canPay) const SizedBox(width: 12),
        if (canPay)
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                key: const ValueKey('bd-add-payment'),
                onPressed: _busy ? null : _addPayment,
                child: Text(l10n.bdAddPaymentFull),
              ),
            ),
          ),
      ],
    );
  }
}
