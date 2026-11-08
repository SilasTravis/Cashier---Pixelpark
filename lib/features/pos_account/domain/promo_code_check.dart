import 'package:equatable/equatable.dart';

import '../../pos_sale/domain/discount.dart';

/// The customer a partner promo code belongs to — only their children can
/// use it, so the terminal opens this account when the code is scanned.
class PromoCodeOwner extends Equatable {
  const PromoCodeOwner({
    required this.id,
    required this.phoneNumber,
    this.firstName,
    this.lastName,
  });

  final int id;
  final String phoneNumber;
  final String? firstName;
  final String? lastName;

  @override
  List<Object?> get props => [id, phoneNumber, firstName, lastName];
}

/// Which kind of promo code the server matched — a partner's single-use,
/// phone-bound 16 digits, or a blogger's static reusable code (`ALI20`).
enum PromoCodeSource {
  partner,
  blogger;

  /// Unknown/missing values read as `partner` — the only kind an older
  /// backend knows.
  static PromoCodeSource parse(Object? raw) =>
      raw == 'blogger' ? PromoCodeSource.blogger : PromoCodeSource.partner;
}

/// A code picked from the customer's "Faol promokodlar" list has no text the
/// app could send (the server keeps only a hash), so it travels through the
/// same `String code` plumbing as a reference: `id:<codeId>`. No typed or
/// scanned code can contain ':' (the normaliser keeps letters and digits), so
/// the two never collide. The data layer turns a reference into `codeId`.
const promoCodeRefPrefix = 'id:';

String promoCodeRefOf(String codeId) => '$promoCodeRefPrefix$codeId';

/// The code id inside a reference, or null for an ordinary typed/scanned code.
String? promoCodeIdOf(String code) => code.startsWith(promoCodeRefPrefix)
    ? code.substring(promoCodeRefPrefix.length)
    : null;

/// One redeemable code of the open customer — a row of the "Faol
/// promokodlar" list. Only the tail of the code is known: the cashier matches
/// it against the code in the customer's SMS.
class CustomerPromoCode extends Equatable {
  const CustomerPromoCode({
    required this.codeId,
    required this.partnerName,
    required this.tierName,
    required this.discount,
    required this.expiresAt,
    required this.codeLast4,
  });

  final String codeId;
  final String partnerName;
  final String tierName;
  final Discount discount;
  final DateTime expiresAt;
  final String codeLast4;

  factory CustomerPromoCode.fromJson(Map<String, dynamic> json) =>
      CustomerPromoCode(
        codeId: json['codeId'] as String,
        partnerName:
            (json['partner'] as Map<String, dynamic>)['name'] as String,
        tierName: (json['tier'] as Map<String, dynamic>)['name'] as String,
        discount: Discount.fromJson({
          ...json['discount'] as Map<String, dynamic>,
          'scope': 'entry',
        }),
        expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
        codeLast4: json['codeLast4'] as String,
      );

  @override
  List<Object?> get props => [
    codeId,
    partnerName,
    tierName,
    discount,
    expiresAt,
    codeLast4,
  ];
}

/// `POST /v1/pos/promo-codes/verify` — what a scanned/typed promo code is
/// worth. Nothing is used yet: the redemption happens inside the
/// plan-entry checkout (`promoCode`).
class PromoCodeCheck extends Equatable {
  const PromoCodeCheck({
    this.source = PromoCodeSource.partner,
    required this.code,
    required this.partnerName,
    required this.tierName,
    required this.discount,
    required this.expiresAt,
    this.owner,
  });

  final PromoCodeSource source;

  /// The server-normalised code the checkout sends back — 16 digits, or a
  /// blogger code like `ALI20`.
  final String code;
  final String partnerName;
  final String tierName;

  /// The tier's entry discount — same preview math as a catalog discount
  /// (`Discount.appliedDiscountUzs`); the server stays the authority.
  final Discount discount;

  /// Partner: the code's TTL. Blogger: the promo's `validUntil`, or null
  /// when it never expires.
  final DateTime? expiresAt;

  /// Partner codes only — a blogger code has no owner; it goes to whichever
  /// customer the cashier opens.
  final PromoCodeOwner? owner;

  bool get isBlogger => source == PromoCodeSource.blogger;

  factory PromoCodeCheck.fromJson(String code, Map<String, dynamic> json) {
    final partner = json['partner'] as Map<String, dynamic>;
    final tier = json['tier'] as Map<String, dynamic>;
    final owner = json['customer'] as Map<String, dynamic>?;
    final expiresAt = json['expiresAt'] as String?;
    final serverCode = json['code'] as String?;
    return PromoCodeCheck(
      source: PromoCodeSource.parse(json['source']),
      // Empty for a code looked up by id (no plaintext exists): keep the
      // reference we asked with — it is what the checkout sends back.
      code: serverCode == null || serverCode.isEmpty ? code : serverCode,
      partnerName: partner['name'] as String,
      tierName: tier['name'] as String,
      discount: Discount.fromJson({
        ...json['discount'] as Map<String, dynamic>,
        'scope': 'entry',
      }),
      expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt).toLocal(),
      owner: owner == null
          ? null
          : PromoCodeOwner(
              id: owner['id'] as int,
              phoneNumber: owner['phoneNumber'] as String,
              firstName: owner['firstName'] as String?,
              lastName: owner['lastName'] as String?,
            ),
    );
  }

  @override
  List<Object?> get props => [
    source,
    code,
    partnerName,
    tierName,
    discount,
    expiresAt,
    owner,
  ];
}

/// What the checkout did with the promo code. `released` = no pass carries
/// it (see [reasonCode]) — the code is usable again.
class PromoCodeOutcome extends Equatable {
  const PromoCodeOutcome({
    required this.applied,
    required this.childId,
    this.reasonCode,
    this.source = PromoCodeSource.partner,
  });

  final bool applied;
  final String childId;
  final String? reasonCode;
  final PromoCodeSource source;

  factory PromoCodeOutcome.fromJson(Map<String, dynamic> json) =>
      PromoCodeOutcome(
        applied: json['status'] == 'applied',
        source: PromoCodeSource.parse(json['source']),
        childId: json['childId'] as String,
        reasonCode: json['reasonCode'] as String?,
      );

  @override
  List<Object?> get props => [applied, childId, reasonCode, source];
}
