import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/responsive.dart';
import '../../../products/domain/product.dart';
import '../../../products/presentation/product_icon.dart';
import '../bloc/pos_sale_bloc.dart';
import '../../../../generated/l10n.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosSaleBloc, PosSaleState>(
      buildWhen: (previous, current) =>
          previous.visibleProducts != current.visibleProducts ||
          previous.isLoadingProducts != current.isLoadingProducts ||
          previous.cart != current.cart,
      builder: (context, state) {
        if (state.isLoadingProducts) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (state.visibleProducts.isEmpty) {
          return Center(
            child: Text(
              AppLocalization.of(context).productNotFound,
              style: AppTextStyles.muted(AppTextStyles.body),
            ),
          );
        }
        final compact = breakpointOfContext(context) == Breakpoint.compact;
        return GridView.builder(
          padding: EdgeInsets.all(compact ? 4 : 16),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: compact ? 160 : 176,
            mainAxisSpacing: compact ? 8 : 12,
            crossAxisSpacing: compact ? 8 : 12,
            childAspectRatio: compact ? 1.0 : 0.92,
          ),
          itemCount: state.visibleProducts.length,
          itemBuilder: (context, index) {
            final product = state.visibleProducts[index];
            return _ProductCard(
              product: product,
              qtyInCart: state.cart[product.id] ?? 0,
              onTap: () =>
                  context.read<PosSaleBloc>().add(PosSaleProductAdded(product)),
            );
          },
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.qtyInCart,
    required this.onTap,
  });

  final Product product;
  final int qtyInCart;
  final VoidCallback onTap;

  static const _nameFontSize = 13.0;
  static const _minNameFontSize = 9.0;
  static const _nameLineHeight = 1.3;
  static const _gap = 8.0;
  static const _textInset = 4.0;

  /// What a very long name always leaves the photo (or icon).
  static const _minPhotoHeight = 40.0;

  static TextStyle _nameStyle(double fontSize) =>
      AppTextStyles.body.copyWith(fontSize: fontSize, height: _nameLineHeight);

  static final _priceStyle = AppTextStyles.muted(
    AppTextStyles.body,
  ).copyWith(fontSize: 12);

  /// 13px, unless the full name wouldn't fit above the price with at least
  /// [_minPhotoHeight] of photo left — then the font shrinks (never below
  /// 9px) rather than the name being cut short.
  double _fittingNameSize(
    BuildContext context,
    BoxConstraints box,
    TextScaler scaler,
  ) {
    if (!box.hasBoundedHeight) return _nameFontSize;
    final textWidth = box.maxWidth - _textInset * 2;
    double height(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: textWidth);
      final h = painter.height;
      painter.dispose();
      return h;
    }

    final room =
        box.maxHeight -
        _minPhotoHeight -
        _gap -
        2 -
        height(formatUzs(product.priceUzs), _priceStyle);
    var size = _nameFontSize;
    while (size > _minNameFontSize &&
        height(product.name, _nameStyle(size)) > room) {
      size -= 0.5;
    }
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final inCart = qtyInCart > 0;
    return Material(
      color: NocturneColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inCart ? NocturneColors.accent : NocturneColors.divider,
            ),
          ),
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final scaler = MediaQuery.textScalerOf(context);
                  final nameStyle = _nameStyle(
                    _fittingNameSize(context, box, scaler),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Takes whatever height the name and price leave, so
                      // every tile is the same size with or without a photo.
                      Expanded(child: ProductImage(product: product)),
                      const SizedBox(height: _gap),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _textInset,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // The name is what the cashier reads — never cut.
                            // At least two lines tall so a short name doesn't
                            // make its photo taller than the row's others; a
                            // longer one shrinks the photo instead.
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: scaler.scale(
                                  _nameFontSize * _nameLineHeight * 2,
                                ),
                              ),
                              child: Text(product.name, style: nameStyle),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatUzs(product.priceUzs),
                              style: _priceStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (inCart)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: NocturneColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$qtyInCart',
                      style: TextStyle(
                        color: NocturneColors.neutral100,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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

/// The tile's photo, whole and centered in its box — scaled to fit, never
/// cropped or stretched. No photo, still loading, or failed → the icon.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final fallback = _ProductIconFallback(icon: product.icon);
    final url = product.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: url == null
          ? fallback
          : LayoutBuilder(
              builder: (context, constraints) => Image.network(
                url,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                width: double.infinity,
                height: double.infinity,
                // Decode at tile size, not the photo's full resolution: a
                // 2000px upload costs the memory of a ~200px thumbnail.
                cacheWidth: _cacheWidth(
                  constraints.maxWidth,
                  MediaQuery.devicePixelRatioOf(context),
                ),
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                    wasSynchronouslyLoaded || frame != null ? child : fallback,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
    );
  }

  /// Rounded up to a 64px bucket so resizing the window by a few pixels
  /// reuses the decoded image instead of decoding it again.
  static int? _cacheWidth(double logicalWidth, double devicePixelRatio) {
    if (!logicalWidth.isFinite || logicalWidth <= 0) return null;
    final px = logicalWidth * devicePixelRatio;
    return ((px / 64).ceil() * 64).clamp(64, 1024);
  }
}

/// The no-photo look: the product's icon on a soft blue tint.
class _ProductIconFallback extends StatelessWidget {
  const _ProductIconFallback({required this.icon});

  final String icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: NocturneColors.accent900,
      child: Center(
        // Scales down when a long name leaves the photo box short.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Icon(
            productIconFor(icon),
            size: 32,
            color: NocturneColors.accent,
          ),
        ),
      ),
    );
  }
}
