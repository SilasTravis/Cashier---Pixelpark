import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../domain/shift_visit.dart';
import '../bloc/visit_history_cubit.dart';

class VisitHistoryPage extends StatelessWidget {
  const VisitHistoryPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<VisitHistoryCubit>()..load(),
    child: const _VisitHistoryView(),
  );
}

class _VisitHistoryView extends StatefulWidget {
  const _VisitHistoryView();

  @override
  State<_VisitHistoryView> createState() => _VisitHistoryViewState();
}

class _VisitHistoryViewState extends State<_VisitHistoryView> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return BlocBuilder<VisitHistoryCubit, VisitHistoryState>(
      builder: (context, state) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 350),
                            () => context.read<VisitHistoryCubit>().load(
                              page: 1,
                              search: value,
                            ),
                          );
                        },
                        decoration: InputDecoration(
                          hintText: l10n.visitHistorySearchHint,
                          prefixIcon: const Icon(
                            PhosphorIconsRegular.magnifyingGlass,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.outlined(
                      tooltip: l10n.refresh,
                      onPressed: state.loading
                          ? null
                          : context.read<VisitHistoryCubit>().load,
                      icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          _StatusChip('all', l10n.categoryAll, state),
                          _StatusChip('open', l10n.visitInside, state),
                          _StatusChip('closed', l10n.visitExited, state),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: NocturneColors.accent.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.clock,
                            size: 16,
                            color: NocturneColors.accent,
                          ),
                          const SizedBox(width: 7),
                          Text(l10n.currentShiftOnly),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Summary(l10n.visitEntries, state.entries),
                    _Summary(l10n.visitExits, state.exits),
                    _Summary(l10n.visitStillInside, state.inside),
                    _Summary(l10n.total, state.total),
                  ],
                ),
              ],
            ),
          ),
          if (state.loading) const LinearProgressIndicator(minHeight: 2),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                state.error!,
                style: const TextStyle(color: NocturneColors.danger),
              ),
            ),
          Expanded(
            child: state.items.isEmpty && !state.loading
                ? Center(
                    child: Text(
                      l10n.visitHistoryEmpty,
                      style: AppTextStyles.muted(AppTextStyles.body),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => _VisitRow(state.items[index]),
                  ),
          ),
          if (state.total > VisitHistoryState.pageSize)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: state.page > 1 && !state.loading
                        ? () => context.read<VisitHistoryCubit>().load(
                            page: state.page - 1,
                          )
                        : null,
                    icon: const Icon(PhosphorIconsRegular.caretLeft),
                  ),
                  Text('${state.page} / ${state.pageCount}'),
                  IconButton(
                    onPressed: state.page < state.pageCount && !state.loading
                        ? () => context.read<VisitHistoryCubit>().load(
                            page: state.page + 1,
                          )
                        : null,
                    icon: const Icon(PhosphorIconsRegular.caretRight),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.value, this.label, this.state);
  final String value;
  final String label;
  final VisitHistoryState state;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: state.status == value,
    onSelected: state.loading
        ? null
        : (_) => context.read<VisitHistoryCubit>().load(page: 1, status: value),
  );
}

class _Summary extends StatelessWidget {
  const _Summary(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: NocturneColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.muted(AppTextStyles.body)),
          const SizedBox(height: 2),
          Text('$value', style: AppTextStyles.h4),
        ],
      ),
    ),
  );
}

class _VisitRow extends StatelessWidget {
  const _VisitRow(this.visit);
  final ShiftVisit visit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final time = DateFormat('HH:mm');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: NocturneColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: NocturneColors.accent900,
            child: Text(visit.childName.characters.first.toUpperCase()),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(visit.childName, style: AppTextStyles.h5),
                Text(
                  '${visit.parentName} · ${formatPhoneNumber(visit.parentPhone)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.muted(AppTextStyles.body),
                ),
              ],
            ),
          ),
          Expanded(
            child: _TimeFact(
              l10n.visitEntered,
              time.format(visit.enteredAt),
              PhosphorIconsRegular.signIn,
            ),
          ),
          Expanded(
            child: _TimeFact(
              l10n.visitExited,
              visit.exitedAt == null ? '—' : time.format(visit.exitedAt!),
              PhosphorIconsRegular.signOut,
            ),
          ),
          Expanded(
            child: _TimeFact(
              l10n.elapsedTime,
              visit.minutes == null
                  ? l10n.visitStillInside
                  : l10n.minutesCount(visit.minutes!),
              PhosphorIconsRegular.timer,
            ),
          ),
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatUzs(visit.amountUzs),
                  style: AppTextStyles.h5.copyWith(
                    color: NocturneColors.accent300,
                  ),
                ),
                Text(
                  visit.forceClosed
                      ? l10n.visitManualExit
                      : visit.exitedAt == null
                      ? l10n.visitInside
                      : l10n.visitExited,
                  style: AppTextStyles.muted(
                    AppTextStyles.body.copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeFact extends StatelessWidget {
  const _TimeFact(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: NocturneColors.neutral500),
      const SizedBox(width: 6),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.body.copyWith(
                fontSize: 10,
                color: NocturneColors.neutral500,
              ),
            ),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ],
  );
}
