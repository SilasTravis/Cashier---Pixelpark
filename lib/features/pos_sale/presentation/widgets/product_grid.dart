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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: inCart ? NocturneColors.accent : NocturneColors.divider,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    productIconFor(product.icon),
                    size: 28,
                    color: NocturneColors.accent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.name,
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatUzs(product.priceUzs),
                    style: AppTextStyles.muted(
                      AppTextStyles.body,
                    ).copyWith(fontSize: 12),
                  ),
                ],
              ),
              if (inCart)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: NocturneColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$qtyInCart',
                      style: const TextStyle(
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
