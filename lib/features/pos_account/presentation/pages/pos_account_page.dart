import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../injector_container.dart';
import '../bloc/pos_account_bloc.dart';
import '../widgets/customer_detail_panel.dart';
import '../widgets/customer_results_list.dart';
import '../widgets/phone_keypad.dart';
import '../widgets/topup_panel.dart';

class PosAccountPage extends StatelessWidget {
  const PosAccountPage({super.key});

  static const _searchPanel = ResponsivePanel(
    compact: 260,
    standard: 286,
    wide: 320,
  );
  static const _topupPanel = ResponsivePanel(
    compact: 260,
    standard: 300,
    wide: 330,
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PosAccountBloc>(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: _searchPanel.of(context),
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: NocturneColors.divider)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [const PhoneKeypad(), const CustomerResultsList()],
              ),
            ),
          ),
          const Expanded(child: CustomerDetailPanel()),
          Container(
            width: _topupPanel.of(context),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: NocturneColors.divider)),
            ),
            child: const TopupPanel(),
          ),
        ],
      ),
    );
  }
}
