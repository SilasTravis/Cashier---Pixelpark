import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../generated/l10n.dart';
import '../../domain/active_pass.dart';
import 'account_ui.dart';

/// One same-plan re-print request: the backend returns each child's live
/// pass unchanged (same QR, nothing charged — the old sticker keeps
/// working), and the panel prints it again.
typedef ReprintGroup = ({
  String planKey,
  String planLabel,
  List<String> childIds,
});

/// "Bugungi QR'lar" — every child's still-valid day pass, each with a
/// re-print button, for the lost or damaged sticker. Hidden when the
/// customer has none.
class TodayPassesCard extends StatelessWidget {
  const TodayPassesCard({
    super.key,
    required this.passes,
    required this.childNames,
    required this.busy,
    required this.onReprint,
    required this.onStale,
  });

  /// `PosAccountState.activePasses` — only children still on the account
  /// ([childNames]) are listed.
  final List<ActivePass> passes;
  final Map<String, String> childNames;
  final bool busy;

  /// One group per plan, in the order to print them.
  final ValueChanged<List<ReprintGroup>> onReprint;

  /// A tapped pass had already expired (the list outlived midnight): the
  /// panel re-reads the passes. Never sent on: past expiry the same request
  /// is a FRESH sale, and a VIP one would debit the balance.
  final VoidCallback onStale;

  void _reprint(Iterable<ActivePass> tapped) {
    final now = DateTime.now();
    final live = tapped.where((pass) => pass.expiresAt.isAfter(now)).toList();
    if (live.length < tapped.length) onStale();
    final groups = groupsFor(live);
    if (groups.isNotEmpty) onReprint(groups);
  }

  /// Children on the same plan go in one request, as the conflict dialog's
  /// re-print does. A pass whose plan row was deleted can't be re-printed.
  static List<ReprintGroup> groupsFor(Iterable<ActivePass> passes) {
    final byPlan = <String, ReprintGroup>{};
    for (final pass in passes) {
      final key = pass.planKey;
      if (key == null) continue;
      final group = byPlan[key];
      byPlan[key] = (
        planKey: key,
        planLabel: pass.planLabel,
        childIds: [...?group?.childIds, pass.childId],
      );
    }
    return byPlan.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final rows = [
      for (final pass in passes)
        if (childNames.containsKey(pass.childId)) pass,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final all = groupsFor(rows);
    return AccountCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.qrCode, size: 18, color: p.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.accountTodayQrs,
                  style: p.heading.copyWith(fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: '${rows.length}', tone: ChipTone.neutral),
              const Spacer(),
              if (rows.length > 1 && all.isNotEmpty)
                TextButton.icon(
                  key: const ValueKey('reprint-all'),
                  onPressed: busy ? null : () => _reprint(rows),
                  icon: const Icon(PhosphorIconsRegular.printer, size: 16),
                  label: Text(l10n.reprintAll),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.accountTodayQrsHint,
            style: p.bodyMuted.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final (i, pass) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, color: p.border),
            _PassRow(
              pass: pass,
              childName: childNames[pass.childId]!,
              busy: busy,
              onReprint: () => _reprint([pass]),
            ),
          ],
        ],
      ),
    );
  }
}

class _PassRow extends StatelessWidget {
  const _PassRow({
    required this.pass,
    required this.childName,
    required this.busy,
    required this.onReprint,
  });

  final ActivePass pass;
  final String childName;
  final bool busy;
  final VoidCallback onReprint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final until = l10n.accountValidUntil(_hhmm(pass.expiresAt));
    final canReprint = pass.planKey != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, box) {
          // A narrow column keeps the name readable: icon-only button.
          final compact = box.maxWidth < 360;
          return Row(
            children: [
              AccountAvatar(name: childName, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(childName, style: p.heading.copyWith(fontSize: 14)),
                    Text(
                      [
                        pass.planLabel,
                        until,
                        if (pass.discountName != null) pass.discountName!,
                      ].join(' · '),
                      style: p.bodyMuted.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (canReprint)
                compact
                    ? IconButton.outlined(
                        key: ValueKey('reprint-${pass.childId}'),
                        tooltip: l10n.reprint,
                        onPressed: busy ? null : onReprint,
                        icon: const Icon(
                          PhosphorIconsRegular.printer,
                          size: 18,
                        ),
                      )
                    : OutlinedButton.icon(
                        key: ValueKey('reprint-${pass.childId}'),
                        onPressed: busy ? null : onReprint,
                        icon: const Icon(
                          PhosphorIconsRegular.printer,
                          size: 16,
                        ),
                        label: Text(l10n.reprint),
                      ),
            ],
          );
        },
      ),
    );
  }

  /// A day pass ends at local midnight — "00:00 gacha" would read as the
  /// start of the day, so the last minute is shown instead.
  static String _hhmm(DateTime t) {
    final shown = t.hour == 0 && t.minute == 0
        ? t.subtract(const Duration(minutes: 1))
        : t;
    return _twoDigits(shown);
  }

  static String _twoDigits(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
