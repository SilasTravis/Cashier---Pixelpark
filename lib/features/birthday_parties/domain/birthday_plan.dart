import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';

/// `#RRGGBB` -> opaque [Color]; [fallback] for anything malformed.
Color colorOf(String hex, Color fallback) {
  final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex.trim());
  if (match == null) return fallback;
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}

class BirthdayPlanSize extends Equatable {
  const BirthdayPlanSize({
    required this.childCount,
    required this.priceUzs,
    required this.extraChildUzs,
  });

  final int childCount;
  final int priceUzs;
  final int extraChildUzs;

  factory BirthdayPlanSize.fromJson(Map<String, dynamic> json) =>
      BirthdayPlanSize(
        childCount: json['childCount'] as int,
        priceUzs: json['priceUzs'] as int,
        extraChildUzs: json['extraChildUzs'] as int,
      );

  @override
  List<Object?> get props => [childCount, priceUzs, extraChildUzs];
}

class BirthdayPlan extends Equatable {
  const BirthdayPlan({
    required this.id,
    required this.name,
    required this.color,
    required this.active,
    required this.allBranches,
    required this.branchIds,
    required this.includedItems,
    required this.sortOrder,
    required this.sizes,
  });

  final String id;
  final String name;
  final String color;
  final bool active;
  final bool allBranches;
  final List<String> branchIds;
  final List<String> includedItems;
  final int sortOrder;
  final List<BirthdayPlanSize> sizes;

  factory BirthdayPlan.fromJson(Map<String, dynamic> json) => BirthdayPlan(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String,
    active: json['active'] as bool,
    allBranches: json['allBranches'] as bool,
    branchIds: (json['branchIds'] as List).cast<String>(),
    includedItems: (json['includedItems'] as List).cast<String>(),
    sortOrder: json['sortOrder'] as int,
    sizes: (json['sizes'] as List)
        .map(
          (e) => BirthdayPlanSize.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
  );

  @override
  List<Object?> get props => [
    id,
    name,
    color,
    active,
    allBranches,
    branchIds,
    includedItems,
    sortOrder,
    sizes,
  ];
}
