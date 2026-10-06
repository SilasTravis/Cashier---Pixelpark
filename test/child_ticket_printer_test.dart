import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/printing/child_ticket_printer.dart';

void main() {
  test('asciiText transliterates Cyrillic and unifies apostrophes', () {
    expect(ChildTicketPrinter.asciiText('Алишер'), 'Alisher');
    expect(ChildTicketPrinter.asciiText('Қодир'), 'Qodir');
    expect(ChildTicketPrinter.asciiText('Oʻktam'), "O'ktam");
    expect(ChildTicketPrinter.asciiText('  Ali  '), 'Ali');
  });

  test('buildPdf makes one page per child', () async {
    final bytes = await ChildTicketPrinter.buildPdf(
      const [
        (
          qrData: 'gate-pass-token',
          childName: 'Алишер',
          planName: 'VIP 2 soat',
          priceUzs: 85000,
          discountUzs: 85000,
          discountName: 'Tugʻilgan kun',
          ticketId: '35b4fb47',
        ),
        (
          qrData: 'gate-pass-token',
          childName: 'Muhammadaminxon',
          planName: 'Standart',
          priceUzs: null,
          discountUzs: 0,
          discountName: null,
          ticketId: 'abc12345',
        ),
      ],
      branchName: 'Megaplanet',
      now: DateTime(2026, 10, 5, 14, 32),
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    final one = await ChildTicketPrinter.buildPdf(const [
      (
        qrData: 'gate-pass-token',
        childName: 'Ali',
        planName: 'Standart',
        priceUzs: 1000,
        discountUzs: 0,
        discountName: null,
        ticketId: 'abc12345',
      ),
    ], branchName: 'Megaplanet');
    expect(bytes.length, greaterThan(one.length));
  });
}
