import 'package:equatable/equatable.dart';

class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    required this.priceUzs,
    required this.category,
    required this.icon,
    this.offlineOnly = false,
  });

  final String id;
  final String name;
  final int priceUzs;
  final String category;

  /// Phosphor icon class name from the design system (e.g. `ph-ticket`).
  final String icon;

  /// Only sold in offline mode — e.g. the VIP / hourly plans, which online
  /// mint a QR and so can't be issued without the server. Hidden from the
  /// grid online; the backend also refuses them at online checkout.
  final bool offlineOnly;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    priceUzs: json['priceUzs'] as int,
    category: json['category'] as String,
    icon: json['icon'] as String,
    offlineOnly: json['offlineOnly'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'priceUzs': priceUzs,
    'category': category,
    'icon': icon,
    'offlineOnly': offlineOnly,
  };

  @override
  List<Object?> get props => [id, name, priceUzs, category, icon, offlineOnly];
}
