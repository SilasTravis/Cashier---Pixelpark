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
import '../../../pos_account/domain/customer.dart';
import '../../../pos_account/presentation/open_customer.dart';
import '../../domain/inside_child.dart';
import '../bloc/inside_cubit.dart';

class InsidePage extends StatelessWidget {
  const InsidePage({super.key, required this.onOpenCustomer});

  /// Tapping a child's card opens its parent's account page.
  final ValueChanged<Customer> onOpenCustomer;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<InsideCubit>()..load(),
    child: _InsideView(onOpenCustomer: onOpenCustomer),
  );
}

class _InsideView extends StatefulWidget {
  const _InsideView({required this.onOpenCustomer});

  final ValueChanged<Customer> onOpenCustomer;

  @override
  State<_InsideView> createState() => _InsideViewState();
}

/// Which children the list shows. 1 soat children are the ones a cashier
/// must watch: their hour ends while they are still inside.
enum _InsideFilter { all, hour, overtime }

class _InsideViewState extends State<_InsideView> {
  final _search = TextEditingController();
  Timer? _clock;
  _InsideFilter _filter = _InsideFilter.all;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && !context.read<InsideCubit>().state.loading) {
        context.read<InsideCubit>().load(background: true);
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return BlocConsumer<InsideCubit, InsideState>(
      listenWhen: (oldState, state) =>
          oldState.exitSucceeded != state.exitSucceeded ||
          oldState.error != state.error,
      listener: (context, state) {
        if (state.exitSucceeded) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.manualExitSucceeded)));
        } else if (state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      builder: (context, state) {
        final query = _search.text.trim().toLowerCase();
        final now = DateTime.now();
        final hourCount = state.children.where((c) => c.isHourPlan).length;
        final overtimeCount = state.children
            .where((c) => c.isOvertime(now))
            .length;
        final children = sortInsideChildren(
          state.children.where((child) {
            final inFilter = switch (_filter) {
              _InsideFilter.all => true,
              _InsideFilter.hour => child.isHourPlan,
              _InsideFilter.overtime => child.isOvertime(now),
            };
            if (!inFilter) return false;
            if (query.isEmpty) return true;
            return child.childName.toLowerCase().contains(query) ||
                child.parentName.toLowerCase().contains(query) ||
                child.parentPhone.toLowerCase().contains(query);
          }).toList(),
          now,
        );
        final emptyMessage = query.isNotEmpty
            ? l10n.insideSearchEmpty
            : switch (_filter) {
                _InsideFilter.all => l10n.insideEmpty,
                _InsideFilter.hour => l10n.insideHourEmpty,
                _InsideFilter.overtime => l10n.insideOvertimeEmpty,
              };
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: l10n.insideSearchHint,
                        prefixIcon: const Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                        ),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(PhosphorIconsRegular.x),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: NocturneColors.accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      l10n.insideCount(state.children.length),
                      style: AppTextStyles.body.copyWith(
                        color: NocturneColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.refresh,
                    onPressed: state.loading
                        ? null
                        : context.read<InsideCubit>().load,
                    icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
                  ),
                ],
              ),
            ),
            if (hourCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: l10n.insideFilterAll,
                        count: state.children.length,
                        selected: _filter == _InsideFilter.all,
                        onTap: () =>
                            setState(() => _filter = _InsideFilter.all),
                      ),
                      _FilterChip(
                        label: l10n.insideFilterHour,
                        count: hourCount,
                        icon: PhosphorIconsRegular.timer,
                        selected: _filter == _InsideFilter.hour,
                        onTap: () =>
                            setState(() => _filter = _InsideFilter.hour),
                      ),
                      _FilterChip(
                        label: l10n.insideFilterOvertime,
                        count: overtimeCount,
                        icon: PhosphorIconsRegular.alarm,
                        danger: overtimeCount > 0,
                        selected: _filter == _InsideFilter.overtime,
                        onTap: () =>
                            setState(() => _filter = _InsideFilter.overtime),
                      ),
                    ],
                  ),
                ),
              ),
            if (overtimeCount > 0 && _filter != _InsideFilter.overtime)
              _OvertimeBanner(
                count: overtimeCount,
                onShow: () => setState(() => _filter = _InsideFilter.overtime),
              ),
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: children.isEmpty && !state.loading
                  ? _Empty(message: emptyMessage)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 760 ? 2 : 1;
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 202,
                              ),
                          itemCount: children.length,
                          itemBuilder: (_, index) => _ChildCard(
                            child: children[index],
                            now: now,
                            exiting:
                                state.exitingVisitId == children[index].visitId,
                            onExit: () =>
                                _confirmExit(context, children[index]),
                            onOpen: () =>
                                _openAccount(context, children[index]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAccount(BuildContext context, InsideChild child) async {
    final customer = await findCustomerByPhone(context, child.parentPhone);
    if (customer != null) widget.onOpenCustomer(customer);
  }

  Future<void> _confirmExit(BuildContext context, InsideChild child) async {
    final l10n = AppLocalization.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.manualExitTitle),
        content: Text(
          l10n.manualExitQuestion(child.childName, formatUzs(child.accruedUzs)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(PhosphorIconsRegular.signOut, size: 17),
            label: Text(l10n.markExited),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<InsideCubit>().forceExit(child.visitId);
    }
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.now,
    required this.exiting,
    required this.onExit,
    required this.onOpen,
  });
  final InsideChild child;
  final DateTime now;
  final bool exiting;
  final VoidCallback onExit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final elapsed = now.difference(child.enteredAt).inMinutes.clamp(0, 999999);
    final overtime = child.isOvertime(now);
    final progress = child.hourProgress(now);
    final remaining = child.remainingMinutes(now);
    final tone = overtime
        ? NocturneColors.danger
        : (remaining != null && remaining <= 10)
        ? NocturneColors.warning
        : NocturneColors.accent;
    return Material(
      color: overtime
          ? Color.alphaBlend(
              NocturneColors.danger.withValues(alpha: .07),
              NocturneColors.surface,
            )
          : NocturneColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: overtime
            ? BorderSide(color: NocturneColors.danger, width: 2)
            : BorderSide(color: NocturneColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        hoverColor: NocturneColors.neutral900,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1 soat: how much of the hour is used, along the top edge.
            if (progress != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  color: tone,
                  backgroundColor: tone.withValues(alpha: .15),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: NocturneColors.accent900,
                        foregroundColor: NocturneColors.accent,
                        child: Text(
                          child.childName.characters.first.toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child.childName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.h5,
                            ),
                            Text(
                              child.parentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.muted(
                                AppTextStyles.body.copyWith(fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (child.isHourPlan && child.hourEndsAt != null)
                        _HourPill(
                          text: overtime
                              ? l10n.hourOvertimeBy(child.overtimeMinutes(now))
                              : l10n.hourRemaining(remaining ?? 0),
                          tone: tone,
                          strong: overtime,
                        )
                      else if (child.planName != null)
                        Chip(
                          label: Text(child.planName!),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.phone,
                        size: 17,
                        color: NocturneColors.accent,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: SelectionArea(
                          child: Text(
                            formatPhoneNumber(child.parentPhone),
                            maxLines: 1,
                            style: AppTextStyles.body.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _Fact(
                          label: l10n.enteredAt,
                          value: DateFormat('HH:mm').format(child.enteredAt),
                        ),
                      ),
                      Expanded(
                        child: _Fact(
                          label: l10n.elapsedTime,
                          value: l10n.minutesCount(elapsed),
                        ),
                      ),
                      Expanded(
                        // A 1 soat child is prepaid — what matters is when the
                        // hour ends, not a running amount.
                        child: child.isHourPlan && child.hourEndsAt != null
                            ? _Fact(
                                label: overtime
                                    ? l10n.hourEndedAtLabel
                                    : l10n.hourEndsAtLabel,
                                value: DateFormat(
                                  'HH:mm',
                                ).format(child.hourEndsAt!),
                                color: overtime ? NocturneColors.danger : null,
                              )
                            : _Fact(
                                label: l10n.accruedAmount,
                                value: formatUzs(child.accruedUzs),
                              ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: exiting ? null : onExit,
                      icon: exiting
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(PhosphorIconsRegular.signOut, size: 17),
                      label: Text(l10n.markExited),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 1 soat time status in the card corner: minutes left (accent, amber
/// in the last 10) or minutes over (solid red) — readable at a glance.
class _HourPill extends StatelessWidget {
  const _HourPill({
    required this.text,
    required this.tone,
    required this.strong,
  });
  final String text;
  final Color tone;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: strong ? tone : tone.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          strong ? PhosphorIconsFill.alarm : PhosphorIconsRegular.timer,
          size: 15,
          color: strong ? Colors.white : tone,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: AppTextStyles.body.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: strong ? Colors.white : tone,
          ),
        ),
      ],
    ),
  );
}

/// Red strip above the list while any 1 soat child is over time.
class _OvertimeBanner extends StatelessWidget {
  const _OvertimeBanner({required this.count, required this.onShow});
  final int count;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final danger = NocturneColors.danger;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: danger.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIconsFill.alarm, color: danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.hourOvertimeBanner(count),
              style: AppTextStyles.body.copyWith(
                color: danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onShow,
            style: TextButton.styleFrom(foregroundColor: danger),
            child: Text(l10n.hourOvertimeShow),
          ),
        ],
      ),
    );
  }
}

/// One filter pill with its count; the over-time pill turns red while
/// anyone is over time so it reads as an alert, not just a tab.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.icon,
    this.danger = false,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tone = danger ? NocturneColors.danger : NocturneColors.accent;
    final fg = selected ? Colors.white : (danger ? tone : NocturneColors.text);
    return Material(
      color: selected ? tone : tone.withValues(alpha: danger ? .1 : .06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? tone : tone.withValues(alpha: .35)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                '$label · $count',
                style: AppTextStyles.body.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.muted(AppTextStyles.body.copyWith(fontSize: 11)),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: color,
        ),
      ),
    ],
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          PhosphorIconsRegular.personSimpleRun,
          size: 42,
          color: NocturneColors.neutral600,
        ),
        const SizedBox(height: 12),
        Text(message, style: AppTextStyles.muted(AppTextStyles.body)),
      ],
    ),
  );
}
