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
    compact: 280,
    standard: 330,
    wide: 360,
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PosSaleBloc>()..add(const PosSaleStarted()),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: CategoryFilter(),
                ),
                const Expanded(child: ProductGrid()),
              ],
            ),
          ),
          Container(
            width: _cartPanel.of(context),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: NocturneColors.divider)),
            ),
            child: const CartPanel(),
          ),
        ],
      ),
    );
  }
}
