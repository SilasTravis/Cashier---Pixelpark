import 'package:equatable/equatable.dart';

/// One balance-ledger row of a customer — a top-up, a tariff or goods debit,
/// a refund, a bonus … as `GET /v1/pos/customers/:id/transactions` returns it.
class CustomerTransaction extends Equatable {
  const CustomerTransaction({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.type,
    required this.status,
    required this.amountUzs,
    this.note,
    this.cashierName,
  });

  final int id;
  final DateTime createdAt;

  /// `top_up` / `credit` add to the balance, `debit` takes from it.
  final String kind;

  /// The backend's `transactionType` (`CASHIER_TOPUP`, `POS_PURCHASE` …).
  final String type;
  final String status;

  /// Always positive — [isDebit] says which way it moved.
  final int amountUzs;
  final String? note;
  final String? cashierName;

  bool get isDebit => kind == 'debit';

  /// A row that did not (yet) move money: pending, failed or cancelled.
  bool get isSettled => status == 'paid';

  @override
  List<Object?> get props => [
    id,
    createdAt,
    kind,
    type,
    status,
    amountUzs,
    note,
    cashierName,
  ];
}

/// A page of a customer's ledger plus how many rows exist in total.
class CustomerTransactionsPage extends Equatable {
  const CustomerTransactionsPage({required this.items, required this.total});

  final List<CustomerTransaction> items;
  final int total;

  @override
  List<Object?> get props => [items, total];
}
