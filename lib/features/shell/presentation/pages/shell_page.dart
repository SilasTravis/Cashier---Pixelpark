import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/local_source/local_source.dart';
import '../../../../core/offline/app_mode_cubit.dart';
import '../../../../core/offline/widgets/mode_prompt_host.dart';
import '../../../../core/offline/widgets/offline_banner.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/update/update_service.dart';
import '../../../../injector_container.dart';
import '../../../offline/data/offline_store.dart';
import '../../../offline/presentation/pages/unsynced_sales_page.dart';
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
import '../../../pos_account/domain/customer.dart';

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
  Customer? _initialCustomer;
  bool? _sidebarCollapsed;

  @override
  void initState() {
    super.initState();
    // Queue counts belong to whoever just signed in.
    context.read<AppModeCubit>().refreshCounts();
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<AppModeCubit>().state;
    final tabs = [
      ...ShellTab.primary,
      if (mode.queuedCount > 0 || _tab == ShellTab.unsynced) ShellTab.unsynced,
    ];
    final disabled = mode.isOffline
        ? {
            for (final tab in ShellTab.values)
              if (tab.needsInternet) tab,
          }
        : const <ShellTab>{};
    final tab = disabled.contains(_tab) ? ShellTab.posSale : _tab;
    return BlocListener<AppModeCubit, AppModeState>(
      // Online again (after sync) → load the real server shift; offline →
      // switch the shift source to the cache / offline shift.
      listenWhen: (previous, current) =>
          previous.isOffline != current.isOffline,
      listener: (context, _) =>
          context.read<ShiftBloc>().add(const ShiftRefreshed()),
      child: ModePromptHost(
        onShowUnsynced: () => setState(() => _tab = ShellTab.unsynced),
        child: Scaffold(
          backgroundColor: NocturneColors.bg,
          body: Column(
            children: [
              const TitleBar(),
              const Divider(height: 1),
              const OfflineBanner(),
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
                          onToggle: () => setState(
                            () => _sidebarCollapsed = !sidebarCollapsed,
                          ),
                          selected: tab,
                          tabs: tabs,
                          disabledTabs: disabled,
                          counts: {ShellTab.unsynced: mode.queuedCount},
                          onSelect: (picked) => setState(() {
                            _tab = picked;
                            if (picked == ShellTab.posAccount) {
                              _initialCustomer = null;
                            }
                          }),
                          cashierName:
                              sl<LocalSource>().getCashierFullName() ?? '',
                          shiftOpenedAt: state.shift?.openedAt,
                          closeShiftDisabledReason: AppLocalization.of(
                            context,
                          ).closeShiftOffline,
                          onCloseShift: mode.isOffline
                              ? null
                              : () =>
                                    showCloseShiftDialog(context, state.shift!),
                          updateAvailable: sl<UpdateService>().hasUpdate,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              HeaderBar(tab: tab, shift: state.shift),
                              Expanded(
                                child: _TabContent(
                                  tab: tab,
                                  initialCustomer: _initialCustomer,
                                  onOpenCustomer: (customer) => setState(() {
                                    _initialCustomer = customer;
                                    _tab = ShellTab.posAccount;
                                  }),
                                ),
                              ),
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
        ),
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.tab,
    required this.initialCustomer,
    required this.onOpenCustomer,
  });

  final ShellTab tab;
  final Customer? initialCustomer;
  final ValueChanged<Customer> onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      ShellTab.posAccount => PosAccountPage(
        key: ValueKey(initialCustomer?.id),
        initialCustomer: initialCustomer,
      ),
      ShellTab.posSale => const PosSalePage(),
      ShellTab.salesHistory => SalesHistoryPage(onOpenCustomer: onOpenCustomer),
      ShellTab.visitHistory => VisitHistoryPage(onOpenCustomer: onOpenCustomer),
      ShellTab.inside => const InsidePage(),
      ShellTab.settings => const SettingsPage(),
      ShellTab.unsynced => UnsyncedSalesPage(
        store: sl<OfflineStore>(),
        cashierId: sl<LocalSource>().getCashierId(),
      ),
    };
  }
}
