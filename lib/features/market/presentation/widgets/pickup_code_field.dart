import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../generated/l10n.dart';

/// The market "Olish kodi" input — same scanner-gun contract as the
/// Promokod field: the cashier fires the handheld gun at the QR in the
/// parent's app, the gun "types" the 6 digits and ends with Enter (or Tab,
/// depending on its setup); both submit here and are swallowed. Typing by
/// hand works the same way. The field clears itself after each submit and
/// keeps focus for the next scan.
class PickupCodeField extends StatefulWidget {
  const PickupCodeField({
    super.key,
    required this.focusNode,
    required this.onSubmit,
    this.busy = false,
    this.errorText,
  });

  /// Owned by the page, so it can pull focus back after a button press.
  final FocusNode focusNode;

  /// Raw text as scanned/typed — normalisation happens in the cubit.
  final ValueChanged<String> onSubmit;
  final bool busy;
  final String? errorText;

  @override
  State<PickupCodeField> createState() => _PickupCodeFieldState();
}

class _PickupCodeFieldState extends State<PickupCodeField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.focusNode.onKeyEvent = _onKeyEvent;
  }

  /// A Tab suffix would otherwise move focus away mid-scan; treat it like
  /// Enter.
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
    widget.focusNode.requestFocus();
  }

  @override
  void dispose() {
    widget.focusNode.onKeyEvent = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      autofocus: true,
      // Never disabled while [busy]: a disabled field drops focus, and the
      // next scan would then type into nothing.
      keyboardType: TextInputType.number,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.done,
      // Room for a scanner's prefix byte or spaces; the cubit keeps digits.
      inputFormatters: [LengthLimitingTextInputFormatter(32)],
      onSubmitted: (_) => _submit(),
      style: AppTextStyles.h4.copyWith(
        letterSpacing: 4,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: l10n.marketCodeLabel,
        hintText: l10n.marketCodeHint,
        hintStyle: AppTextStyles.muted(AppTextStyles.body),
        errorText: widget.errorText,
        errorMaxLines: 2,
        prefixIcon: const Icon(PhosphorIconsRegular.qrCode),
        suffixIcon: widget.busy
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: l10n.marketCodeFind,
                onPressed: _submit,
                icon: const Icon(
                  PhosphorIconsRegular.arrowRight,
                  color: NocturneColors.accent,
                ),
              ),
      ),
    );
  }
}
