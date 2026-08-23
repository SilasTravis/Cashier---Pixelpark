import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/phone_number.dart';
import '../../domain/customer.dart';
import '../bloc/pos_account_bloc.dart';
import '../../../../generated/l10n.dart';

/// The center pane before a customer is selected: a hint until enough digits
/// are typed, a spinner while searching, the match list, or — no matches —
/// an inline "add customer" row (matching the design's `adding` toggle,
/// no modal).
class CustomerResultsList extends StatefulWidget {
  const CustomerResultsList({super.key});

  @override
  State<CustomerResultsList> createState() => _CustomerResultsListState();
}

class _CustomerResultsListState extends State<CustomerResultsList> {
  final _searchController = TextEditingController();
  bool _showAll = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosAccountBloc, PosAccountState>(
      builder: (context, state) {
        final l10n = AppLocalization.of(context);
        final query = state.searchQuery.trim();
        Widget content;
        if (query.isEmpty) {
          final customers = _showAll
              ? state.recentCustomers
              : state.customerHistory;
          content = customers.isEmpty
              ? _CenteredHint(
                  icon: PhosphorIconsRegular.userCircleDashed,
                  text: l10n.findCustomerHint,
                )
              : _CustomerTileList(
                  title: _showAll ? l10n.allCustomers : l10n.searchHistory,
                  subtitle: l10n.customerCount(customers.length),
                  customers: customers,
                );
        } else if (query.length < 2) {
          content = _CenteredHint(
            icon: PhosphorIconsRegular.userCircleDashed,
            text: l10n.customerDirectorySearchHint,
          );
        } else if (state.isSearching) {
          content = const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        } else if (state.results.isEmpty) {
          content = RegExp(r'^\d{9}$').hasMatch(query)
              ? const _NotFoundCard()
              : _CenteredHint(
                  icon: PhosphorIconsRegular.userCircleDashed,
                  text: l10n.phoneNotFound,
                );
        } else {
          content = _CustomerTileList(
            title: l10n.searchResult,
            subtitle: l10n.customerCount(state.results.length),
            customers: state.results,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => context.read<PosAccountBloc>().add(
                PosAccountQueryChanged(value),
              ),
              decoration: InputDecoration(
                hintText: l10n.customerDirectorySearchHint,
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          context.read<PosAccountBloc>().add(
                            const PosAccountQueryChanged(''),
                          );
                          setState(() {});
                        },
                        icon: const Icon(PhosphorIconsRegular.x),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (query.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(
                        PhosphorIconsRegular.clockCounterClockwise,
                      ),
                      label: Text(l10n.searchHistory),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(PhosphorIconsRegular.users),
                      label: Text(l10n.allCustomers),
                    ),
                  ],
                  selected: {_showAll},
                  onSelectionChanged: (value) =>
                      setState(() => _showAll = value.first),
                ),
              ),
            if (query.isEmpty) const SizedBox(height: 12),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (_showAll &&
                      query.isEmpty &&
                      notification.metrics.extentAfter < 240) {
                    context.read<PosAccountBloc>().add(
                      const PosAccountMoreCustomersRequested(),
                    );
                  }
                  return false;
                },
                child: content,
              ),
            ),
            if (_showAll && state.isLoadingMoreCustomers)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        );
      },
    );
  }
}

class _CustomerTileList extends StatelessWidget {
  const _CustomerTileList({
    required this.title,
    required this.subtitle,
    required this.customers,
  });

  final String title;
  final String subtitle;
  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(title, style: AppTextStyles.h5),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: AppTextStyles.muted(
                  AppTextStyles.body,
                ).copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final customer in customers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CustomerTile(
                name: customer.fullName,
                phone: customer.phoneNumber,
                childCount: customer.children.length,
                balance: customer.balance,
                onTap: () => context.read<PosAccountBloc>().add(
                  PosAccountCustomerSelected(customer),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 34,
              color: NocturneColors.text.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: NocturneColors.text.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.name,
    required this.phone,
    required this.childCount,
    required this.balance,
    required this.onTap,
  });

  final String name;
  final String phone;
  final int childCount;
  final int balance;
  final VoidCallback onTap;

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = name.isEmpty ? phone : name;
    return Material(
      color: NocturneColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadow.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: NocturneColors.accent900,
                child: Text(
                  _initials(displayName),
                  style: const TextStyle(
                    color: NocturneColors.accent300,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayName, style: AppTextStyles.h5),
                    Text(
                      AppLocalization.of(context).childCount(childCount),
                      style: AppTextStyles.muted(
                        AppTextStyles.body,
                      ).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatUzs(balance),
                    style: AppTextStyles.h5.copyWith(
                      color: NocturneColors.accent300,
                    ),
                  ),
                  Text(
                    formatPhoneNumber(phone),
                    style: AppTextStyles.body.copyWith(
                      fontSize: 11,
                      color: NocturneColors.text.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              const Icon(
                PhosphorIconsRegular.caretRight,
                size: 16,
                color: NocturneColors.neutral500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFoundCard extends StatefulWidget {
  const _NotFoundCard();

  @override
  State<_NotFoundCard> createState() => _NotFoundCardState();
}

class _NotFoundCardState extends State<_NotFoundCard> {
  bool _adding = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosAccountBloc, PosAccountState>(
      builder: (context, state) {
        final l10n = AppLocalization.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NocturneColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadow.sm,
            ),
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.phoneNotFound, style: AppTextStyles.h5),
                const SizedBox(height: 2),
                Text(
                  l10n.accountNotFoundForPhone(state.phoneDigits),
                  style: AppTextStyles.muted(
                    AppTextStyles.body,
                  ).copyWith(fontSize: 13),
                ),
                const SizedBox(height: 14),
                if (!_adding)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _adding = true),
                    icon: const Icon(PhosphorIconsRegular.userPlus, size: 16),
                    label: Text(l10n.addCustomer),
                  )
                else
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 240,
                        child: TextField(
                          controller: _nameController,
                          autofocus: true,
                          style: AppTextStyles.body,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(labelText: l10n.fullName),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed:
                            state.isBusy ||
                                _nameController.text.trim().length < 2
                            ? null
                            : () => context.read<PosAccountBloc>().add(
                                PosAccountNewCustomerRequested(
                                  _nameController.text.trim(),
                                ),
                              ),
                        icon: state.isBusy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(PhosphorIconsRegular.check, size: 16),
                        label: Text(l10n.save),
                      ),
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _adding = false;
                          _nameController.clear();
                        }),
                        child: Text(l10n.cancel),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
