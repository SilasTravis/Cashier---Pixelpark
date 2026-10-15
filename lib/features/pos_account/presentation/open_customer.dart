import 'package:flutter/material.dart';

import '../../../generated/l10n.dart';
import '../../../injector_container.dart';
import '../data/pos_account_repository_impl.dart';
import '../domain/customer.dart';

/// Finds the customer who owns [phone] — the way "Park ichida" and
/// "Kirdi-chiqdi tarixi" jump to a parent's account page.
///
/// A spinner covers the lookup; when nobody matches (or the lookup fails) a
/// snackbar says so and the result is null.
Future<Customer?> findCustomerByPhone(
  BuildContext context,
  String phone,
) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalization.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  final result = await sl<PosAccountRepository>().searchCustomers(phone);
  if (navigator.canPop()) navigator.pop();
  Customer? found;
  result.fold((_) {}, (customers) {
    for (final item in customers) {
      if (_digits(item.phoneNumber) == _digits(phone)) {
        found = item;
        break;
      }
    }
  });
  if (found == null) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.accountNotFoundForPhone(phone))),
    );
  }
  return found;
}

String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');
