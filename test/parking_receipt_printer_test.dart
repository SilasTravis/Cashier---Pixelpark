import 'dart:convert';

import 'package:cashier_app/core/printing/parking_receipt_printer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'renders one thermal slip with enough height for a long branch name',
    () async {
      final issuedAt = DateTime(2026, 11, 19, 14, 35);
      final sample = await ParkingReceiptPrinter.render(
        branchName: 'Chilonzor',
        issuedAt: issuedAt,
      );
      final long = await ParkingReceiptPrinter.render(
        branchName: List.filled(10, 'Chilonzor').join(' '),
        issuedAt: issuedAt,
      );
      for (final slip in [sample, long]) {
        final pdf = latin1.decode(slip.bytes);
        expect(pdf, startsWith('%PDF'));
        expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf), hasLength(1));
        expect(slip.format.width / PdfPageFormat.mm, closeTo(79, 0.01));
      }
      expect(sample.format.height / PdfPageFormat.mm, lessThan(76));
      expect(long.format.height, greaterThan(sample.format.height));
    },
  );
}
