import 'package:flutter/services.dart';

/// Formats a so'm amount with thin thousands-grouping spaces, matching the
/// design's `25 000 so'm` style — e.g. `formatUzs(145000) == "145 000 so'm"`.
String formatUzs(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final posFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(' ');
  }
  return "${amount < 0 ? '-' : ''}${buffer.toString()} so'm";
}

/// Digits grouped by three with plain spaces — `groupDigits(80000) ==
/// "80 000"`. What [ThousandsInputFormatter] shows in an amount field.
String groupDigits(int amount) => formatUzs(amount).replaceAll(" so'm", '');

/// Reads an amount typed into a [ThousandsInputFormatter] field (or any
/// digits-only text) — grouping spaces are ignored; null when empty.
int? parseUzs(String text) => int.tryParse(text.replaceAll(' ', ''));

/// Keeps an amount field digits-only and grouped by three as the cashier
/// types ("80000" → "80 000"), keeping the caret next to the same digit.
class ThousandsInputFormatter extends TextInputFormatter {
  const ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = groupDigits(int.parse(digits));
    // Digits left of the caret before formatting → same count after it.
    final caret = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final digitsBefore = newValue.text
        .substring(0, caret)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    var offset = 0;
    var seen = 0;
    while (offset < text.length && seen < digitsBefore) {
      if (text[offset] != ' ') seen++;
      offset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
