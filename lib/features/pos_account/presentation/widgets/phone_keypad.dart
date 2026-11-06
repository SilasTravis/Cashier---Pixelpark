import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/responsive.dart';
import '../bloc/pos_account_bloc.dart';
import '../../../../generated/l10n.dart';

const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];

/// Phone entry + keypad — no search button. Typing debounces into a live
/// search (see `PosAccountBloc._scheduleAutoSearch`); the magnifying glass
/// here just reflects that a search is in flight.
class PhoneKeypad extends StatelessWidget {
  const PhoneKeypad({super.key});

  String _formatPhone(String digits, {required bool foreign}) {
    // Foreign numbers vary in length per country — no fixed grouping.
    if (foreign) return '+$digits';
    final buffer = StringBuffer('+998 ');
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 1 || i == 4 || i == 6) buffer.write(' ');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final compact = breakpointOfContext(context) == Breakpoint.compact;
    return BlocBuilder<PosAccountBloc, PosAccountState>(
      buildWhen: (previous, current) =>
          previous.phoneDigits != current.phoneDigits ||
          previous.foreignPhone != current.foreignPhone ||
          previous.isSearching != current.isSearching,
      builder: (context, state) {
        final bloc = context.read<PosAccountBloc>();
        final typing = state.phoneDigits.isNotEmpty;
        final foreign = state.foreignPhone;
        final l10n = AppLocalization.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.phoneNumber, style: p.bodyMuted.copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            Container(
              height: compact ? 48 : 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: typing ? p.accent : p.borderStrong,
                  width: typing ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    // Never "+998 90 847 4…": a long number scales down to
                    // fit instead of being cut.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        typing
                            ? _formatPhone(state.phoneDigits, foreign: foreign)
                            : (foreign ? '+' : '+998'),
                        maxLines: 1,
                        softWrap: false,
                        style: AppTextStyles.h4.copyWith(
                          fontSize: compact ? 17 : 21,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: typing ? p.text : p.textFaint,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  if (state.isSearching)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 17,
                      color: typing ? p.accent : p.textFaint,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: compact ? 1.25 : 1.45,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final key in _keys)
                  key.isEmpty
                      ? const SizedBox.shrink()
                      : _KeypadButton(
                          label: key,
                          onTap: () {
                            if (key == '⌫') {
                              bloc.add(const PosAccountBackspacePressed());
                            } else {
                              bloc.add(PosAccountDigitPressed(key));
                            }
                          },
                        ),
              ],
            ),
            const SizedBox(height: 8),
            // Cashier-only: register a tourist with a non-+998 number.
            // Turning it on/off clears what was typed.
            Material(
              color: Colors.transparent,
              child: SwitchListTile.adaptive(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: foreign,
                activeTrackColor: p.accent,
                onChanged: (_) =>
                    bloc.add(const PosAccountForeignPhoneToggled()),
                title: Text(l10n.foreignPhone, style: p.body),
                secondary: Icon(
                  PhosphorIconsRegular.globe,
                  size: 18,
                  color: foreign ? p.accent : p.textMuted,
                ),
              ),
            ),
            if (foreign)
              Text(
                l10n.foreignPhoneHint,
                style: AppTextStyles.body.copyWith(
                  fontSize: 11,
                  color: p.textMuted,
                ),
              ),
            const SizedBox(height: 10),
            Text(
              l10n.keypadHint,
              style: AppTextStyles.body.copyWith(
                fontSize: 11,
                color: p.textFaint,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final isBackspace = label == '⌫';
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: p.accentSoft,
        splashColor: p.accentBorder,
        child: Center(
          child: isBackspace
              ? Icon(
                  PhosphorIconsRegular.backspace,
                  size: 20,
                  color: p.textMuted,
                )
              : Text(
                  label,
                  style: AppTextStyles.h4.copyWith(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
        ),
      ),
    );
  }
}
