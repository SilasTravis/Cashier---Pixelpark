import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../generated/l10n.dart';
import '../theme/pos_palette.dart';
import '../utils/responsive.dart';

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
    this.onPick,
    this.pickCount,
  });

  /// Raw text as scanned/typed — normalisation and validation (shape, Luhn)
  /// happen in the bloc.
  final ValueChanged<String> onSubmit;
  final bool busy;
  final String? errorText;
  final bool autofocus;

  /// Opens the customer's "Faol promokodlar" list. While the field is empty
  /// a button for it sits under the field; once text is typed that button
  /// becomes "Tekshirish". Null hides the list button (no customer open).
  final VoidCallback? onPick;

  /// How many active codes the customer has (null = not loaded yet) — shown
  /// on the list button so the cashier knows before opening it.
  final int? pickCount;

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
    final p = PosPalette.of(context);
    // Same look as the phone field right below it: a small caption, then a
    // 56px (48px compact) rounded box that turns blue while focused.
    final compact = breakpointOfContext(context) == Breakpoint.compact;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.promoCode, style: p.bodyMuted.copyWith(fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          key: const ValueKey('promo-code-input'),
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
          style: p.body.copyWith(
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: p.surface,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: compact ? 14 : 18,
            ),
            hintText: l10n.promoCodeHint,
            hintStyle: p.bodyMuted.copyWith(
              fontSize: compact ? 14 : 15,
              letterSpacing: 0,
              fontWeight: FontWeight.w400,
            ),
            errorText: widget.errorText,
            errorMaxLines: 2,
            border: border(p.borderStrong),
            enabledBorder: border(p.borderStrong),
            focusedBorder: border(p.accent, 2),
            errorBorder: border(p.danger),
            focusedErrorBorder: border(p.danger, 2),
            prefixIcon: Icon(
              PhosphorIconsRegular.qrCode,
              size: 20,
              color: p.textMuted,
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            suffixIcon: widget.busy
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        // Typed text → "Tekshirish"; empty → the customer's active codes, so
        // a cashier who isn't quick on the keyboard can pick the code that
        // matches the customer's SMS instead of typing it.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final hasText = value.text.trim().isNotEmpty;
            if (!hasText && widget.onPick == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: hasText
                  ? FilledButton(
                      key: const ValueKey('promo-code-check'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: widget.busy ? null : _submit,
                      child: Text(l10n.promoCodeCheck),
                    )
                  : OutlinedButton.icon(
                      key: const ValueKey('promo-code-pick'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        foregroundColor: p.accent,
                        side: BorderSide(color: p.accent),
                      ),
                      icon: const Icon(PhosphorIconsRegular.ticket, size: 18),
                      label: Text(
                        (widget.pickCount ?? 0) > 0
                            ? '${l10n.promoCodeActive} (${widget.pickCount})'
                            : l10n.promoCodeActive,
                      ),
                      onPressed: widget.busy ? null : widget.onPick,
                    ),
            );
          },
        ),
      ],
    );
  }
}
