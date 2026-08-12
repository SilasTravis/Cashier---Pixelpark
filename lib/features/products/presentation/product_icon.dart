import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Maps the design system's `ph-*` icon class name (stored on `Product.icon`
/// from the Dashboard) to a Phosphor Flutter icon. Falls back to a generic
/// package icon for names not in this list rather than failing — the
/// Dashboard product form is the source of truth for which names are valid.
IconData productIconFor(String icon) {
  final key = icon.replaceFirst('ph-', '');
  return _icons[key] ?? PhosphorIconsRegular.package;
}

const _icons = {
  'ticket': PhosphorIconsRegular.ticket,
  'popcorn': PhosphorIconsRegular.popcorn,
  'gift': PhosphorIconsRegular.gift,
  'shopping-bag': PhosphorIconsRegular.shoppingBag,
  'star': PhosphorIconsRegular.star,
  'heart': PhosphorIconsRegular.heart,
  'book': PhosphorIconsRegular.book,
  'balloon': PhosphorIconsRegular.balloon,
  'cube': PhosphorIconsRegular.cube,
  'candy': PhosphorIconsRegular.cookie,
  'ice-cream': PhosphorIconsRegular.iceCream,
  'crown': PhosphorIconsRegular.crown,
  'toy': PhosphorIconsRegular.puzzlePiece,
  'game-controller': PhosphorIconsRegular.gameController,
  'paint-brush': PhosphorIconsRegular.paintBrush,
  'baby': PhosphorIconsRegular.baby,
};
