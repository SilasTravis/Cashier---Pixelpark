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

/// `POST /v1/pos/promo-codes/verify` — what a scanned partner code is
/// worth. Nothing is used yet: the single-use redemption happens inside the
/// plan-entry checkout (`promoCode`).
class PromoCodeCheck extends Equatable {
  const PromoCodeCheck({
    required this.code,
    required this.partnerName,
    required this.tierName,
    required this.discount,
    required this.expiresAt,
    this.owner,
  });

  /// The normalised 16 digits the checkout sends back.
  final String code;
  final String partnerName;
  final String tierName;

  /// The tier's entry discount — same preview math as a catalog discount
  /// (`Discount.appliedDiscountUzs`); the server stays the authority.
  final Discount discount;
  final DateTime expiresAt;
  final PromoCodeOwner? owner;

  factory PromoCodeCheck.fromJson(String code, Map<String, dynamic> json) {
    final partner = json['partner'] as Map<String, dynamic>;
    final tier = json['tier'] as Map<String, dynamic>;
    final owner = json['customer'] as Map<String, dynamic>?;
    return PromoCodeCheck(
      code: code,
      partnerName: partner['name'] as String,
      tierName: tier['name'] as String,
      discount: Discount.fromJson({
        ...json['discount'] as Map<String, dynamic>,
        'scope': 'entry',
      }),
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
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
  });

  final bool applied;
  final String childId;
  final String? reasonCode;

  factory PromoCodeOutcome.fromJson(Map<String, dynamic> json) =>
      PromoCodeOutcome(
        applied: json['status'] == 'applied',
        childId: json['childId'] as String,
        reasonCode: json['reasonCode'] as String?,
      );

  @override
  List<Object?> get props => [applied, childId, reasonCode];
}
