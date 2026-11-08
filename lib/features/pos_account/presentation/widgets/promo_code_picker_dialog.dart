import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../../pos_sale/domain/discount.dart';
import '../../domain/promo_code_check.dart';
import '../bloc/pos_account_bloc.dart';

/// "Faol promokodlar": loads the open customer's redeemable codes and lets
/// the cashier pick one instead of typing it. The customer reads the code
/// out of their SMS; the server keeps only its tail, so each row shows the
/// last characters to match against. Picking verifies the code by id (see
/// [PosAccountPromoCodePicked]) and the dialog closes.
Future<void> showPromoCodePicker(BuildContext context) {
  final bloc = context.read<PosAccountBloc>()
    ..add(const PosAccountPromoCodesRequested());
  return showDialog<void>(
    context: context,
    builder: (_) =>
        BlocProvider.value(value: bloc, child: const PromoCodePickerDialog()),
  );
}

class PromoCodePickerDialog extends StatelessWidget {
  const PromoCodePickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final screen = MediaQuery.sizeOf(context);
    final maxWidth = (screen.width - 48).clamp(280.0, 520.0);
    final maxHeight = (screen.height - 48).clamp(240.0, 560.0);
    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.promoCodeActive, style: p.heading)),
                  IconButton(
                    tooltip: l10n.close,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(PhosphorIconsRegular.x, color: p.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: BlocBuilder<PosAccountBloc, PosAccountState>(
                  buildWhen: (a, b) =>
                      a.customerPromoCodes != b.customerPromoCodes ||
                      a.isLoadingPromoCodes != b.isLoadingPromoCodes ||
                      a.promoCodesFailed != b.promoCodesFailed,
                  builder: (context, state) {
                    final codes = state.customerPromoCodes;
                    if (state.promoCodesFailed) {
                      return _Message(
                        key: const ValueKey('promo-picker-failed'),
                        text: l10n.promoCodeLoadFailed,
                        action: OutlinedButton(
                          onPressed: () => context.read<PosAccountBloc>().add(
                            const PosAccountPromoCodesRequested(),
                          ),
                          child: Text(l10n.promoCodeRetry),
                        ),
                      );
                    }
                    if (codes == null) {
                      return const Padding(
                        key: ValueKey('promo-picker-loading'),
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (codes.isEmpty) {
                      return _Message(
                        key: const ValueKey('promo-picker-empty'),
                        text: l10n.promoCodeActiveEmpty,
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.promoCodeActiveHint,
                          style: p.bodyMuted.copyWith(fontSize: 12.5),
                        ),
                        const SizedBox(height: 10),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: codes.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) => _CodeTile(
                              code: codes[i],
                              onTap: () {
                                context.read<PosAccountBloc>().add(
                                  PosAccountPromoCodePicked(codes[i].codeId),
                                );
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center, style: p.bodyMuted),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

String _amount(Discount discount) => discount.kind == DiscountKind.percent
    ? '${discount.value}%'
    : formatUzs(discount.value);

String _date(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(at.day)}.${two(at.month)}.${at.year}';
}

/// One redeemable code: who issued it and what it is worth on the left, the
/// code's tail (to match against the SMS) as a badge on the right.
class _CodeTile extends StatelessWidget {
  const _CodeTile({required this.code, required this.onTap});

  final CustomerPromoCode code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final radius = BorderRadius.circular(12);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: p.borderStrong),
      ),
      child: InkWell(
        key: ValueKey('promo-code-tile-${code.codeId}'),
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIconsRegular.ticket,
                  size: 16,
                  color: p.accentStrong,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${code.partnerName} · ${code.tierName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: p.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '−${_amount(code.discount)} · '
                      '${l10n.promoCodeValidUntil(_date(code.expiresAt))}',
                      style: p.bodyMuted.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '···${code.codeLast4}',
                  key: ValueKey('promo-code-tail-${code.codeId}'),
                  style: p.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: p.accentStrong,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
