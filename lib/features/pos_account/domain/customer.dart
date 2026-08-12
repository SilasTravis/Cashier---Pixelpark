import 'package:equatable/equatable.dart';

class Child extends Equatable {
  const Child({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
  });

  final String id;
  final String firstName;
  final String? lastName;
  final DateTime birthDate;

  String get fullName => [firstName, lastName].whereType<String>().join(' ');

  @override
  List<Object?> get props => [id, firstName, lastName, birthDate];
}

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.balance,
    required this.children,
  });

  final int id;
  final String phoneNumber;
  final String firstName;
  final String? lastName;
  final int balance;
  final List<Child> children;

  String get fullName => [
    firstName,
    lastName,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' ');

  Customer copyWith({int? balance, List<Child>? children}) {
    return Customer(
      id: id,
      phoneNumber: phoneNumber,
      firstName: firstName,
      lastName: lastName,
      balance: balance ?? this.balance,
      children: children ?? this.children,
    );
  }

  @override
  List<Object?> get props => [
    id,
    phoneNumber,
    firstName,
    lastName,
    balance,
    children,
  ];
}
