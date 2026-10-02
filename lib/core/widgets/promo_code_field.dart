import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../generated/l10n.dart';
import '../theme/app_text_styles.dart';
import '../theme/nocturne_colors.dart';

/// The cashier's "Promokod" input. The cashier focuses it and fires the
/// handheld scanner gun at the partner app's QR: the gun "types" the 16
/// digits and ends with Enter (or Tab, depending on its setup) — both submit
/// here and are swallowed, so the suffix never presses another control.
/// A blogger code (`ALI20`) is typed by hand, in any keyboard layout — the
/// bloc maps Russian-layout letters back to Latin. The field clears itself
/// after each submit and keeps focus for the next scan.
class PromoCodeField extends StatefulWidget {
  const PromoCodeField({
    super.key,
    required this.onSubmit,
    this.busy = false,
    this.errorText,
    this.autofocus = false,
  });

  /// Raw text as scanned/typed — normalisation and validation (shape, Luhn)
  /// happen in the bloc.
  final ValueChanged<String> onSubmit;
  final bool busy;
  final String? errorText;
  final bool autofocus;

  @override
  State<PromoCodeField> createState() => _PromoCodeFieldState();
}

class _PromoCodeFieldState extends State<PromoCodeField> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _onKeyEvent);

  /// Scanners configured with a Tab suffix would otherwise move focus away
  /// mid-scan; treat Tab exactly like Enter.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit() {
    final raw = _controller.text;
    if (raw.trim().isEmpty || widget.busy) return;
    widget.onSubmit(raw);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          // Never disabled while [busy]: a disabled field drops focus, and
          // the next scan would then type into nothing.
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          // No character filter: blogger codes carry letters (Latin, or
          // Cyrillic from a Russian layout), and anything else must reach
          // the classifier to be refused — silently dropping, say, a '.'
          // would turn a wrong code into another one. 64 = the server's max.
          inputFormatters: [LengthLimitingTextInputFormatter(64)],
          onSubmitted: (_) => _submit(),
          style: AppTextStyles.body.copyWith(
            fontSize: 14,
            letterSpacing: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            isDense: true,
            labelText: l10n.promoCode,
            hintText: l10n.promoCodeHint,
            errorText: widget.errorText,
            errorMaxLines: 2,
            prefixIcon: const Icon(PhosphorIconsRegular.qrCode, size: 18),
            suffixIcon: widget.busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: l10n.promoCodeCheck,
                    onPressed: _submit,
                    icon: const Icon(
                      PhosphorIconsRegular.arrowRight,
                      size: 18,
                      color: NocturneColors.accent,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
