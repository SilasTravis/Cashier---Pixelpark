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
    List<BirthdayPartyPayment> refunds = const [],
    bool withItems = false,
  }) {
    final children = p.extraChildren > 0
        ? '${p.childCount} + ${p.extraChildren}'
        : '${p.childCount}';
    // A cancel's new refund rows (one per destination) make this a refund
    // receipt; so does a single refund row passed as [payment].
    final refundRows = refunds.isNotEmpty
        ? refunds
        : [if (payment?.kind == BirthdayPaymentKind.refund) payment!];
    final isRefund = refundRows.isNotEmpty;
    final shown = isRefund ? null : payment;
    return BirthdayReceipt(
      title: isRefund ? "Tug'ilgan kun - qaytarish" : "Tug'ilgan kun",
      createdAt: isRefund
          ? refundRows
                .map((r) => r.createdAt)
                .reduce((a, b) => b.isAfter(a) ? b : a)
          : payment?.createdAt ?? p.createdAt,
      details: [
        ('Ota-ona', p.customerName),
        ('Filial', p.branchName),
        ('Tarif', p.planName),
        ('Bolalar', children),
        ('Bayram kuni', _dmy(p.partyDate)),
        ('Narx', groupDigits(p.agreedPriceUzs)),
        if (p.discountUzs > 0) ('Chegirma', groupDigits(p.discountUzs)),
        if (isRefund)
          for (final r in refundRows)
            (_refundLabel(r), groupDigits(r.amountUzs))
        else if (shown != null) ...[
          if (shown.fromBalanceUzs > 0)
            ('Balansdan', groupDigits(shown.fromBalanceUzs)),
          if (shown.cashUzs > 0) ('Naqd', groupDigits(shown.cashUzs)),
          if (shown.cardUzs > 0) ('Karta', groupDigits(shown.cardUzs)),
        ],
        if (p.refundedUzs > 0 && !isRefund)
          ('Qaytarilgan', groupDigits(p.refundedUzs)),
      ],
      summary: [
        // Net of refunds, so paid + left always adds up to the price.
        ("Jami to'langan", groupDigits(p.paidUzs - p.refundedUzs)),
        ('Qoldi', groupDigits(p.debtUzs)),
      ],
      items: withItems ? List.of(p.includedItems) : const [],
    );
  }

  /// Where one refund row went: `Balansga` / `Naqd`.
  static String _refundLabel(BirthdayPartyPayment r) =>
      r.refundTo == 'balance' ? 'Balansga' : 'Naqd';

  static String _dmy(String ymd) => partyDateLabel(ymd);
}
