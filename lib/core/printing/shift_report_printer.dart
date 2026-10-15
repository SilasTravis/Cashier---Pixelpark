import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/shift/domain/shift.dart';
import 'sale_receipt_printer.dart';

/// The shift close-out check: takings, tickets per tariff and children,
/// printed on the receipt printer when the cashier closes the shift. Same
/// paper and ASCII-only Helvetica as [SaleReceiptPrinter].
class ShiftReportPrinter {
  static const double _paperWidthMm = 79;
  static const double _leftPaddingMm = 3;
  static const double _rightPaddingMm = 13;
  static const double _verticalPaddingMm = 10;
  static const double _contentWidthMm = 63;

  static Future<bool> printDirect(
    Shift shift, {
    required String branchName,
    required String cashierName,
    String? preferredPrinterName,
  }) async {
    final target = await SaleReceiptPrinter.findReceiptPrinter(
      preferredPrinterName,
    );
    if (target == null) {
      debugPrint('ShiftReportPrinter: receipt printer not found');
      return false;
    }
    return Printing.directPrintPdf(
      printer: target,
      name: 'shift-${shift.id.substring(0, 8)}',
      format: PdfPageFormat(
        _paperWidthMm * PdfPageFormat.mm,
        heightMm(shift) * PdfPageFormat.mm,
        marginAll: 0,
      ),
      usePrinterSettings: true,
      dynamicLayout: false,
      onLayout: (_) =>
          buildPdf(shift, branchName: branchName, cashierName: cashierName),
    );
  }

  /// The lines of the check, label → value; `null` value = section title.
  @visibleForTesting
  static List<(String, String?)> lines(Shift shift) {
    final t = shift.totals;
    final entries = t.entries;
    return [
      ('Cheklar soni', '${t.salesCount}'),
      ('Naqd', _money(t.cashUzs)),
      ('Karta', _money(t.cardUzs)),
      if (t.topupUzs > 0) ('Shundan balans to\'ldirish', _money(t.topupUzs)),
      if (t.balanceSalesUzs > 0)
        ('Balansdan (tushum emas)', _money(t.balanceSalesUzs)),
      if (t.discountUzs > 0) ('Chegirma', '-${_money(t.discountUzs)}'),
      if (t.refundedUzs > 0) ('Qaytarildi', '-${_money(t.refundedUzs)}'),
      if (entries != null) ...[
        ('BILETLAR', null),
        for (final line in entries.tariffs) (line.label, '${line.count} ta'),
        ('Jami biletlar', '${entries.ticketsCount} ta'),
        ('Shundan VIP', '${entries.vipCount} ta'),
        ('BOLALAR', null),
        ('Takrorlanmas bolalar', '${entries.uniqueChildren} ta'),
        ('Ichkariga kirgan', '${entries.enteredChildren} ta'),
      ],
    ];
  }

  static Future<Uint8List> buildPdf(
    Shift shift, {
    required String branchName,
    required String cashierName,
  }) async {
    final document = pw.Document();
    final regular = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final time = DateFormat('dd.MM.yyyy HH:mm');
    final closedAt = shift.closedAt ?? DateTime.now();

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          _paperWidthMm * PdfPageFormat.mm,
          heightMm(shift) * PdfPageFormat.mm,
          marginLeft: _leftPaddingMm * PdfPageFormat.mm,
          marginRight: _rightPaddingMm * PdfPageFormat.mm,
          marginTop: _verticalPaddingMm * PdfPageFormat.mm,
          marginBottom: _verticalPaddingMm * PdfPageFormat.mm,
        ),
        build: (_) => pw.Center(
          child: pw.SizedBox(
            width: _contentWidthMm * PdfPageFormat.mm,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'PIXEL PARK',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
                pw.SizedBox(height: 3),
                if (branchName.isNotEmpty)
                  pw.Text(
                    branchName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regular, fontSize: 9),
                  ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'SMENA HISOBOTI',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: bold, fontSize: 11),
                ),
                pw.SizedBox(height: 8),
                if (cashierName.isNotEmpty)
                  _row('Kassir', cashierName, regular),
                _row('Ochildi', time.format(shift.openedAt.toLocal()), regular),
                _row('Yopildi', time.format(closedAt.toLocal()), regular),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                for (final (label, value) in lines(shift))
                  if (value == null) ...[
                    pw.Divider(borderStyle: pw.BorderStyle.dashed),
                    pw.Text(
                      label,
                      style: pw.TextStyle(font: bold, fontSize: 9),
                    ),
                    pw.SizedBox(height: 2),
                  ] else
                    _row(label, value, regular),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                _row(
                  'JAMI TUSHUM',
                  _money(shift.totals.grandTotalUzs),
                  bold,
                  fontSize: 12,
                ),
                pw.SizedBox(height: 16),
                _row('Kassir imzosi', '______________', regular),
              ],
            ),
          ),
        ),
      ),
    );
    return document.save();
  }

  static pw.Widget _row(
    String label,
    String value,
    pw.Font font, {
    double fontSize = 9,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: fontSize),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          value,
          style: pw.TextStyle(font: font, fontSize: fontSize),
        ),
      ],
    ),
  );

  static String _money(int value) {
    final digits = value.abs().toString().replaceAllMapped(
      RegExp(r'(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '${value < 0 ? '-' : ''}${digits.trim()} so\'m';
  }

  @visibleForTesting
  static double heightMm(Shift shift) {
    final rows = lines(shift);
    final titles = rows.where((row) => row.$2 == null).length;
    final height = 80.0 + rows.length * 5 + titles * 6;
    return height.clamp(100, 400).toDouble();
  }
}
