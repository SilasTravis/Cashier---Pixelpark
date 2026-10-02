String formatPhoneNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final local = digits.startsWith('998') && digits.length == 12
      ? digits.substring(3)
      : digits;

  if (local.length == 9) {
    return '+998 ${local.substring(0, 2)} ${local.substring(2, 5)} '
        '${local.substring(5, 7)} ${local.substring(7, 9)}';
  }

  return value.trim();
}
