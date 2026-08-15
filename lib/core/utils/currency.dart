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
