import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../generated/l10n.dart';
import 'account_ui.dart';

/// "Xizmatlar" on the account page: services sold to this parent outside the
/// entry checkout (birthday parties today). A responsive grid of
/// [ServiceCard]s, so more services can join later.
class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key, required this.cards});

  final List<ServiceCard> cards;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    return AccountCard(
      key: const ValueKey('services-section'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.squaresFour, size: 18, color: p.accent),
              const SizedBox(width: 8),
              Text(l10n.servicesTitle, style: p.heading.copyWith(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final columns = ((constraints.maxWidth + gap) / (300 + gap))
                  .floor()
                  .clamp(1, 3);
              final width =
                  (constraints.maxWidth - (columns - 1) * gap) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final card in cards) SizedBox(width: width, child: card),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One service: icon tile, title, a short subtitle and a chevron. [onTap]
/// null disables it and [disabledReason] replaces the subtitle (and is the
/// tooltip).
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.disabledReason,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final enabled = onTap != null;
    final radius = BorderRadius.circular(16);
    final card = Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: p.accentSoft,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 24, color: p.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: p.heading.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        enabled ? subtitle : (disabledReason ?? subtitle),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: p.bodyMuted.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 18,
                  color: enabled ? p.accent : p.textFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!enabled && disabledReason != null) {
      return Tooltip(message: disabledReason!, child: card);
    }
    return card;
  }
}
