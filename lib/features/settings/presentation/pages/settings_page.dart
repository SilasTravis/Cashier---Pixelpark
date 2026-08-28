import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:printing/printing.dart';

import '../../../../core/local_source/local_source.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/update/update_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../injector_container.dart';
import '../../../../router/app_navigator.dart';
import '../../../../generated/l10n.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../bloc/update_cubit.dart';
import '../widgets/update_card.dart';

/// The design's sidebar has no logout affordance (just a bare "Kassa 2 ·
/// Zaira" label) — this app needs one, so it lives here instead: cashier +
/// branch identity, app version, and the sign-out action.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await sl<AuthRepository>().logout();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(Routes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final local = sl<LocalSource>();
    final l10n = AppLocalization.of(context);
    final compact = breakpointOfContext(context) == Breakpoint.compact;
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 20 : 24),
                decoration: BoxDecoration(
                  color: NocturneColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadow.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: compact ? 24 : 28,
                          backgroundColor: NocturneColors.accent.withValues(
                            alpha: 0.15,
                          ),
                          child: Text(
                            (local.getCashierFullName() ?? '?').isEmpty
                                ? '?'
                                : local.getCashierFullName()![0].toUpperCase(),
                            style: const TextStyle(
                              color: NocturneColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                local.getCashierFullName() ?? '',
                                style: AppTextStyles.h5,
                              ),
                              Text(
                                '@${local.getCashierUsername() ?? ''}',
                                style: AppTextStyles.muted(
                                  AppTextStyles.body,
                                ).copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 36),
                    _InfoRow(
                      label: l10n.branch,
                      value: local.getBranchName() ?? '',
                    ),
                    const SizedBox(height: 10),
                    _AppVersionRow(label: l10n.version),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _PrinterSettingsCard(),
              const SizedBox(height: 16),
              BlocProvider<UpdateCubit>(
                create: (_) => UpdateCubit(sl<UpdateService>()),
                child: const UpdateCard(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(PhosphorIconsRegular.signOut, size: 16),
                  label: Text(l10n.logout),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrinterSettingsCard extends StatefulWidget {
  const _PrinterSettingsCard();

  @override
  State<_PrinterSettingsCard> createState() => _PrinterSettingsCardState();
}

class _PrinterSettingsCardState extends State<_PrinterSettingsCard> {
  static const _automatic = '__automatic__';
  late Future<List<Printer>> _printers;

  @override
  void initState() {
    super.initState();
    _printers = Printing.listPrinters();
  }

  void _refresh() => setState(() => _printers = Printing.listPrinters());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final local = sl<LocalSource>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.sm,
      ),
      child: FutureBuilder<List<Printer>>(
        future: _printers,
        builder: (context, snapshot) {
          final printers = snapshot.data ?? const <Printer>[];
          final names = printers.map((printer) => printer.name).toSet();
          final qrValue = names.contains(local.getQrPrinterName())
              ? local.getQrPrinterName()!
              : _automatic;
          final receiptValue = names.contains(local.getReceiptPrinterName())
              ? local.getReceiptPrinterName()!
              : _automatic;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.printer,
                    color: NocturneColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l10n.printerSettings, style: AppTextStyles.h5),
                  ),
                  IconButton(
                    tooltip: l10n.refresh,
                    onPressed:
                        snapshot.connectionState == ConnectionState.waiting
                        ? null
                        : _refresh,
                    icon: snapshot.connectionState == ConnectionState.waiting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            PhosphorIconsRegular.arrowsClockwise,
                            size: 17,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _printerDropdown(
                label: l10n.qrPrinter,
                automaticLabel: l10n.automaticGodex,
                value: qrValue,
                printers: printers,
                onChanged: (value) async {
                  await local.setQrPrinterName(
                    value == _automatic ? null : value,
                  );
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 12),
              _printerDropdown(
                label: l10n.receiptPrinter,
                automaticLabel: l10n.automaticSewoo,
                value: receiptValue,
                printers: printers,
                onChanged: (value) async {
                  await local.setReceiptPrinterName(
                    value == _automatic ? null : value,
                  );
                  if (mounted) setState(() {});
                },
              ),
              if (snapshot.hasData && printers.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.noPrintersFound,
                  style: AppTextStyles.muted(
                    AppTextStyles.body,
                  ).copyWith(fontSize: 12),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _printerDropdown({
    required String label,
    required String automaticLabel,
    required String value,
    required List<Printer> printers,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(PhosphorIconsRegular.printer, size: 18),
    ),
    items: [
      DropdownMenuItem(value: _automatic, child: Text(automaticLabel)),
      for (final printer in printers)
        DropdownMenuItem(
          value: printer.name,
          child: Text(printer.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (value) {
      if (value != null) onChanged(value);
    },
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.muted(AppTextStyles.body)),
        const Spacer(),
        Text(value, style: AppTextStyles.body.copyWith(fontSize: 14)),
      ],
    );
  }
}

class _AppVersionRow extends StatelessWidget {
  const _AppVersionRow({required this.label});

  final String label;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '—';
        return _InfoRow(label: label, value: version);
      },
    );
  }
}
