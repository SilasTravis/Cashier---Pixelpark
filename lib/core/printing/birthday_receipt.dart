import '../../features/birthday_parties/domain/birthday_party.dart';

/// One item line of a birthday receipt — printed like a product line:
/// name, then `qty x price` and the line total.
class BirthdayReceiptLine {
  const BirthdayReceiptLine(this.name, this.qty, this.unitUzs);

  final String name;
  final int qty;
  final int unitUzs;

  int get totalUzs => qty * unitUzs;

  @override
  bool operator ==(Object other) =>
      other is BirthdayReceiptLine &&
      other.name == name &&
      other.qty == qty &&
      other.unitUzs == unitUzs;

  @override
  int get hashCode => Object.hash(name, qty, unitUzs);

  @override
  String toString() => '$name $qty x $unitUzs';
}

/// What the 80mm birthday receipt prints, laid out like a product sale
/// receipt (items, discount, JAMI, this payment's split) plus the party's
/// paid / left and its date. Never a cashback block. Plain data, so the
/// content is testable without a PDF.
class BirthdayReceipt {
  const BirthdayReceipt({
    required this.receiptId,
    required this.createdAt,
    required this.lines,
    required this.discountUzs,
    required this.totalUzs,
    required this.paymentRows,
    required this.refundedUzs,
    required this.paidUzs,
    required this.debtUzs,
    required this.partyDate,
    required this.parent,
    required this.items,
    this.title,
  });

  /// Only refund receipts carry a title ("Tug'ilgan kun - qaytarish").
  final String? title;
  final String receiptId;
  final DateTime createdAt;
  final List<BirthdayReceiptLine> lines;

  /// List price − agreed price; negative = the cashier charged more.
  final int discountUzs;

  /// The agreed price of the party (JAMI).
  final int totalUzs;

  /// This payment's split (`Naqd` / `Karta` / `Balans`), or a refund's
  /// destinations (`Qaytarildi: balansga` / `Qaytarildi: naqd`).
  final List<(String, int)> paymentRows;

  /// Everything refunded on the party so far (0 hides the row).
  final int refundedUzs;

  /// Paid so far, net of refunds — paid + left always adds up to the price.
  final int paidUzs;
  final int debtUzs;

  /// `dd.MM.yyyy`.
  final String partyDate;
  final String parent;

  /// Included items; empty unless the sale receipt asked for them.
  final List<String> items;

  bool get isRefund => title != null;

  factory BirthdayReceipt.fromParty(
    BirthdayParty p, {
    BirthdayPartyPayment? payment,
    List<BirthdayPartyPayment> refunds = const [],
    bool withItems = false,
  }) {
    // A cancel's new refund rows (one per destination) make this a refund
    // receipt; so does a single refund row passed as [payment].
    final refundRows = refunds.isNotEmpty
        ? refunds
        : [if (payment?.kind == BirthdayPaymentKind.refund) payment!];
    final isRefund = refundRows.isNotEmpty;
    final shown = isRefund ? null : payment;
    return BirthdayReceipt(
      title: isRefund ? "Tug'ilgan kun - qaytarish" : null,
      receiptId: (isRefund ? refundRows.last.id : shown?.id) ?? p.id,
      createdAt: isRefund
          ? refundRows
                .map((r) => r.createdAt)
                .reduce((a, b) => b.isAfter(a) ? b : a)
          : shown?.createdAt ?? p.createdAt,
      lines: [
        BirthdayReceiptLine(
          '${p.planName} · ${p.childCount} bola',
          1,
          p.packagePriceUzs,
        ),
        if (p.extraChildren > 0)
          BirthdayReceiptLine(
            "Qo'shimcha bola",
            p.extraChildren,
            p.extraChildUzs,
          ),
      ],
      discountUzs: p.discountUzs,
      totalUzs: p.agreedPriceUzs,
      paymentRows: [
        if (isRefund)
          for (final r in refundRows) (_refundLabel(r), r.amountUzs)
        else if (shown != null) ...[
          if (shown.cashUzs > 0) ('Naqd', shown.cashUzs),
          if (shown.cardUzs > 0) ('Karta', shown.cardUzs),
          if (shown.fromBalanceUzs > 0) ('Balans', shown.fromBalanceUzs),
        ],
      ],
      refundedUzs: p.refundedUzs,
      paidUzs: p.paidUzs - p.refundedUzs,
      debtUzs: p.debtUzs,
      partyDate: partyDateLabel(p.partyDate),
      parent: p.customerLabel,
      items: withItems ? List.of(p.includedItems) : const [],
    );
  }

  /// Where one refund row went.
  static String _refundLabel(BirthdayPartyPayment r) =>
      r.refundTo == 'balance' ? 'Qaytarildi: balansga' : 'Qaytarildi: naqd';
}
