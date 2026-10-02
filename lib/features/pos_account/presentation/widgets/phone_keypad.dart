import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../bloc/pos_account_bloc.dart';
import '../../../../generated/l10n.dart';

const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];

/// Phone entry + keypad — no search button. Typing debounces into a live
/// search (see `PosAccountBloc._scheduleAutoSearch`); the magnifying glass
/// here just reflects that a search is in flight.
class PhoneKeypad extends StatelessWidget {
  const PhoneKeypad({super.key});

  String _formatPhone(String digits) {
    final buffer = StringBuffer('+998 ');
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if (i == 1 || i == 4 || i == 6) buffer.write(' ');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosAccountBloc, PosAccountState>(
      buildWhen: (previous, current) =>
          previous.phoneDigits != current.phoneDigits ||
          previous.isSearching != current.isSearching,
      builder: (context, state) {
        final bloc = context.read<PosAccountBloc>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: NocturneColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NocturneColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.phoneDigits.isEmpty
                          ? '+998'
                          : _formatPhone(state.phoneDigits),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h4.copyWith(
                        fontSize:
                            breakpointOfContext(context) == Breakpoint.compact
                            ? 16
                            : null,
                      ),
                    ),
                  ),
                  if (state.isSearching)
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 15,
                      color: NocturneColors.accent400,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
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
            const SizedBox(height: 10),
            Text(
              AppLocalization.of(context).keypadHint,
              style: AppTextStyles.body.copyWith(
                fontSize: 11,
                color: NocturneColors.text.withValues(alpha: 0.45),
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
    return Material(
      color: NocturneColors.bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(child: Text(label, style: AppTextStyles.h5)),
      ),
    );
  }
}
