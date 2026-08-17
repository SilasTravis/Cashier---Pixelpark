import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../injector_container.dart';
import '../bloc/products_bloc.dart';
import '../product_icon.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductsBloc>()..add(const ProductsStarted()),
      child: const _ProductsView(),
    );
  }
}

class _ProductsView extends StatelessWidget {
  const _ProductsView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            style: AppTextStyles.body,
            onChanged: (value) =>
                context.read<ProductsBloc>().add(ProductsSearchChanged(value)),
            decoration: const InputDecoration(
              hintText: 'Mahsulot qidirish',
              prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: BlocBuilder<ProductsBloc, ProductsState>(
            buildWhen: (previous, current) =>
                previous.categories != current.categories ||
                previous.selectedCategory != current.selectedCategory,
            builder: (context, state) {
              return SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CategoryChip(
                      label: 'Hammasi',
                      selected: state.selectedCategory == null,
                      onTap: () => context.read<ProductsBloc>().add(
                        const ProductsCategorySelected(null),
                      ),
                    ),
                    for (final category in state.categories)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _CategoryChip(
                          label: category,
                          selected: state.selectedCategory == category,
                          onTap: () => context.read<ProductsBloc>().add(
                            ProductsCategorySelected(category),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        Expanded(
          child: BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              if (state.errorMessage != null) {
                return Center(
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: NocturneColors.danger),
                  ),
                );
              }
              if (state.visibleProducts.isEmpty) {
                return Center(
                  child: Text(
                    'Mahsulot topilmadi',
                    style: AppTextStyles.muted(AppTextStyles.body),
                  ),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                itemCount: state.visibleProducts.length,
                itemBuilder: (context, index) {
                  final product = state.visibleProducts[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: NocturneColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NocturneColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              productIconFor(product.icon),
                              size: 22,
                              color: NocturneColors.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                product.category,
                                style: AppTextStyles.muted(
                                  AppTextStyles.body,
                                ).copyWith(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          product.name,
                          style: AppTextStyles.body.copyWith(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          formatUzs(product.priceUzs),
                          style: AppTextStyles.h6.copyWith(
                            color: NocturneColors.accent,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? NocturneColors.accent.withValues(alpha: 0.15)
          : NocturneColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? NocturneColors.accent : NocturneColors.divider,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              fontSize: 12,
              color: selected ? NocturneColors.accent : NocturneColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
