import 'package:equatable/equatable.dart';

enum BirthdayPartyStatus { booked, completed, cancelled }

enum BirthdayPaymentState { unpaid, partial, paid }

enum BirthdayPaymentKind { payment, refund }

/// How a payment/deposit is split across sources, in so'm.
typedef BirthdayMoney = ({int fromBalanceUzs, int cashUzs, int cardUzs});

DateTime? _date(Object? raw) =>
    raw == null ? null : DateTime.parse(raw as String);

String? _username(Object? raw) =>
    raw == null ? null : (raw as Map)['username'] as String;

class BirthdayPartyPayment extends Equatable {
  const BirthdayPartyPayment({
    required this.id,
    required this.kind,
    required this.amountUzs,
    required this.fromBalanceUzs,
    required this.cashUzs,
    required this.cardUzs,
    required this.refundTo,
    required this.cashierUsername,
    required this.createdAt,
  });

  final String id;
  final BirthdayPaymentKind kind;
  final int amountUzs;
  final int fromBalanceUzs;
  final int cashUzs;
  final int cardUzs;

  /// `balance` | `cash` for refunds, null for payments.
  final String? refundTo;
  final String? cashierUsername;
  final DateTime createdAt;

  factory BirthdayPartyPayment.fromJson(Map<String, dynamic> json) =>
      BirthdayPartyPayment(
        id: json['id'] as String,
        kind: json['kind'] == 'refund'
            ? BirthdayPaymentKind.refund
            : BirthdayPaymentKind.payment,
        amountUzs: json['amountUzs'] as int,
        fromBalanceUzs: json['fromBalanceUzs'] as int,
        cashUzs: json['cashUzs'] as int,
        cardUzs: json['cardUzs'] as int,
        refundTo: json['refundTo'] as String?,
        cashierUsername: _username(json['cashier']),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props => [
    id,
    kind,
    amountUzs,
    fromBalanceUzs,
    cashUzs,
    cardUzs,
    refundTo,
    cashierUsername,
    createdAt,
  ];
}

class BirthdayPartyComment extends Equatable {
  const BirthdayPartyComment({
    required this.id,
    required this.text,
    required this.author,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String author;
  final DateTime createdAt;

  factory BirthdayPartyComment.fromJson(Map<String, dynamic> json) =>
      BirthdayPartyComment(
        id: json['id'] as String,
        text: json['text'] as String,
        author: json['author'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  @override
  List<Object?> get props => [id, text, author, createdAt];
}

class BirthdayParty extends Equatable {
  const BirthdayParty({
    required this.id,
    required this.status,
    required this.paymentState,
    required this.branchId,
    required this.branchName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.planId,
    required this.planName,
    required this.planColor,
    required this.includedItems,
    required this.childCount,
    required this.extraChildren,
    required this.packagePriceUzs,
    required this.extraChildUzs,
    required this.listPriceUzs,
    required this.agreedPriceUzs,
    required this.discountUzs,
    required this.paidUzs,
    required this.refundedUzs,
    required this.debtUzs,
    required this.keptUzs,
    required this.maxCashRefundUzs,
    required this.partyDate,
    required this.soldByUsername,
    required this.createdAt,
    required this.completedAt,
    required this.cancelledAt,
    required this.cancelReason,
    required this.payments,
    required this.comments,
  });

  final String id;
  final BirthdayPartyStatus status;
  final BirthdayPaymentState paymentState;
  final String branchId;
  final String branchName;
  final int customerId;
  final String customerName;
  final String customerPhone;
  final String planId;
  final String planName;
  final String planColor;
  final List<String> includedItems;
  final int childCount;
  final int extraChildren;
  final int packagePriceUzs;
  final int extraChildUzs;
  final int listPriceUzs;
  final int agreedPriceUzs;
  final int discountUzs;
  final int paidUzs;
  final int refundedUzs;
  final int debtUzs;
  final int keptUzs;
  final int maxCashRefundUzs;

  /// `YYYY-MM-DD`, Tashkent calendar day.
  final String partyDate;
  final String? soldByUsername;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final List<BirthdayPartyPayment> payments;
  final List<BirthdayPartyComment> comments;

  factory BirthdayParty.fromJson(Map<String, dynamic> json) {
    final customer = Map<String, dynamic>.from(json['customer'] as Map);
    final plan = Map<String, dynamic>.from(json['plan'] as Map);
    return BirthdayParty(
      id: json['id'] as String,
      status: BirthdayPartyStatus.values.byName(json['status'] as String),
      paymentState: BirthdayPaymentState.values.byName(
        json['paymentState'] as String,
      ),
      branchId: json['branchId'] as String,
      branchName: json['branchName'] as String,
      customerId: customer['id'] as int,
      customerName: customer['fullName'] as String,
      customerPhone: customer['phoneNumber'] as String,
      planId: plan['id'] as String,
      planName: plan['name'] as String,
      planColor: plan['color'] as String,
      includedItems: (plan['includedItems'] as List).cast<String>(),
      childCount: json['childCount'] as int,
      extraChildren: json['extraChildren'] as int,
      packagePriceUzs: json['packagePriceUzs'] as int,
      extraChildUzs: json['extraChildUzs'] as int,
      listPriceUzs: json['listPriceUzs'] as int,
      agreedPriceUzs: json['agreedPriceUzs'] as int,
      discountUzs: json['discountUzs'] as int,
      paidUzs: json['paidUzs'] as int,
      refundedUzs: json['refundedUzs'] as int,
      debtUzs: json['debtUzs'] as int,
      keptUzs: json['keptUzs'] as int,
      maxCashRefundUzs: json['maxCashRefundUzs'] as int,
      partyDate: json['partyDate'] as String,
      soldByUsername: _username(json['soldBy']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: _date(json['completedAt']),
      cancelledAt: _date(json['cancelledAt']),
      cancelReason: json['cancelReason'] as String?,
      payments: (json['payments'] as List)
          .map(
            (e) => BirthdayPartyPayment.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      comments: (json['comments'] as List)
          .map(
            (e) => BirthdayPartyComment.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    status,
    paymentState,
    branchId,
    branchName,
    customerId,
    customerName,
    customerPhone,
    planId,
    planName,
    planColor,
    includedItems,
    childCount,
    extraChildren,
    packagePriceUzs,
    extraChildUzs,
    listPriceUzs,
    agreedPriceUzs,
    discountUzs,
    paidUzs,
    refundedUzs,
    debtUzs,
    keptUzs,
    maxCashRefundUzs,
    partyDate,
    soldByUsername,
    createdAt,
    completedAt,
    cancelledAt,
    cancelReason,
    payments,
    comments,
  ];
}
