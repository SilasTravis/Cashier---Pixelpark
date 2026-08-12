import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../domain/gate_pass.dart';

/// Shows one QR "slip" card per issued gate pass — mirrors the design's
/// per-child receipt cards, child name in small type beneath the code.
Future<void> showGatePassSlipDialog(
  BuildContext context,
  IssuedPasses issued,
  Map<String, String> childNamesById,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: NocturneColors.surface,
        title: const Text('QR kartalar tayyor', style: AppTextStyles.h4),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final pass in issued.passes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NocturneColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: NocturneColors.divider),
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: pass.code,
                            size: 160,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          Text(pass.planLabel, style: AppTextStyles.h5),
                          const SizedBox(height: 2),
                          Text(
                            childNamesById[pass.childId] ?? '',
                            style: AppTextStyles.muted(
                              AppTextStyles.body,
                            ).copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${pass.priceUzs} so\'m',
                            style: AppTextStyles.muted(
                              AppTextStyles.body,
                            ).copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Yopish'),
          ),
        ],
      );
    },
  );
}
