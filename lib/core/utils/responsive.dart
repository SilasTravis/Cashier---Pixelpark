import 'package:flutter/widgets.dart';

/// The three widths this POS terminal is designed for (`800`–`1920px`, per
/// the product spec). The `.dc.html` layout is a dense 1440px desktop
/// design — layout STRUCTURE never changes across breakpoints (a cashier's
/// muscle memory depends on buttons staying put), only panel widths and a
/// couple of font sizes scale.
enum Breakpoint { compact, standard, wide }

Breakpoint breakpointOf(double width) {
  if (width < 1100) return Breakpoint.compact;
  if (width < 1500) return Breakpoint.standard;
  return Breakpoint.wide;
}

Breakpoint breakpointOfContext(BuildContext context) =>
    breakpointOf(MediaQuery.sizeOf(context).width);

/// Scales a "at 1440px" reference value down/up for the current breakpoint.
/// Used for the few panels (phone keypad, cart, product-grid tile) whose
/// width should breathe a little with the window instead of staying frozen.
double scaleForWidth(double width, double at1440) {
  final clamped = width.clamp(800, 1920);
  return at1440 * (clamped / 1440);
}

class ResponsivePanel {
  const ResponsivePanel({
    required this.compact,
    required this.standard,
    required this.wide,
  });

  final double compact;
  final double standard;
  final double wide;

  double of(BuildContext context) {
    switch (breakpointOfContext(context)) {
      case Breakpoint.compact:
        return compact;
      case Breakpoint.standard:
        return standard;
      case Breakpoint.wide:
        return wide;
    }
  }
}
