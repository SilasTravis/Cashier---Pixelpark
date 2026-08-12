import 'package:equatable/equatable.dart';

class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    required this.priceUzs,
    required this.category,
    required this.icon,
  });

  final String id;
  final String name;
  final int priceUzs;
  final String category;

  /// Phosphor icon class name from the design system (e.g. `ph-ticket`).
  final String icon;

  @override
  List<Object?> get props => [id, name, priceUzs, category, icon];
}
