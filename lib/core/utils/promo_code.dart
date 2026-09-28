/// Partner promo codes — 16 decimal digits, the last a Luhn check digit.
///
/// Digits only on purpose: the scanner gun "types" the QR through the OS
/// keyboard layout, and letters come out Cyrillic on a Russian layout or
/// flipped by Caps Lock, while digits are layout-independent. Mirrors the
/// backend's `partners/domain/promo-code-format.ts` exactly (shared test
/// vectors in `test/promo_code_test.dart`).
const promoCodeLength = 16;

/// Everything but digits dropped — the display form `4821 7730 1956 0342`,
/// dashes and a scanner's trailing CR/LF/Tab all normalise alike.
String normalizePromoCode(String raw) => raw.replaceAll(RegExp(r'\D'), '');

/// The Luhn check digit of [payload] (the digits WITHOUT the check digit).
int luhnCheckDigit(String payload) {
  var sum = 0;
  for (var i = 0; i < payload.length; i++) {
    var digit = payload.codeUnitAt(payload.length - 1 - i) - 48;
    if (i.isEven) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
  }
  return (10 - sum % 10) % 10;
}

/// Exactly 16 digits whose last is the Luhn digit of the first 15 — checked
/// locally so a mistyped code, or a gate-pass sticker scanned into the wrong
/// field, never costs a request. Expects an already-normalised value.
bool isValidPromoCode(String digits) {
  if (!RegExp(r'^\d{16}$').hasMatch(digits)) return false;
  return luhnCheckDigit(digits.substring(0, promoCodeLength - 1)) ==
      digits.codeUnitAt(promoCodeLength - 1) - 48;
}

/// `4821773019560342` → `4821 7730 1956 0342`.
String formatPromoCode(String digits) =>
    digits.replaceAllMapped(RegExp(r'(\d{4})(?=\d)'), (m) => '${m[1]} ');
