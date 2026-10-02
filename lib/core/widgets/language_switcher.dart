import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../generated/l10n.dart';
import '../localization/locale_cubit.dart';
import '../theme/app_text_styles.dart';
import '../theme/nocturne_colors.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    LocaleCubit localeCubit;
    try {
      localeCubit = context.read<LocaleCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }

    return BlocBuilder<LocaleCubit, Locale>(
      bloc: localeCubit,
      builder: (context, locale) =>
          _buildSwitcher(context, localeCubit, locale.languageCode),
    );
  }

  Widget _buildSwitcher(
    BuildContext context,
    LocaleCubit localeCubit,
    String languageCode,
  ) {
    final l10n = AppLocalization.of(context);
    return PopupMenuButton<String>(
      tooltip: l10n.language,
      initialValue: languageCode,
      onSelected: localeCubit.changeLanguage,
      position: PopupMenuPosition.under,
      color: NocturneColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: NocturneColors.divider),
      ),
      itemBuilder: (_) => [
        _item('uz', 'UZ', l10n.languageUzbek, languageCode),
        _item('ru', 'RU', l10n.languageRussian, languageCode),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: NocturneColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: NocturneColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsRegular.translate,
              size: 16,
              color: NocturneColors.accent,
            ),
            const SizedBox(width: 7),
            Text(
              languageCode.toUpperCase(),
              style: AppTextStyles.body.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(PhosphorIconsRegular.caretDown, size: 12),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(
    String value,
    String code,
    String label,
    String selected,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            code,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(label)),
        if (selected == value)
          const Icon(
            PhosphorIconsRegular.check,
            size: 16,
            color: NocturneColors.accent,
          ),
      ],
    ),
  );
}
