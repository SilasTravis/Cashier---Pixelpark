/// Promo codes typed into the till's single "Promokod" field. Two kinds:
///
/// * partner — 16 decimal digits, the last a Luhn check digit, minted per
///   customer by a partner's server (Fonus). Digits only on purpose: the
///   scanner gun "types" the QR through the OS keyboard layout, and digits
///   are layout-independent.
/// * blogger — a static, reusable code like `ALI20` (3–20 Latin letters and
///   digits, at least one letter), typed by hand.
///
/// Mirrors the backend's `normalizeAnyPromoCode` + classifier exactly
/// (shared test vectors in `test/promo_code_test.dart`).
const promoCodeLength = 16;

enum PromoCodeKind { partner, blogger }

/// Russian ЙЦУКЕН layout → the Latin letter on the SAME key, so a cashier
/// typing A-L-I-2-0 with the Russian layout active ("ФДШ20") still gets
/// "ALI20". Ё is deliberately not mapped (its key is a backtick).
const _ruToLatin = {
  'Й': 'Q', 'Ц': 'W', 'У': 'E', 'К': 'R', 'Е': 'T', 'Н': 'Y', 'Г': 'U', //
  'Ш': 'I', 'Щ': 'O', 'З': 'P', 'Ф': 'A', 'Ы': 'S', 'В': 'D', 'А': 'F', //
  'П': 'G', 'Р': 'H', 'О': 'J', 'Л': 'K', 'Д': 'L', 'Я': 'Z', 'Ч': 'X', //
  'С': 'C', 'М': 'V', 'И': 'B', 'Т': 'N', 'Ь': 'M',
};

/// 1. Russian-layout Cyrillic → Latin by key position (either case),
/// 2. uppercase, 3. whitespace and '-' removed — so the partner display form
/// `4821 7730 1956 0342`, a scanner's trailing CR/LF/Tab, "ali-20" and
/// "ФДШ20" all normalise alike.
String normalizePromoCode(String raw) {
  final mapped = StringBuffer();
  for (final rune in raw.runes) {
    final char = String.fromCharCode(rune);
    mapped.write(_ruToLatin[char.toUpperCase()] ?? char);
  }
  return mapped.toString().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
}

/// The kind of an already-normalised code, or null when it has neither
/// shape (→ `PROMO_CODE_INVALID_FORMAT` locally, no request). A digits-only
/// value is a partner code and must pass [isValidPromoCode].
PromoCodeKind? classifyPromoCode(String normalized) {
  if (RegExp(r'^\d+$').hasMatch(normalized)) {
    return isValidPromoCode(normalized) ? PromoCodeKind.partner : null;
  }
  if (RegExp(r'^[A-Z0-9]{3,20}$').hasMatch(normalized) &&
      RegExp(r'[A-Z]').hasMatch(normalized)) {
    return PromoCodeKind.blogger;
  }
  return null;
}

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

/// A partner code: exactly 16 digits whose last is the Luhn digit of the
/// first 15 — checked locally so a mistyped code never costs a request.
/// Expects an already-normalised value.
bool isValidPromoCode(String digits) {
  if (!RegExp(r'^\d{16}$').hasMatch(digits)) return false;
  return luhnCheckDigit(digits.substring(0, promoCodeLength - 1)) ==
      digits.codeUnitAt(promoCodeLength - 1) - 48;
}

/// `4821773019560342` → `4821 7730 1956 0342`.
String formatPromoCode(String digits) =>
    digits.replaceAllMapped(RegExp(r'(\d{4})(?=\d)'), (m) => '${m[1]} ');
