String formatPhoneNumber(String value) {
  final trimmed = value.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  // A foreign number (cashier-registered, `+<country>…`) is shown as stored —
  // never squeezed into the Uzbek `+998 XX XXX XX XX` shape.
  if (trimmed.startsWith('+') && !digits.startsWith('998')) return trimmed;

  final local = digits.startsWith('998') && digits.length == 12
      ? digits.substring(3)
      : digits;

  if (local.length == 9) {
    return '+998 ${local.substring(0, 2)} ${local.substring(2, 5)} '
        '${local.substring(5, 7)} ${local.substring(7, 9)}';
  }

  return trimmed;
}
