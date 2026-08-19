import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../domain/inside_child.dart';
import '../bloc/inside_cubit.dart';

class InsidePage extends StatelessWidget {
  const InsidePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<InsideCubit>()..load(),
    child: const _InsideView(),
  );
}

class _InsideView extends StatefulWidget {
  const _InsideView();

  @override
  State<_InsideView> createState() => _InsideViewState();
}

class _InsideViewState extends State<_InsideView> {
  final _search = TextEditingController();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && !context.read<InsideCubit>().state.loading) {
        context.read<InsideCubit>().load();
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
        final children = state.children.where((child) {
          if (query.isEmpty) return true;
          return child.childName.toLowerCase().contains(query) ||
              child.parentName.toLowerCase().contains(query) ||
              child.parentPhone.toLowerCase().contains(query);
        }).toList();
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
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: children.isEmpty && !state.loading
                  ? _Empty(
                      message: query.isEmpty
                          ? l10n.insideEmpty
                          : l10n.insideSearchEmpty,
                    )
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
                                mainAxisExtent: 174,
                              ),
                          itemCount: children.length,
                          itemBuilder: (_, index) => _ChildCard(
                            child: children[index],
                            exiting:
                                state.exitingVisitId == children[index].visitId,
                            onExit: () =>
                                _confirmExit(context, children[index]),
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
    required this.exiting,
    required this.onExit,
  });
  final InsideChild child;
  final bool exiting;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final elapsed = DateTime.now()
        .difference(child.enteredAt)
        .inMinutes
        .clamp(0, 999999);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: NocturneColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: NocturneColors.accent900,
                child: Text(child.childName.characters.first.toUpperCase()),
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
                      '${child.parentName} · ${child.parentPhone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.muted(
                        AppTextStyles.body.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              if (child.planName != null)
                Chip(
                  label: Text(child.planName!),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 12),
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
                child: _Fact(
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
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

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
        const Icon(
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
