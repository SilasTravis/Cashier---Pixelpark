import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';

/// Small look helpers shared by the birthday sale screens: soft tier tints,
/// a gentle card shadow and tabular figures for money.

const _tabular = [FontFeature.tabularFigures()];

/// Money and counts line up column-wise.
TextStyle tabular(TextStyle style) => style.copyWith(fontFeatures: _tabular);

bool isNight(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// A tier colour mixed into the surface: [strength] 0..1 — the card fill
/// (weak) up to the selected fill (strong). Night mode needs more colour to
/// read on the slate surface.
Color tierTint(BuildContext context, Color tier, {double strength = 1}) {
  final p = PosPalette.of(context);
  final alpha = (isNight(context) ? 0.22 : 0.09) * strength;
  return Color.alphaBlend(tier.withValues(alpha: alpha), p.surface);
}

/// Tier colour readable as text on its own tint (night mode lifts it).
Color tierInk(BuildContext context, Color tier) => isNight(context)
    ? Color.lerp(tier, Colors.white, 0.45)!
    : Color.lerp(tier, Colors.black, 0.12)!;

/// The soft lift of a card on the page canvas; night mode keeps it flat.
List<BoxShadow> softShadow(BuildContext context) => isNight(context)
    ? const []
    : const [
        BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x0A0F172A),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ];

/// A white (surface) card with a big radius and the soft shadow.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: isNight(context) ? Border.all(color: p.border) : null,
        boxShadow: softShadow(context),
      ),
      child: child,
    );
  }
}

/// "① Tarif · Rangi bo'yicha tanlang" — a soft numbered step title.
class SoftStepHeader extends StatelessWidget {
  const SoftStepHeader({
    super.key,
    required this.step,
    required this.title,
    this.hint,
    this.trailing,
    this.done = false,
  });

  final int step;
  final String title;
  final String? hint;
  final Widget? trailing;

  /// The step already has a choice: the number turns into a check.
  final bool done;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? p.accent : p.accentSoft,
            shape: BoxShape.circle,
          ),
          child: done
              ? Icon(PhosphorIconsBold.check, size: 14, color: p.onAccent)
              : Text(
                  '$step',
                  style: TextStyle(
                    color: p.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Text(title, style: p.heading.copyWith(fontSize: 16.5)),
        if (hint != null) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              hint!,
              overflow: TextOverflow.ellipsis,
              style: p.bodyMuted.copyWith(fontSize: 13),
            ),
          ),
        ] else
          const Spacer(),
        if (trailing != null) ...[if (hint != null) const Spacer(), trailing!],
      ],
    );
  }
}

/// A soft rounded pill used for quick choices (deposit amounts, dates).
class SoftChoicePill extends StatelessWidget {
  const SoftChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Selected colour; the accent by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final c = color ?? p.accent;
    final fg = selected ? tierInk(context, c) : p.text;
    final radius = BorderRadius.circular(999);
    return Material(
      color: selected ? tierTint(context, c, strength: 1.4) : p.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: selected ? c : Colors.transparent, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tabular(
                    p.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
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

/// Grey shimmer-less placeholder bar for loading values.
class SkeletonBar extends StatelessWidget {
  const SkeletonBar({super.key, this.width = 120, this.height = 12});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: p.border,
        borderRadius: BorderRadius.circular(height),
      ),
    );
  }
}
