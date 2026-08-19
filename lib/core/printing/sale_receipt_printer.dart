import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/pos_sale/domain/sale_receipt.dart';
import '../utils/receipt_id.dart';

class SaleReceiptPrinter {
  static const double _paperWidthMm = 79;
  static const double _leftPaddingMm = 3;
  static const double _rightPaddingMm = 13;
  static const double _verticalPaddingMm = 10;
  static const double _contentWidthMm = 63;

  static bool hasPrintableProducts(SaleReceipt receipt) =>
      receipt.items.any((item) => !_isGateTicket(item.nameSnapshot));

  static Future<bool> printDirect(
    SaleReceipt receipt, {
    required String branchName,
    required String cashierName,
    String? preferredPrinterName,
  }) async {
    if (!hasPrintableProducts(receipt)) return true;
    final printers = await Printing.listPrinters();
    final target = preferredPrinterName == null
        ? printers
              .where((printer) => printer.name.toLowerCase().contains('slk-'))
              .firstOrNull
        : printers
              .where((printer) => printer.name == preferredPrinterName)
              .firstOrNull;
    if (target == null) {
      debugPrint('SaleReceiptPrinter: SLK receipt printer not found');
      return false;
    }
    final format = PdfPageFormat(
      _paperWidthMm * PdfPageFormat.mm,
      _receiptHeightMm(receipt) * PdfPageFormat.mm,
      marginAll: 0,
    );
    return Printing.directPrintPdf(
      printer: target,
      name: 'sale-${formatReceiptId(receipt.id)}',
      format: format,
      usePrinterSettings: true,
      dynamicLayout: false,
      onLayout: (_) =>
          buildPdf(receipt, branchName: branchName, cashierName: cashierName),
    );
  }

  static Future<bool> print(
    SaleReceipt receipt, {
    required String branchName,
    required String cashierName,
  }) {
    return Printing.layoutPdf(
      name: 'sale-${formatReceiptId(receipt.id)}',
      format: PdfPageFormat(
        _paperWidthMm * PdfPageFormat.mm,
        _receiptHeightMm(receipt) * PdfPageFormat.mm,
        marginAll: 0,
      ),
      onLayout: (_) =>
          buildPdf(receipt, branchName: branchName, cashierName: cashierName),
    );
  }

  static Future<Uint8List> buildPdf(
    SaleReceipt receipt, {
    required String branchName,
    required String cashierName,
  }) async {
    final items = receipt.items
        .where((item) => !_isGateTicket(item.nameSnapshot))
        .toList();
    final subtotal = items.fold<int>(0, (sum, item) => sum + item.lineTotalUzs);
    final payment = _paymentForPrintedProducts(receipt, subtotal);
    final document = pw.Document();
    final pageFormat = PdfPageFormat(
      _paperWidthMm * PdfPageFormat.mm,
      _receiptHeightMm(receipt) * PdfPageFormat.mm,
      marginLeft: _leftPaddingMm * PdfPageFormat.mm,
      marginRight: _rightPaddingMm * PdfPageFormat.mm,
      marginTop: _verticalPaddingMm * PdfPageFormat.mm,
      marginBottom: _verticalPaddingMm * PdfPageFormat.mm,
    );
    final regular = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();

    document.addPage(
      pw.Page(
        pageFormat: pageFormat,
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
                pw.SizedBox(height: 8),
                _metadataBlock('Chek', formatReceiptId(receipt.id), regular),
                _metadataBlock(
                  'Sana',
                  DateFormat(
                    'dd.MM.yyyy HH:mm',
                  ).format(receipt.createdAt.toLocal()),
                  regular,
                ),
                if (cashierName.isNotEmpty)
                  _metadataBlock('Kassir', cashierName, regular),
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                for (final item in items) ...[
                  pw.Text(
                    item.nameSnapshot,
                    style: pw.TextStyle(font: regular, fontSize: 9),
                  ),
                  _textRow(
                    '${item.qty} x ${_money(item.priceSnapshotUzs)}',
                    _money(item.lineTotalUzs),
                    regular,
                  ),
                  pw.SizedBox(height: 4),
                ],
                pw.Divider(borderStyle: pw.BorderStyle.dashed),
                _textRow('JAMI', _money(subtotal), bold, fontSize: 12),
                if (payment.cashUzs > 0)
                  _textRow('Naqd', _money(payment.cashUzs), regular),
                if (payment.cardUzs > 0)
                  _textRow('Karta', _money(payment.cardUzs), regular),
                if (payment.balanceUzs > 0)
                  _textRow('Balans', _money(payment.balanceUzs), regular),
                pw.SizedBox(height: 12),
                pw.Text(
                  'Xaridingiz uchun rahmat!',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: regular, fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return document.save();
  }

  static pw.Widget _textRow(
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
        pw.Expanded(
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(font: font, fontSize: fontSize),
          ),
        ),
      ],
    ),
  );

  static pw.Widget _metadataBlock(String label, String value, pw.Font font) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              value,
              style: pw.TextStyle(font: font, fontSize: 8),
              maxLines: 2,
            ),
          ],
        ),
      );

  static String _money(int value) {
    final digits = value.toString();
    return '${digits.replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (_) => ' ')} so\'m';
  }

  static double _receiptHeightMm(SaleReceipt receipt) {
    var height = 98.0;
    for (final item in receipt.items.where(
      (item) => !_isGateTicket(item.nameSnapshot),
    )) {
      final nameLines = (item.nameSnapshot.length / 28).ceil().clamp(1, 3);
      height += 11 + (nameLines - 1) * 5;
    }
    if (receipt.cashUzs > 0) height += 5;
    if (receipt.cardUzs > 0) height += 5;
    if (receipt.balanceUzs > 0) height += 5;
    return height.clamp(105, 280).toDouble();
  }

  static ({int cashUzs, int cardUzs, int balanceUzs})
  _paymentForPrintedProducts(SaleReceipt receipt, int totalUzs) {
    var remaining = totalUzs;
    final cash = math.min(receipt.cashUzs, remaining);
    remaining -= cash;
    final card = math.min(receipt.cardUzs, remaining);
    remaining -= card;
    final balance = math.min(receipt.balanceUzs, remaining);
    return (cashUzs: cash, cardUzs: card, balanceUzs: balance);
  }

  static bool _isGateTicket(String name) {
    final value = name.trim().toLowerCase();
    return value.contains('kirish chiptasi') ||
        value.contains('chiqish chiptasi') ||
        value.contains('входной билет') ||
        value.contains('выходной билет') ||
        value.contains('entry ticket') ||
        value.contains('exit ticket');
  }
}
