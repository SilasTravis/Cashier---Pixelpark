import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../features/offline/application/offline_sync_service.dart';
import '../../../generated/l10n.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/nocturne_colors.dart';
import '../app_mode_cubit.dart';

/// Renders [AppModeCubit]'s prompts as confirm dialogs and shows each sync
/// result once. Lives in the shell so dialogs only appear to a signed-in
/// cashier; a prompt raised earlier (e.g. on the login screen) is shown as
/// soon as the shell mounts.
class ModePromptHost extends StatefulWidget {
  const ModePromptHost({super.key, required this.child, this.onShowUnsynced});

  final Widget child;
  final VoidCallback? onShowUnsynced;

  @override
  State<ModePromptHost> createState() => _ModePromptHostState();
}

class _ModePromptHostState extends State<ModePromptHost> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handle(context.read<AppModeCubit>().state),
    );
  }

  Future<void> _handle(AppModeState state) async {
    if (_open || !mounted) return;
    final cubit = context.read<AppModeCubit>();
    final l10n = AppLocalization.of(context);
    switch (state.prompt) {
      case ModePrompt.goOffline:
        final yes = await _confirm(
          icon: PhosphorIconsRegular.wifiSlash,
          title: l10n.offlinePromptTitle,
          body: l10n.offlinePromptBody,
          accept: l10n.offlinePromptAccept,
          decline: l10n.offlinePromptDecline,
        );
        if (yes) {
          await cubit.acceptOffline();
        } else {
          cubit.declineOffline();
        }
      case ModePrompt.goOnline:
        final yes = await _confirm(
          icon: PhosphorIconsRegular.cloudArrowUp,
          title: l10n.onlinePromptTitle,
          body: l10n.onlinePromptBody(state.queuedCount),
          accept: l10n.onlinePromptAccept,
          decline: l10n.onlinePromptLater,
        );
        if (yes) {
          await cubit.acceptOnline();
        } else {
          cubit.postponeOnline();
        }
      case ModePrompt.none:
        final report = state.lastReport;
        if (report == null) return;
        cubit.reportShown();
        if (report.syncedCount == 0 &&
            report.failed.isEmpty &&
            !report.transportFailed) {
          return;
        }
        await _showReport(report);
    }
  }

  Future<bool> _confirm({
    required IconData icon,
    required String title,
    required String body,
    required String accept,
    required String decline,
  }) async {
    _open = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NocturneColors.surface,
        icon: Icon(icon, color: NocturneColors.warning, size: 32),
        title: Text(title, style: AppTextStyles.h4),
        content: SizedBox(
          width: 360,
          child: Text(body, style: AppTextStyles.body),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(decline),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(accept),
          ),
        ],
      ),
    );
    _open = false;
    return result ?? false;
  }

  Future<void> _showReport(SyncReport report) async {
    _open = true;
    final l10n = AppLocalization.of(context);
    final showFailures =
        report.failed.isNotEmpty && widget.onShowUnsynced != null;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NocturneColors.surface,
        title: Text(l10n.syncResultTitle, style: AppTextStyles.h4),
        content: Text(
          report.transportFailed
              ? l10n.syncTransportFailed(report.transportError!)
              : l10n.syncResultBody(report.syncedCount, report.failed.length),
          style: AppTextStyles.body,
        ),
        actions: [
          if (showFailures)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onShowUnsynced!();
              },
              child: Text(l10n.syncViewFailures),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
    _open = false;
    if (mounted) _handle(context.read<AppModeCubit>().state);
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<AppModeCubit, AppModeState>(
        listenWhen: (previous, current) =>
            previous.prompt != current.prompt ||
            previous.lastReport != current.lastReport,
        listener: (_, state) => _handle(state),
        child: widget.child,
      );
}
