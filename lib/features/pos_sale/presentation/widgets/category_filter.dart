import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../bloc/pos_sale_bloc.dart';

class CategoryFilter extends StatelessWidget {
  const CategoryFilter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosSaleBloc, PosSaleState>(
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
                onTap: () => context.read<PosSaleBloc>().add(
                  const PosSaleCategorySelected(null),
                ),
              ),
              for (final category in state.categories)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _CategoryChip(
                    label: category,
                    selected: state.selectedCategory == category,
                    onTap: () => context.read<PosSaleBloc>().add(
                      PosSaleCategorySelected(category),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
