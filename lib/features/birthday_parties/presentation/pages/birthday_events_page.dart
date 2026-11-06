import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../../pos_account/domain/customer.dart';
import '../../data/birthday_parties_repository.dart';
import '../../domain/birthday_party.dart';
import '../bloc/birthday_events_cubit.dart';
import '../model/event_groups.dart';
import '../widgets/event_card.dart';

/// Tadbirlar tab: the branch's birthday parties by segment, grouped by date.
class BirthdayEventsPage extends StatelessWidget {
  const BirthdayEventsPage({super.key, this.onOpenCustomer, this.onOpen});

  /// Reserved for the detail dialog (Task C6) to jump to the parent account.
  final ValueChanged<Customer>? onOpenCustomer;

  /// Card / primary-button tap. C6 wires the detail dialog here and calls
  /// `cubit.replace(updated)` with the party it returns.
  final ValueChanged<BirthdayParty>? onOpen;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        BirthdayEventsCubit(sl<BirthdayPartiesRepository>())
          ..load(BirthdayPartyStatus.booked),
    child: _View(onOpen: onOpen),
  );
}

class _View extends StatelessWidget {
  const _View({this.onOpen});
  final ValueChanged<BirthdayParty>? onOpen;

  String _title(AppLocalization l10n, EventGroupKind k) => switch (k) {
    EventGroupKind.overdue => l10n.eventsOverdue,
    EventGroupKind.today => l10n.eventsToday,
    EventGroupKind.tomorrow => l10n.eventsTomorrow,
    EventGroupKind.thisWeek => l10n.eventsThisWeek,
    EventGroupKind.nextWeek => l10n.eventsNextWeek,
    EventGroupKind.later => l10n.eventsLater,
    EventGroupKind.all => '',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    return BlocBuilder<BirthdayEventsCubit, BirthdayEventsState>(
      builder: (context, state) {
        final cubit = context.read<BirthdayEventsCubit>();
        final today = tashkentToday();
        final groups = groupEvents(state.parties, today);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  SegmentedButton<BirthdayPartyStatus>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: BirthdayPartyStatus.booked,
                        label: Text(l10n.eventsBooked),
                      ),
                      ButtonSegment(
                        value: BirthdayPartyStatus.completed,
                        label: Text(l10n.eventsCompleted),
                      ),
                      ButtonSegment(
                        value: BirthdayPartyStatus.cancelled,
                        label: Text(l10n.eventsCancelled),
                      ),
                    ],
                    selected: {state.status},
                    onSelectionChanged: (s) => cubit.load(s.first),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: cubit.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: state.error != null && state.parties.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.error!, style: TextStyle(color: p.danger)),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: cubit.refresh,
                            child: Text(l10n.eventsRetry),
                          ),
                        ],
                      ),
                    )
                  : groups.isEmpty
                  ? Center(
                      child: state.loading
                          ? const SizedBox.shrink()
                          : Text(
                              l10n.eventsEmpty,
                              style: TextStyle(color: p.textMuted),
                            ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      children: [
                        for (final g in groups) ...[
                          if (g.kind != EventGroupKind.all)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 12, 0, 8),
                              child: Text(
                                _title(l10n, g.kind).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: g.kind == EventGroupKind.overdue
                                      ? p.danger
                                      : p.textMuted,
                                ),
                              ),
                            ),
                          for (final party in g.parties)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: EventCard(
                                party: party,
                                today: today,
                                onOpen: onOpen ?? (_) {},
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}
