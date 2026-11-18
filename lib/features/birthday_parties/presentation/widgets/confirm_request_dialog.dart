import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_party.dart';
import '../../domain/birthday_plan.dart';
import '../bloc/birthday_requests_cubit.dart';
import '../birthday_error_text.dart';
import '../birthday_recovery.dart';
import '../model/party_time_slots.dart';
import '../model/request_details.dart';
import 'birthday_ui.dart';

/// Server code: another till (or the parent) already decided the request.
const birthdayRequestAlreadyDecided = 'BIRTHDAY_REQUEST_ALREADY_DECIDED';

/// "Tasdiqlash": the cashier picks the party time from 30-minute slots (the
/// branch's other parties that day are shown and marked, never blocked) or
/// types another one. Resolves with the booked
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
  /// The chosen `HH:MM`, from a slot or the "Boshqa vaqt" field.
  String? _time;
  bool _busy = false;
  String? _errorCode;
  String? _errorMessage;

  final _otherTime = TextEditingController();
  bool _otherInvalid = false;

  /// Other booked parties of the branch that day; null while loading.
  List<DayParty>? _day;
  bool _dayFailed = false;

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  @override
  void dispose() {
    _otherTime.dispose();
    super.dispose();
  }

  Future<void> _loadDay() async {
    try {
      final booked = await widget.cubit.repository.list(
        BirthdayPartyStatus.booked,
      );
      if (!mounted) return;
      setState(() => _day = dayPartiesFor(widget.party, booked));
    } catch (_) {
      // The time can still be chosen without the day's schedule.
      if (!mounted) return;
      setState(() {
        _day = const [];
        _dayFailed = true;
      });
    }
  }

  void _pickSlot(int minutes) {
    _otherTime.clear();
    setState(() {
      _time = formatHhmm(minutes);
      _otherInvalid = false;
    });
  }

  void _onOtherChanged(String raw) {
    final minutes = parseHhmm(raw);
    setState(() {
      _time = minutes == null ? null : formatHhmm(minutes);
      _otherInvalid = raw.trim().isNotEmpty && minutes == null;
    });
  }

  Future<void> _submit() async {
    final time = _time;
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
    final party = widget.party;
    final day = _day ?? const <DayParty>[];
    final starts = [for (final d in day) d.startMinutes];
    final selected = parseHhmm(_time);
    final clash = selected == null
        ? null
        : day.where((d) => d.startMinutes ~/ 30 == selected ~/ 30).toList();
    final slots = daySlots();
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.bdTimeTitle, style: p.title.copyWith(fontSize: 20)),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  text:
                      '${party.customerLabel} · ${party.planName} · '
                      '${l10n.bdKidsCount(party.childCount + party.extraChildren)}'
                      ' · ',
                  children: [
                    TextSpan(
                      text: weekdayDateLabel(l10n, party.partyDate),
                      style: TextStyle(
                        color: p.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                style: p.bodyMuted,
              ),
              const SizedBox(height: 14),
              _DayStrip(
                branch: party.branchName,
                day: _day,
                failed: _dayFailed,
                selected: selected,
              ),
              const SizedBox(height: 14),
              _SlotGroup(
                title: l10n.bdTimeMorning,
                slots: slots.where((m) => m < 14 * 60).toList(),
                starts: starts,
                selected: selected,
                enabled: !_busy,
                onPick: _pickSlot,
              ),
              const SizedBox(height: 10),
              _SlotGroup(
                title: l10n.bdTimeAfternoon,
                slots: slots.where((m) => m >= 14 * 60).toList(),
                starts: starts,
                selected: selected,
                enabled: !_busy,
                onPick: _pickSlot,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _LegendItem(
                    label: l10n.bdTimeLegendSelected,
                    state: _SlotLook.selected,
                  ),
                  _LegendItem(
                    label: l10n.bdTimeLegendBusy,
                    state: _SlotLook.busy,
                  ),
                  _LegendItem(
                    label: l10n.bdTimeLegendNear,
                    state: _SlotLook.near,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${l10n.bdTimeOther}:',
                        style: p.bodyMuted.copyWith(fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 84,
                        child: TextField(
                          key: const ValueKey('bd-confirm-other-time'),
                          controller: _otherTime,
                          enabled: !_busy,
                          maxLength: 5,
                          keyboardType: TextInputType.datetime,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9:]'),
                            ),
                          ],
                          textAlign: TextAlign.center,
                          style: tabular(
                            p.body.copyWith(fontWeight: FontWeight.w700),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            counterText: '',
                            hintText: '14:15',
                            errorText: _otherInvalid ? '' : null,
                            errorStyle: const TextStyle(height: 0),
                          ),
                          onChanged: _onOtherChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_otherInvalid) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.bdTimeOtherInvalid,
                  key: const ValueKey('bd-confirm-other-invalid'),
                  textAlign: TextAlign.end,
                  style: TextStyle(color: p.danger, fontSize: 12.5),
                ),
              ],
              if (clash != null && clash.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('bd-confirm-busy-warning'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: p.warningSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: p.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.bdTimeBusyWarning(
                            clash.map((d) => d.label).join(', '),
                          ),
                          style: TextStyle(color: p.warning, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                    child: Text(
                      l10n.bdTimeHint,
                      style: p.bodyMuted.copyWith(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      key: const ValueKey('bd-confirm-back'),
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l10n.bdBack),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('bd-confirm-submit'),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.positive,
                        foregroundColor: p.onAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onPressed: _time == null || _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _time == null
                                  ? l10n.bdRequestConfirm
                                  : l10n.bdTimeConfirmAt(_time!),
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

/// "Shu kuni Megaplanet'da": the day 10:00–21:00 with the other parties and
/// the chosen time.
class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.branch,
    required this.day,
    required this.failed,
    required this.selected,
  });

  final String branch;
  final List<DayParty>? day;
  final bool failed;
  final int? selected;

  static const _span = dayEndMinutes - dayStartMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final parties = day ?? const <DayParty>[];
    final kicker = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
      color: p.textMuted,
    );
    return Container(
      key: const ValueKey('bd-confirm-day'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.bdTimeDayAt(branch).toUpperCase(),
                  style: kicker,
                ),
              ),
              if (day == null)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                )
              else if (failed)
                Text(
                  l10n.bdTimeDayFailed,
                  key: const ValueKey('bd-confirm-day-failed'),
                  style: TextStyle(fontSize: 12, color: p.warning),
                )
              else
                Text(
                  (parties.isEmpty
                          ? l10n.bdTimeDayEmpty
                          : l10n.bdTimeDayCount(parties.length))
                      .toUpperCase(),
                  style: kicker,
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              double x(int minutes) =>
                  ((minutes - dayStartMinutes) / _span).clamp(0.0, 1.0) * w;
              Widget block(int start, Widget child) {
                final left = x(start);
                final right = x(start + partyDrawnMinutes);
                return Positioned(
                  left: left,
                  width: (right - left).clamp(0.0, w),
                  top: 0,
                  bottom: 0,
                  child: child,
                );
              }

              return Container(
                height: 34,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    for (final d in parties)
                      if (d.startMinutes < dayEndMinutes &&
                          d.startMinutes + partyDrawnMinutes > dayStartMinutes)
                        block(
                          d.startMinutes,
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _PartyChip(party: d),
                          ),
                        ),
                    // Labels apart from their blocks: a label may run past
                    // its 2-hour block rather than be cut.
                    for (final d in parties)
                      if (d.startMinutes < dayEndMinutes &&
                          d.startMinutes >= dayStartMinutes)
                        Positioned(
                          left: x(d.startMinutes) + 6,
                          top: 0,
                          bottom: 0,
                          child: Center(child: _PartyLabel(party: d)),
                        ),
                    if (selected != null &&
                        selected! < dayEndMinutes &&
                        selected! + partyDrawnMinutes > dayStartMinutes)
                      block(
                        selected!,
                        Container(
                          key: const ValueKey('bd-confirm-day-selected'),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: p.accent.withValues(alpha: 0.18),
                            border: Border.all(color: p.accent, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, c) {
              final style = tabular(
                TextStyle(fontSize: 11, color: p.textFaint),
              );
              return SizedBox(
                height: 14,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final h in const [10, 12, 14, 16, 18, 20, 21])
                      Positioned(
                        left:
                            (h * 60 - dayStartMinutes) / _span * c.maxWidth -
                            (h == 10 ? 0 : (h == 21 ? 14 : 7)),
                        child: Text('$h', style: style),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PartyChip extends StatelessWidget {
  const _PartyChip({required this.party});
  final DayParty party;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final tier = colorOf(party.planColor, p.accent);
    return Container(
      decoration: BoxDecoration(
        color: tierTint(context, tier, strength: 2),
        border: Border.all(color: tier.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _PartyLabel extends StatelessWidget {
  const _PartyLabel({required this.party});
  final DayParty party;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final tier = colorOf(party.planColor, p.accent);
    return Text(
      party.label,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: tierInk(context, tier),
      ),
    );
  }
}

enum _SlotLook { free, near, busy, selected }

_SlotLook _lookOf(SlotState s) => switch (s) {
  SlotState.free => _SlotLook.free,
  SlotState.near => _SlotLook.near,
  SlotState.busy => _SlotLook.busy,
};

/// Diagonal stripes for "another party starts here".
Gradient _stripes(PosPalette p) => LinearGradient(
  begin: Alignment.topLeft,
  end: const Alignment(-0.82, -0.55),
  tileMode: TileMode.repeated,
  colors: [p.surfaceMuted, p.surfaceMuted, p.border, p.border],
  stops: const [0, 0.5, 0.5, 1],
);

BoxDecoration _slotDecoration(PosPalette p, _SlotLook look, double radius) =>
    switch (look) {
      _SlotLook.selected => BoxDecoration(
        color: p.accent,
        border: Border.all(color: p.accent),
        borderRadius: BorderRadius.circular(radius),
      ),
      _SlotLook.busy => BoxDecoration(
        gradient: _stripes(p),
        border: Border.all(color: p.borderStrong),
        borderRadius: BorderRadius.circular(radius),
      ),
      _SlotLook.near => BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.warning.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(radius),
      ),
      _SlotLook.free => BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.borderStrong),
        borderRadius: BorderRadius.circular(radius),
      ),
    };

class _SlotGroup extends StatelessWidget {
  const _SlotGroup({
    required this.title,
    required this.slots,
    required this.starts,
    required this.selected,
    required this.enabled,
    required this.onPick,
  });

  final String title;
  final List<int> slots;
  final List<int> starts;
  final int? selected;
  final bool enabled;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: p.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) {
            const gap = 6.0;
            final w = (c.maxWidth - gap * 7) / 8;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final m in slots)
                  _SlotButton(
                    key: ValueKey('bd-slot-${formatHhmm(m)}'),
                    width: w,
                    minutes: m,
                    look: m == selected
                        ? _SlotLook.selected
                        : _lookOf(slotState(m, starts)),
                    onTap: enabled ? () => onPick(m) : null,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    super.key,
    required this.width,
    required this.minutes,
    required this.look,
    required this.onTap,
  });

  final double width;
  final int minutes;
  final _SlotLook look;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final label = formatHhmm(minutes);
    final color = switch (look) {
      _SlotLook.selected => p.onAccent,
      _SlotLook.busy => p.textFaint,
      _SlotLook.near => p.warning,
      _SlotLook.free => p.text,
    };
    return Semantics(
      button: true,
      selected: look == _SlotLook.selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Ink(
            width: width,
            height: 38,
            decoration: _slotDecoration(p, look, 9),
            child: Center(
              child: Text(
                label,
                style: tabular(
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                    decoration: look == _SlotLook.busy
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Exposes a slot's state to tests: `bd-slot-11:00` -> busy.
@visibleForTesting
String slotLookName(Widget w) => w is _SlotButton ? w.look.name : '';

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.state});
  final String label;
  final _SlotLook state;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: _slotDecoration(p, state, 4),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: p.textMuted)),
      ],
    );
  }
}
