import '../../features/birthday_parties/domain/birthday_party.dart';
import '../utils/currency.dart';

/// What the 80mm birthday receipt prints, as plain label/value rows so the
/// layout code stays dumb and the content is testable without a PDF.
class BirthdayReceipt {
  const BirthdayReceipt({
    required this.title,
    required this.details,
    required this.summary,
    required this.items,
    required this.createdAt,
  });

  final String title;

  /// Everything above the totals block.
  final List<(String, String)> details;

  /// The totals block: paid so far and what is left.
  final List<(String, String)> summary;

  List<(String, String)> get rows => [...details, ...summary];

  /// Included items; empty unless the sale receipt asked for them.
  final List<String> items;
  final DateTime createdAt;

  factory BirthdayReceipt.fromParty(
    BirthdayParty p, {
    BirthdayPartyPayment? payment,
    bool withItems = false,
  }) {
    final children = p.extraChildren > 0
        ? '${p.childCount} + ${p.extraChildren}'
        : '${p.childCount}';
    final isRefund = payment?.kind == BirthdayPaymentKind.refund;
    return BirthdayReceipt(
      title: "Tug'ilgan kun",
      createdAt: payment?.createdAt ?? p.createdAt,
      details: [
        ('Ota-ona', p.customerName),
        ('Filial', p.branchName),
        ('Tarif', p.planName),
        ('Bolalar', children),
        ('Bayram kuni', _dmy(p.partyDate)),
        ('Narx', groupDigits(p.agreedPriceUzs)),
        if (p.discountUzs > 0) ('Chegirma', groupDigits(p.discountUzs)),
        if (payment != null && isRefund)
          ('Qaytarildi', groupDigits(payment.amountUzs))
        else if (payment != null) ...[
          if (payment.fromBalanceUzs > 0)
            ('Balansdan', groupDigits(payment.fromBalanceUzs)),
          if (payment.cashUzs > 0) ('Naqd', groupDigits(payment.cashUzs)),
          if (payment.cardUzs > 0) ('Karta', groupDigits(payment.cardUzs)),
        ],
        if (p.refundedUzs > 0) ('Qaytarilgan', groupDigits(p.refundedUzs)),
      ],
      summary: [
        // Net of refunds, so paid + left always adds up to the price.
        ("Jami to'langan", groupDigits(p.paidUzs - p.refundedUzs)),
        ('Qoldi', groupDigits(p.debtUzs)),
      ],
      items: withItems ? List.of(p.includedItems) : const [],
    );
  }

  /// `2026-11-06` -> `06.11.2026`; anything unexpected is printed as is.
  static String _dmy(String ymd) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(ymd);
    return m == null ? ymd : '${m[3]}.${m[2]}.${m[1]}';
  }
}
