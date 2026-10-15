import 'package:equatable/equatable.dart';

class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    required this.priceUzs,
    required this.category,
    required this.icon,
    this.offlineOnly = false,
    this.imageUrl,
    this.showInExtras = false,
  });

  final String id;
  final String name;
  final int priceUzs;
  final String category;

  /// Phosphor icon class name from the design system (e.g. `ph-ticket`).
  /// Also the fallback when there is no photo, or it can't be loaded.
  final String icon;

  /// Only sold in offline mode — e.g. the VIP / hourly plans, which online
  /// mint a QR and so can't be issued without the server. Hidden from the
  /// grid online; the backend also refuses them at online checkout.
  final bool offlineOnly;

  /// The product photo uploaded in the Dashboard, or null. A backend that
  /// predates photos — or an offline cache saved before them — has no key.
  final String? imageUrl;

  /// Also offered in the account page's "Qo'shimcha" step (e.g. a nanny
  /// service), sold there from the customer's balance with a receipt. Still
  /// in the Savdo grid too. Absent on older backends / caches → false.
  final bool showInExtras;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    priceUzs: json['priceUzs'] as int,
    category: json['category'] as String,
    icon: json['icon'] as String,
    offlineOnly: json['offlineOnly'] as bool? ?? false,
    imageUrl: _readImageUrl(json['imageUrl']),
    showInExtras: json['showInExtras'] as bool? ?? false,
  );

  /// Missing, null, blank or non-http(s) → null: a bad value must only ever
  /// cost the photo (the icon shows instead), never the catalog.
  static String? _readImageUrl(Object? value) {
    if (value is! String) return null;
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasAuthority) return null;
    return (uri.scheme == 'https' || uri.scheme == 'http') ? raw : null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'priceUzs': priceUzs,
    'category': category,
    'icon': icon,
    'offlineOnly': offlineOnly,
    'imageUrl': imageUrl,
    'showInExtras': showInExtras,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    priceUzs,
    category,
    icon,
    offlineOnly,
    imageUrl,
    showInExtras,
  ];
}
