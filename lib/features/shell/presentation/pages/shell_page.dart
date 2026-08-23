import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/local_source/local_source.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/update/update_service.dart';
import '../../../../injector_container.dart';
import '../../../pos_account/presentation/pages/pos_account_page.dart';
import '../../../inside/presentation/pages/inside_page.dart';
import '../../../pos_sale/presentation/pages/pos_sale_page.dart';
import '../../../sales_history/presentation/pages/sales_history_page.dart';
import '../../../visit_history/presentation/pages/visit_history_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../shift/presentation/bloc/shift_bloc.dart';
import '../model/shell_tab.dart';
import '../widgets/close_shift_dialog.dart';
import '../widgets/header_bar.dart';
import '../widgets/open_shift_dialog.dart';
import '../widgets/sidebar.dart';
import '../widgets/title_bar.dart';
import '../../../../generated/l10n.dart';

class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ShiftBloc>()..add(const ShiftStarted()),
      child: const _ShellView(),
    );
  }
}

class _ShellView extends StatefulWidget {
  const _ShellView();

  @override
  State<_ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<_ShellView> {
  ShellTab _tab = ShellTab.posAccount;
  bool? _sidebarCollapsed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NocturneColors.bg,
      body: Column(
        children: [
          const TitleBar(),
          const Divider(height: 1),
          Expanded(
            child: BlocConsumer<ShiftBloc, ShiftState>(
              listenWhen: (previous, current) =>
                  previous.lastClosed != current.lastClosed &&
                  current.lastClosed != null,
              listener: (context, state) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalization.of(context).shiftClosed),
                  ),
                );
              },
              builder: (context, state) {
                if (!state.hasOpenShift) {
                  return const OpenShiftPrompt();
                }
                final isCompact = MediaQuery.sizeOf(context).width < 1100;
                final sidebarCollapsed = _sidebarCollapsed ?? isCompact;
                return Row(
                  children: [
                    Sidebar(
                      collapsed: sidebarCollapsed,
                      onToggle: () =>
                          setState(() => _sidebarCollapsed = !sidebarCollapsed),
                      selected: _tab,
                      onSelect: (tab) => setState(() => _tab = tab),
                      cashierName: sl<LocalSource>().getCashierFullName() ?? '',
                      shiftOpenedAt: state.shift?.openedAt,
                      onCloseShift: () =>
                          showCloseShiftDialog(context, state.shift!),
                      updateAvailable: sl<UpdateService>().hasUpdate,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          HeaderBar(tab: _tab, shift: state.shift),
                          Expanded(child: _TabContent(tab: _tab)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.tab});

  final ShellTab tab;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      ShellTab.posAccount => const PosAccountPage(),
      ShellTab.posSale => const PosSalePage(),
      ShellTab.salesHistory => const SalesHistoryPage(),
      ShellTab.visitHistory => const VisitHistoryPage(),
      ShellTab.inside => const InsidePage(),
      ShellTab.settings => const SettingsPage(),
    };
  }
}
