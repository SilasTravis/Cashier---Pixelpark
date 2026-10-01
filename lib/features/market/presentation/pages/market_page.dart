import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../domain/market_order.dart';
import '../bloc/market_incoming_cubit.dart';
import '../bloc/market_pickup_cubit.dart';
import '../widgets/market_order_card.dart';
import '../widgets/pickup_code_field.dart';

enum _Section { give, incoming }

/// "Pixel Market buyurtmalari": hand parcels to parents by their pickup code
/// ("Berish") and receive the parcels shops send to this park
/// ("Kelayotgan"). Server-only — the shell disables the tab offline.
class MarketPage extends StatelessWidget {
  const MarketPage({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => sl<MarketPickupCubit>()),
      BlocProvider(create: (_) => sl<MarketIncomingCubit>()..load()),
    ],
    child: const _MarketView(),
  );
}

class _MarketView extends StatefulWidget {
  const _MarketView();

  @override
  State<_MarketView> createState() => _MarketViewState();
}

class _MarketViewState extends State<_MarketView> {
  _Section _section = _Section.give;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final incoming = context.watch<MarketIncomingCubit>().state;
    final receivable = incoming.orders
        .where((order) => order.status == MarketOrderStatus.handedOver)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              SegmentedButton<_Section>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _Section.give,
                    icon: const Icon(PhosphorIconsRegular.handshake, size: 17),
                    label: Text(l10n.marketGive),
                  ),
                  ButtonSegment(
                    value: _Section.incoming,
                    icon: const Icon(PhosphorIconsRegular.truck, size: 17),
                    label: Text(
                      receivable > 0
                          ? '${l10n.marketIncoming} · $receivable'
                          : l10n.marketIncoming,
                    ),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (picked) =>
                    setState(() => _section = picked.first),
              ),
              const Spacer(),
              if (_section == _Section.incoming)
                IconButton(
                  tooltip: l10n.refresh,
                  onPressed: incoming.loading
                      ? null
                      : context.read<MarketIncomingCubit>().load,
                  icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (_section) {
            _Section.give => const _GiveView(),
            _Section.incoming => const _IncomingView(),
          },
        ),
      ],
    );
  }
}

class _GiveView extends StatefulWidget {
  const _GiveView();

  @override
  State<_GiveView> createState() => _GiveViewState();
}

class _GiveViewState extends State<_GiveView> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  String? _errorText(AppLocalization l10n, MarketPickupState state) {
    if (!state.hasError) return null;
    if (state.errorCode == marketCodeInvalid) return l10n.marketCodeInvalid;
    return state.errorMessage ?? l10n.marketRequestFailed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return BlocConsumer<MarketPickupCubit, MarketPickupState>(
      // After a button press the button holds focus — hand it back to the
      // code field so the next scan lands there.
      listenWhen: (previous, current) => previous.busy && !current.busy,
      listener: (_, _) => _focus.requestFocus(),
      builder: (context, state) {
        final cubit = context.read<MarketPickupCubit>();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: PickupCodeField(
                focusNode: _focus,
                busy: state.loading,
                errorText: _errorText(l10n, state),
                onSubmit: cubit.lookup,
              ),
            ),
            const SizedBox(height: 16),
            if (state.handed.isNotEmpty) ...[
              _HandedPanel(
                handed: state.handed,
                onNext: () {
                  cubit.reset();
                  _focus.requestFocus();
                },
              ),
              const SizedBox(height: 16),
            ],
            if (state.orders.isNotEmpty)
              ..._orders(context, l10n, state, cubit)
            else if (state.handed.isEmpty && !state.loading)
              _Hint(
                icon: PhosphorIconsRegular.qrCode,
                message: l10n.marketScanPrompt,
              ),
          ],
        );
      },
    );
  }

  List<Widget> _orders(
    BuildContext context,
    AppLocalization l10n,
    MarketPickupState state,
    MarketPickupCubit cubit,
  ) {
    final first = state.orders.first;
    final numbers = {for (final order in state.orders) order.orderNumber};
    return [
      _CustomerCard(
        name: first.customerName,
        phone: first.customerPhone,
        orderNumbers: numbers.toList(),
      ),
      const SizedBox(height: 12),
      for (final order in state.orders) ...[
        MarketPickupOrderCard(
          order: order,
          receiving: state.receivingId == order.id,
          onReceive: state.busy ? null : () => cubit.receive(order.id),
        ),
        const SizedBox(height: 12),
      ],
      if (state.hasUnreceived)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(
                PhosphorIconsRegular.info,
                size: 18,
                color: NocturneColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.marketUnreceivedHint,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    color: NocturneColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
      SizedBox(
        height: 56,
        child: FilledButton.icon(
          onPressed: state.canHandOver && !state.busy ? cubit.handOver : null,
          icon: state.handingOver
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(PhosphorIconsRegular.checkCircle, size: 22),
          label: Text(
            l10n.marketHandOver,
            style: AppTextStyles.h5.copyWith(color: NocturneColors.neutral100),
          ),
        ),
      ),
    ];
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.name,
    required this.phone,
    required this.orderNumbers,
  });

  final String? name;
  final String? phone;
  final List<String> orderNumbers;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NocturneColors.accent.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: NocturneColors.accent800),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: NocturneColors.accent900,
            child: Icon(
              PhosphorIconsRegular.user,
              color: NocturneColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.marketCustomer,
                  style: AppTextStyles.muted(
                    AppTextStyles.body.copyWith(fontSize: 12),
                  ),
                ),
                Text(
                  (name == null || name!.isEmpty) ? '—' : name!,
                  style: AppTextStyles.h4,
                ),
                if (phone != null && phone!.isNotEmpty)
                  SelectionArea(
                    child: Text(
                      formatPhoneNumber(phone!),
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final number in orderNumbers)
                Text(
                  l10n.marketOrderNumber(number),
                  style: AppTextStyles.h5.copyWith(
                    color: NocturneColors.accent300,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HandedPanel extends StatelessWidget {
  const _HandedPanel({required this.handed, required this.onNext});
  final List<MarketOrder> handed;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final name = handed.first.customerName;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NocturneColors.success.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: NocturneColors.success.withValues(alpha: .5)),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsFill.checkCircle,
            size: 44,
            color: NocturneColors.success,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.marketHandedTitle, style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  [
                    l10n.marketHandedBody(handed.length),
                    if (name != null && name.isNotEmpty) name,
                  ].join(' · '),
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onNext,
            icon: const Icon(PhosphorIconsRegular.arrowRight, size: 17),
            label: Text(l10n.marketNext),
          ),
        ],
      ),
    );
  }
}

class _IncomingView extends StatelessWidget {
  const _IncomingView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    void toast(BuildContext context, String message) =>
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
    return MultiBlocListener(
      listeners: [
        BlocListener<MarketIncomingCubit, MarketIncomingState>(
          listenWhen: (previous, current) =>
              previous.errorSeq != current.errorSeq,
          listener: (context, state) => toast(
            context,
            (state.error ?? '').isEmpty
                ? l10n.marketRequestFailed
                : state.error!,
          ),
        ),
        BlocListener<MarketIncomingCubit, MarketIncomingState>(
          listenWhen: (previous, current) =>
              previous.receivedSeq != current.receivedSeq,
          listener: (context, _) => toast(context, l10n.marketReceivedToast),
        ),
      ],
      child: BlocBuilder<MarketIncomingCubit, MarketIncomingState>(
        builder: (context, state) {
          final cubit = context.read<MarketIncomingCubit>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: state.orders.isEmpty && !state.loading
                    ? _Hint(
                        icon: PhosphorIconsRegular.truck,
                        message: l10n.marketIncomingEmpty,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: state.orders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final order = state.orders[index];
                          return _IncomingTile(
                            order: order,
                            receiving: state.receivingId == order.id,
                            onReceive: state.receivingId == null
                                ? () => cubit.receive(order.id)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IncomingTile extends StatelessWidget {
  const _IncomingTile({
    required this.order,
    required this.receiving,
    required this.onReceive,
  });

  final MarketOrder order;
  final bool receiving;
  final VoidCallback? onReceive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final muted = AppTextStyles.muted(
      AppTextStyles.body.copyWith(fontSize: 13),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: NocturneColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.marketOrderNumber(order.orderNumber),
                      style: AppTextStyles.h5,
                    ),
                    const SizedBox(width: 10),
                    MarketStatusChip(status: order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    order.shopName,
                    l10n.marketItemsCount(order.itemCount),
                    if (order.customerName != null &&
                        order.customerName!.isNotEmpty)
                      order.customerName!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ],
            ),
          ),
          if (order.status == MarketOrderStatus.handedOver)
            FilledButton.icon(
              onPressed: receiving ? null : onReceive,
              icon: receiving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(PhosphorIconsRegular.package, size: 17),
              label: Text(l10n.marketReceived),
            ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: NocturneColors.neutral600),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.muted(AppTextStyles.body),
        ),
      ],
    ),
  );
}
