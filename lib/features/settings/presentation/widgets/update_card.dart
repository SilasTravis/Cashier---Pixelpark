import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/update/update_exception.dart';
import '../../../../generated/l10n.dart';
import '../bloc/update_cubit.dart';

/// Settings → Update: check for a newer release, download it, and restart
/// into it. The restart is always confirmed first — the cashier has an open
/// shift by construction, since Settings is only reachable from the shell.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  Future<void> _confirmAndRestart(BuildContext context) async {
    final l10n = AppLocalization.of(context);
    final cubit = context.read<UpdateCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.updateConfirmTitle),
        content: Text(l10n.updateConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.updateCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.updateConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.restart();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.sm,
      ),
      child: BlocBuilder<UpdateCubit, UpdateState>(
        builder: (context, state) {
          final cubit = context.read<UpdateCubit>();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.arrowCircleUp,
                    color: NocturneColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l10n.updateTitle, style: AppTextStyles.h5),
                  ),
                  Text(
                    cubit.currentVersion,
                    style: AppTextStyles.muted(
                      AppTextStyles.body,
                    ).copyWith(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._body(context, state, cubit, l10n),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    UpdateState state,
    UpdateCubit cubit,
    AppLocalization l10n,
  ) {
    switch (state) {
      case UpdateIdle():
        return [_checkButton(cubit, l10n)];

      case UpdateChecking():
        return [
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ];

      case UpdateUpToDate():
        return [
          _note(l10n.updateUpToDate),
          const SizedBox(height: 12),
          _checkButton(cubit, l10n),
        ];

      case UpdateAvailable(:final release):
        return [
          Text(
            l10n.updateAvailable(release.version),
            style: AppTextStyles.body.copyWith(fontSize: 14),
          ),
          if (release.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              release.notes,
              style: AppTextStyles.muted(
                AppTextStyles.body,
              ).copyWith(fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              // Disabled rather than hidden off-Windows: the button stays
              // inspectable/testable, but a cashier or dev machine running
              // macOS/Linux can never trigger a real download that could
              // only fail later at restart (see UpdateService.applyAndRestart).
              onPressed: Platform.isWindows
                  ? () => cubit.download(release)
                  : null,
              icon: const Icon(PhosphorIconsRegular.downloadSimple, size: 16),
              label: Text(l10n.updateDownload),
            ),
          ),
          if (!Platform.isWindows) ...[
            const SizedBox(height: 8),
            _note(l10n.updateWindowsOnly),
          ],
        ];

      case UpdateDownloading(:final received, :final total, :final fraction):
        return [
          Text(
            l10n.updateDownloading,
            style: AppTextStyles.body.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: fraction),
          const SizedBox(height: 6),
          _note('${_mb(received)} / ${_mb(total)} MB'),
        ];

      case UpdateReadyToRestart():
        return [
          Text(
            l10n.updateReady,
            style: AppTextStyles.body.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: () => _confirmAndRestart(context),
              icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 16),
              label: Text(l10n.updateRestart),
            ),
          ),
        ];

      // Two failure branches, because the cubit deliberately gives the
      // "unexpected" case no displayable message: a raw DioException string
      // ("Failed host lookup: 'api.github.com' … uri=…") must never reach a
      // cashier in an otherwise fully localized app. Its detail is
      // diagnostics-only; the UI supplies its own localized generic text.
      //
      // UpdateFailureKnown.message is likewise developer-facing English
      // only (see update_exception.dart) — `code` is what gets rendered,
      // mapped to a fully localized ARB string by `_knownFailureText`.
      case UpdateFailureKnown(
        :final code,
        :final message,
        :final releasePageUrl,
      ):
        return _failureBody(
          '${l10n.updateFailed}: ${_knownFailureText(l10n, code, message)}',
          releasePageUrl,
          cubit,
          l10n,
        );

      case UpdateFailureUnexpected(:final releasePageUrl):
        return _failureBody(
          l10n.updateFailedGeneric,
          releasePageUrl,
          cubit,
          l10n,
        );
    }
  }

  /// Maps the closed set of [UpdateFailureCode]s to fully localized,
  /// cashier-facing text — never [devMessage], which is English and
  /// developer-facing only. [UpdateFailureCode.unsupportedPlatform] reuses
  /// [AppLocalization.updateWindowsOnly], the same string already shown as
  /// the Windows-only note elsewhere on this card, rather than duplicating
  /// a near-identical ARB entry.
  ///
  /// [UpdateFailureCode.other] is the one deliberate exception: no
  /// production throw site in this codebase should ever reach it (each of
  /// the five real cases above already has a localized entry), so falling
  /// back to the raw English [devMessage] here is a safety net for an
  /// uncategorized case, not a sanctioned display path.
  String _knownFailureText(
    AppLocalization l10n,
    UpdateFailureCode code,
    String devMessage,
  ) {
    switch (code) {
      case UpdateFailureCode.checksumMismatch:
        return l10n.updateFailureChecksumMismatch;
      case UpdateFailureCode.checksumUnreadable:
        return l10n.updateFailureChecksumUnreadable;
      case UpdateFailureCode.executableMissing:
        return l10n.updateFailureExecutableMissing;
      case UpdateFailureCode.incompleteExtraction:
        return l10n.updateFailureIncompleteExtraction;
      case UpdateFailureCode.unsupportedPlatform:
        return l10n.updateWindowsOnly;
      case UpdateFailureCode.other:
        return devMessage;
    }
  }

  List<Widget> _failureBody(
    String text,
    String? releasePageUrl,
    UpdateCubit cubit,
    AppLocalization l10n,
  ) {
    return [
      Text(
        text,
        style: AppTextStyles.body.copyWith(
          fontSize: 13,
          color: NocturneColors.danger,
        ),
      ),
      if (releasePageUrl != null && releasePageUrl.isNotEmpty) ...[
        const SizedBox(height: 10),
        _note(l10n.updateManualHint),
        const SizedBox(height: 4),
        SelectableText(
          releasePageUrl,
          style: AppTextStyles.body.copyWith(
            fontSize: 12,
            color: NocturneColors.accent,
          ),
        ),
      ],
      const SizedBox(height: 12),
      _checkButton(cubit, l10n),
    ];
  }

  Widget _checkButton(UpdateCubit cubit, AppLocalization l10n) => SizedBox(
    height: 44,
    child: OutlinedButton.icon(
      onPressed: cubit.check,
      icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 16),
      label: Text(l10n.updateCheck),
    ),
  );

  Widget _note(String text) => Text(
    text,
    style: AppTextStyles.muted(AppTextStyles.body).copyWith(fontSize: 12),
  );

  static String _mb(int bytes) => (bytes / 1048576).toStringAsFixed(1);
}
