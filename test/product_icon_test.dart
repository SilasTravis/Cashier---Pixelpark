import 'package:cashier_app/features/products/presentation/product_icon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

void main() {
  test('reads the Dashboard\'s full class list as well as a bare name', () {
    expect(productIconFor('ph ph-baby'), PhosphorIconsRegular.baby);
    expect(productIconFor('ph-baby'), PhosphorIconsRegular.baby);
    expect(productIconFor('  ph   ph-ticket '), PhosphorIconsRegular.ticket);
  });

  test('an unknown or empty name falls back to the package icon', () {
    expect(productIconFor('ph ph-nope'), PhosphorIconsRegular.package);
    expect(productIconFor(''), PhosphorIconsRegular.package);
  });
}
