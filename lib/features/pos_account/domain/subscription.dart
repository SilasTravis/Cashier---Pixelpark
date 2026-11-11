import 'package:equatable/equatable.dart';

import '../../pos_sale/domain/sale_receipt.dart';
import 'pos_entry.dart';

/// "Obuna" (child subscription) models — the POS contract of
/// `GET/POST /v1/pos/customers/:id/subscriptions` and `GET /v1/pos/subscriptions`.
///
/// Every parser here is defensive: the subscription feature is additive, so
/// a missing/odd field on an older or half-deployed backend must degrade to
/// "no subscription" rather than break the customer page.

/// Per-entry limit of a subscription: `per_day` (max 1 a day, the default),
/// `per_week` (+ a count) or `none`.
enum SubscriptionLimitKind {
  none,
  perDay,
  perWeek;

  static SubscriptionLimitKind parse(Object? raw) => switch (raw) {
    'none' => SubscriptionLimitKind.none,
    'per_week' => SubscriptionLimitKind.perWeek,
    _ => SubscriptionLimitKind.perDay,
  };
}

/// Why a child's live subscription can't be used right now.
enum SubscriptionBlockedReason {
  notMappedHere,
  usedToday,
  weeklyLimit,
  other;

  static SubscriptionBlockedReason? parse(Object? raw) => switch (raw) {
    null => null,
    'NOT_MAPPED_HERE' => SubscriptionBlockedReason.notMappedHere,
    'USED_TODAY' => SubscriptionBlockedReason.usedToday,
    'WEEKLY_LIMIT' => SubscriptionBlockedReason.weeklyLimit,
    _ => SubscriptionBlockedReason.other,
  };
}

int? _int(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text.trim()),
  _ => null,
};

double? _double(Object? value) => switch (value) {
  num number => number.toDouble(),
  String text => double.tryParse(text.trim()),
  _ => null,
};

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

String _string(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

/// The branch kids plan a subscription entry issues (`kidsPlanHere` /
/// `kidsPlan`): `{ key, name, priceUzs }`.
class SubscriptionKidsPlan extends Equatable {
  const SubscriptionKidsPlan({
    required this.key,
    required this.name,
    this.priceUzs,
  });

  final String key;
  final String name;
  final int? priceUzs;

  static SubscriptionKidsPlan? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    if (key is! String) return null;
    return SubscriptionKidsPlan(
      key: key,
      name: _string(json['name'], key),
      priceUzs: _int(json['priceUzs']),
    );
  }

  @override
  List<Object?> get props => [key, name, priceUzs];
}

/// One LIVE subscription of one of the customer's children.
class CustomerSubscription extends Equatable {
  const CustomerSubscription({
    required this.id,
    required this.childId,
    required this.name,
    required this.level,
    required this.entriesTotal,
    required this.entriesUsed,
    required this.entriesLeft,
    required this.status,
    required this.limitKind,
    required this.usableHere,
    required this.usableToday,
    this.activatedAt,
    this.expiresAt,
    this.limitCount,
    this.blockedReason,
    this.kidsPlanHere,
    this.validityDays,
  });

  final String id;
  final String childId;
  final String name;

  /// `day` (kun bo'yi / VIP-like) or `hour`.
  final String level;
  final int entriesTotal;
  final int entriesUsed;
  final int entriesLeft;

  /// Null until the first entry — the validity period starts there.
  final DateTime? activatedAt;

  /// Exclusive end (Tashkent day start after the last valid day).
  final DateTime? expiresAt;

  /// `not_activated` | `active` (only live ones are listed).
  final String status;
  final SubscriptionLimitKind limitKind;
  final int? limitCount;
  final bool usableHere;
  final bool usableToday;
  final SubscriptionBlockedReason? blockedReason;
  final SubscriptionKidsPlan? kidsPlanHere;

  /// Not in the documented contract — parsed if a backend sends it so the
  /// "Bugun faollashadi → 30 kun" hint can show the number.
  final int? validityDays;

  /// Enters at 0 at this till today.
  bool get usable => usableHere && usableToday;

  bool get isActivated => activatedAt != null;

  /// The last valid day (local) — [expiresAt] is exclusive.
  DateTime? get lastValidDay => expiresAt?.subtract(const Duration(minutes: 1));

  /// Null for an entry the till can't trust (no id/child) — dropped.
  static CustomerSubscription? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final childId = json['childId'];
    if (id is! String || childId is! String) return null;
    final total = _int(json['entriesTotal']) ?? 0;
    final used = _int(json['entriesUsed']) ?? 0;
    return CustomerSubscription(
      id: id,
      childId: childId,
      name: _string(json['name'], 'Obuna'),
      level: _string(json['level'], 'day'),
      entriesTotal: total,
      entriesUsed: used,
      entriesLeft: _int(json['entriesLeft']) ?? (total - used).clamp(0, total),
      activatedAt: _date(json['activatedAt']),
      expiresAt: _date(json['expiresAt']),
      status: _string(json['status'], 'active'),
      limitKind: SubscriptionLimitKind.parse(json['limitKind']),
      limitCount: _int(json['limitCount']),
      usableHere: json['usableHere'] == true,
      usableToday: json['usableToday'] == true,
      blockedReason: SubscriptionBlockedReason.parse(json['blockedReason']),
      kidsPlanHere: SubscriptionKidsPlan.tryFromJson(json['kidsPlanHere']),
      validityDays: _int(json['validityDays']),
    );
  }

  static List<CustomerSubscription> listFromJson(Object? json) => [
    if (json is List)
      for (final item in json) ?tryFromJson(item),
  ];

  @override
  List<Object?> get props => [
    id,
    childId,
    name,
    level,
    entriesTotal,
    entriesUsed,
    entriesLeft,
    activatedAt,
    expiresAt,
    status,
    limitKind,
    limitCount,
    usableHere,
    usableToday,
    blockedReason,
    kidsPlanHere,
    validityDays,
  ];
}

/// A subscription type sellable at this till (`GET /v1/pos/subscriptions`).
class SellableSubscriptionPlan extends Equatable {
  const SellableSubscriptionPlan({
    required this.id,
    required this.name,
    required this.level,
    required this.entriesCount,
    required this.validityDays,
    required this.limitKind,
    required this.priceUzs,
    this.limitCount,
    this.kidsPlan,
    this.perEntryUzs,
    this.savingsPercent,
  });

  final String id;
  final String name;
  final String level;
  final int entriesCount;
  final int validityDays;
  final SubscriptionLimitKind limitKind;
  final int? limitCount;

  /// Effective price at this branch.
  final int priceUzs;
  final SubscriptionKidsPlan? kidsPlan;
  final int? perEntryUzs;
  final double? savingsPercent;

  static SellableSubscriptionPlan? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final price = _int(json['priceUzs']);
    if (id is! String || price == null || price <= 0) return null;
    final entries = _int(json['entriesCount']) ?? 1;
    return SellableSubscriptionPlan(
      id: id,
      name: _string(json['name'], 'Obuna'),
      level: _string(json['level'], 'day'),
      entriesCount: entries,
      validityDays: _int(json['validityDays']) ?? 0,
      limitKind: SubscriptionLimitKind.parse(json['limitKind']),
      limitCount: _int(json['limitCount']),
      priceUzs: price,
      kidsPlan: SubscriptionKidsPlan.tryFromJson(json['kidsPlan']),
      perEntryUzs:
          _int(json['perEntryUzs']) ?? (entries > 0 ? price ~/ entries : null),
      savingsPercent: _double(json['savingsPercent']),
    );
  }

  static List<SellableSubscriptionPlan> listFromJson(Object? json) => [
    if (json is List)
      for (final item in json) ?tryFromJson(item),
  ];

  @override
  List<Object?> get props => [
    id,
    name,
    level,
    entriesCount,
    validityDays,
    limitKind,
    limitCount,
    priceUzs,
    kidsPlan,
    perEntryUzs,
    savingsPercent,
  ];
}

/// The subscription a gate pass was issued from (`passes[].subscription`).
class PassSubscription extends Equatable {
  const PassSubscription({
    required this.id,
    required this.name,
    required this.entriesTotal,
    required this.entriesLeft,
    this.expiresAt,
  });

  final String id;
  final String name;
  final int entriesTotal;
  final int entriesLeft;
  final DateTime? expiresAt;

  static PassSubscription? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String) return null;
    return PassSubscription(
      id: id,
      name: _string(json['name'], 'Obuna'),
      entriesTotal: _int(json['entriesTotal']) ?? 0,
      entriesLeft: _int(json['entriesLeft']) ?? 0,
      expiresAt: _date(json['expiresAt']),
    );
  }

  @override
  List<Object?> get props => [id, name, entriesTotal, entriesLeft, expiresAt];
}

/// The money side of a subscription sale (`receipt` of the sell response).
class SubscriptionSaleReceipt extends Equatable {
  const SubscriptionSaleReceipt({
    required this.createdAt,
    required this.priceUzs,
    required this.balanceUzs,
    required this.cashUzs,
    required this.cardUzs,
    this.saleId,
  });

  /// The ACCOUNT_TOPUP sale of the collected cash/card — null when the
  /// balance paid it all.
  final String? saleId;
  final DateTime createdAt;
  final int priceUzs;

  /// The part paid from the customer's balance.
  final int balanceUzs;
  final int cashUzs;
  final int cardUzs;

  factory SubscriptionSaleReceipt.fromJson(
    Object? json, {
    required int fallbackPriceUzs,
  }) {
    final map = json is Map ? json : const {};
    return SubscriptionSaleReceipt(
      saleId: map['saleId'] is String ? map['saleId'] as String : null,
      createdAt: _date(map['createdAt']) ?? DateTime.now(),
      priceUzs: _int(map['priceUzs']) ?? fallbackPriceUzs,
      balanceUzs: _int(map['balanceUzs']) ?? 0,
      cashUzs: _int(map['cashUzs']) ?? 0,
      cardUzs: _int(map['cardUzs']) ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    saleId,
    createdAt,
    priceUzs,
    balanceUzs,
    cashUzs,
    cardUzs,
  ];
}

/// `POST /v1/pos/customers/:id/subscriptions` answer.
class SubscriptionSaleResult extends Equatable {
  const SubscriptionSaleResult({
    required this.subscription,
    required this.receipt,
    this.pass,
    this.passFailureCode,
    this.passFailureMessage,
    this.balance,
    this.cashback,
  });

  final CustomerSubscription subscription;

  /// Today's sticker when "Bugun kirsin" was on and the entry worked.
  final PosEntry? pass;

  /// The sale stands even when today's entry failed — this says why.
  final String? passFailureCode;
  final String? passFailureMessage;

  /// The customer's balance after the sale.
  final int? balance;
  final SubscriptionSaleReceipt receipt;
  final SaleCashback? cashback;

  factory SubscriptionSaleResult.fromJson(Map<String, dynamic> json) {
    final subscription = CustomerSubscription.tryFromJson(json['subscription']);
    if (subscription == null) {
      throw const FormatException('subscription missing in sale response');
    }
    final failure = json['passFailure'];
    return SubscriptionSaleResult(
      subscription: subscription,
      pass: json['pass'] is Map
          ? PosEntry.fromJson(Map<String, dynamic>.from(json['pass'] as Map))
          : null,
      passFailureCode: failure is Map ? failure['code']?.toString() : null,
      passFailureMessage: failure is Map
          ? failure['message']?.toString()
          : null,
      balance: _int(json['balance']),
      receipt: SubscriptionSaleReceipt.fromJson(
        json['receipt'],
        fallbackPriceUzs: 0,
      ),
      cashback: SaleCashback.tryFromJson(json['cashback']),
    );
  }

  @override
  List<Object?> get props => [
    subscription,
    pass,
    passFailureCode,
    passFailureMessage,
    balance,
    receipt,
    cashback,
  ];
}

/// Everything the 80 mm subscription receipt prints — assembled by the till
/// from the sale result plus what the modal knew (child name, plan terms).
class SubscriptionReceipt extends Equatable {
  const SubscriptionReceipt({
    required this.id,
    required this.createdAt,
    required this.planName,
    required this.priceUzs,
    required this.childName,
    required this.entriesTotal,
    required this.entriesLeft,
    required this.limitKind,
    this.limitCount,
    this.usedToday = false,
    this.activatedAt,
    this.expiresAt,
    this.validityDays,
    this.balanceUzs = 0,
    this.cashUzs = 0,
    this.cardUzs = 0,
    this.cashback,
  });

  factory SubscriptionReceipt.fromSale(
    SubscriptionSaleResult sale, {
    required String childName,
    SellableSubscriptionPlan? plan,
  }) {
    final subscription = sale.subscription;
    final receipt = sale.receipt;
    return SubscriptionReceipt(
      id: receipt.saleId ?? subscription.id,
      createdAt: receipt.createdAt,
      planName: subscription.name,
      priceUzs: receipt.priceUzs > 0
          ? receipt.priceUzs
          : plan?.priceUzs ??
                receipt.balanceUzs + receipt.cashUzs + receipt.cardUzs,
      childName: childName,
      entriesTotal: subscription.entriesTotal,
      entriesLeft: subscription.entriesLeft,
      limitKind: subscription.limitKind,
      limitCount: subscription.limitCount,
      usedToday: sale.pass != null,
      activatedAt: subscription.activatedAt,
      expiresAt: subscription.expiresAt,
      validityDays: subscription.validityDays ?? plan?.validityDays,
      balanceUzs: receipt.balanceUzs,
      cashUzs: receipt.cashUzs,
      cardUzs: receipt.cardUzs,
      cashback: sale.cashback,
    );
  }

  final String id;
  final DateTime createdAt;
  final String planName;
  final int priceUzs;
  final String childName;
  final int entriesTotal;
  final int entriesLeft;
  final SubscriptionLimitKind limitKind;
  final int? limitCount;

  /// Today's entry was taken with the sale ("5 ta (bugun 1)").
  final bool usedToday;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final int? validityDays;
  final int balanceUzs;
  final int cashUzs;
  final int cardUzs;
  final SaleCashback? cashback;

  @override
  List<Object?> get props => [
    id,
    createdAt,
    planName,
    priceUzs,
    childName,
    entriesTotal,
    entriesLeft,
    limitKind,
    limitCount,
    usedToday,
    activatedAt,
    expiresAt,
    validityDays,
    balanceUzs,
    cashUzs,
    cardUzs,
    cashback,
  ];
}
