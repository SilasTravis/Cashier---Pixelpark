import '../../domain/entities/cashier.dart';

class CashierModel extends Cashier {
  const CashierModel({
    required super.id,
    required super.fullName,
    required super.username,
    required super.branchId,
    required super.active,
  });

  factory CashierModel.fromJson(Map<String, dynamic> json) => CashierModel(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    username: json['username'] as String,
    branchId: json['branchId'] as String,
    active: json['active'] as bool,
  );
}

class BranchModel extends Branch {
  const BranchModel({
    required super.id,
    required super.slug,
    required super.name,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) => BranchModel(
    id: json['id'] as String,
    slug: json['slug'] as String,
    name: json['name'] as String,
  );
}
