import 'package:flutter/material.dart';

import '../../generated/l10n.dart';
import '../../router/app_navigator.dart';

/// A failed job can finish after the checkout widget or navigator is gone.
void showParkingReceiptNotice() {
  final context = rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = AppLocalization.maybeOf(context);
  if (messenger == null || !messenger.mounted || l10n == null) return;
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      content: Text(l10n.parkingReceiptUnconfirmed),
    ),
  );
}
