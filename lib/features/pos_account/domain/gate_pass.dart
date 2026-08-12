import 'package:equatable/equatable.dart';

class GatePass extends Equatable {
  const GatePass({
    required this.id,
    required this.childId,
    required this.code,
    required this.planLabel,
    required this.priceUzs,
    required this.expiresAt,
  });

  final String id;
  final String childId;
  final String code;
  final String planLabel;
  final int priceUzs;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [
    id,
    childId,
    code,
    planLabel,
    priceUzs,
    expiresAt,
  ];
}

class IssuedPasses extends Equatable {
  const IssuedPasses({required this.saleId, required this.passes});

  final String saleId;
  final List<GatePass> passes;

  @override
  List<Object?> get props => [saleId, passes];
}
