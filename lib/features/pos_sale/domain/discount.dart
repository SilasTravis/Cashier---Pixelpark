import 'package:equatable/equatable.dart';

/// How a [Discount]'s `value` is interpreted — mirrors the backend's
/// `discount.entity.ts`. `percent`: 1..100. `fixed`: a whole UZS amount, >= 1.
enum DiscountKind { percent, fixed }

/// Which flow a [Discount] row is usable in — mirrors the backend's
/// `DiscountScope`. `goods`: the POS cart / plan-entry goods leg (the
/// existing [DiscountPicker]). `entry`: a child's plan-entry gate pass (the
/// per-child 3-dots menu in `customer_detail_panel.dart`) — replaces the old
/// hardcoded `FreeReason` picker.
enum DiscountScope {
  goods,
  entry;

  /// Wire value sent as the `?scope=` query param.
  String get key => name;

  static DiscountScope fromKey(String? key) =>
      key == 'entry' ? DiscountScope.entry : DiscountScope.goods;
}

/// One admin-managed catalog row ("Flayer 30%", "Tug'ilgan kun 20 000 so'm")
/// — global, not branch-scoped. The cashier picks at most one per receipt;
/// the catalog only ever contains `active: true` rows (see
/// `GET /v1/pos/discounts`), so `active` is always true for anything this
/// app fetches, but is kept on the model for parity with the wire shape.
class Discount extends Equatable {
  const Discount({
    required this.id,
    required this.name,
    required this.kind,
    required this.value,
    this.scope = DiscountScope.goods,
    this.active = true,
  });

  final String id;
  final String name;
  final DiscountKind kind;
  final int value;
  final DiscountScope scope;
  final bool active;

  factory Discount.fromJson(Map<String, dynamic> json) => Discount(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: json['kind'] == 'fixed' ? DiscountKind.fixed : DiscountKind.percent,
    value: json['value'] as int,
    scope: DiscountScope.fromKey(json['scope'] as String?),
    active: json['active'] as bool? ?? true,
  );

  /// Replicates the backend's `applyDiscount()` formula — `percent`:
  /// `round(gross * value / 100)`; `fixed`: `min(value, gross)`; always
  /// clamped to `0 <= discountUzs <= grossUzs`.
  ///
  /// PREVIEW ONLY: this exists so the cart screen can show "how much this
  /// will save" before the API call returns. The actual charged amount is
  /// always decided server-side — the printed receipt, the history screen
  /// and the shift totals must read `grossUzs`/`discountUzs`/`subtotalUzs`
  /// off the server's response, never re-derive them from this function.
  int appliedDiscountUzs(int grossUzs) {
    if (grossUzs <= 0) return 0;
    final raw = switch (kind) {
      DiscountKind.percent => (grossUzs * value + 50) ~/ 100,
      DiscountKind.fixed => value,
    };
    return raw.clamp(0, grossUzs);
  }

  @override
  List<Object?> get props => [id, name, kind, value, scope, active];
}

/// The discount actually applied to a sale, as snapshotted and echoed back
/// by the server on the receipt/history/shift responses — `id` is nullable
/// per the wire contract ("kept nullable for forward compat"; a deleted
/// catalog row cannot happen today since deletion is FK-restricted, but the
/// shape allows for it).
class DiscountSnapshot extends Equatable {
  const DiscountSnapshot({
    required this.id,
    required this.name,
    required this.kind,
    required this.value,
  });

  final String? id;
  final String name;
  final DiscountKind kind;
  final int value;

  factory DiscountSnapshot.fromJson(Map<String, dynamic> json) =>
      DiscountSnapshot(
        id: json['id'] as String?,
        name: json['name'] as String,
        kind: json['kind'] == 'fixed'
            ? DiscountKind.fixed
            : DiscountKind.percent,
        value: json['value'] as int,
      );

  @override
  List<Object?> get props => [id, name, kind, value];
}
