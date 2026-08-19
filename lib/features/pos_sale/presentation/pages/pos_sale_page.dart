import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../injector_container.dart';
import '../bloc/pos_sale_bloc.dart';
import '../widgets/cart_panel.dart';
import '../widgets/category_filter.dart';
import '../widgets/product_grid.dart';

class PosSalePage extends StatelessWidget {
  const PosSalePage({super.key});

  static const _cartPanel = ResponsivePanel(
    compact: 272,
    standard: 330,
    wide: 360,
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PosSaleBloc>()..add(const PosSaleStarted()),
      child: Padding(
        padding: breakpointOfContext(context) == Breakpoint.compact
            ? const EdgeInsets.fromLTRB(12, 12, 12, 14)
            : const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CategoryFilter(),
                  const SizedBox(height: 12),
                  const Expanded(child: ProductGrid()),
                ],
              ),
            ),
            SizedBox(
              width: breakpointOfContext(context) == Breakpoint.compact
                  ? 12
                  : 16,
            ),
            Container(
              width: _cartPanel.of(context),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: NocturneColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadow.sm,
              ),
              child: const CartPanel(),
            ),
          ],
        ),
      ),
    );
  }
}
