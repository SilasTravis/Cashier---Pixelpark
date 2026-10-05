import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// One child's entry ticket: who, which plan, what it costs. [priceUzs] is
/// null for per-minute plans (no fixed price at entry).
typedef ChildTicketEntry = ({
  String childName,
  String planName,
  int? priceUzs,
  String ticketId,
});

/// Text-only entry ticket for the thermal RECEIPT printer — the fallback
/// when no Godex label printer is available to print the gate-pass sticker.
/// Black on white only (1-bit thermal), one compact page per child, laid out
/// with the same paper geometry as [SaleReceiptPrinter] so it lands centred
/// on the SLK roll.
///
/// The PDF uses the built-in Helvetica (Latin only), so text is
/// transliterated to ASCII first — see [asciiText].
class ChildTicketPrinter {
  static const double _paperWidthMm = 79;
  static const double _leftPaddingMm = 3;
  static const double _rightPaddingMm = 13;
  static const double _verticalPaddingMm = 3;
  static const double _contentWidthMm = 63;
  static const double _pageHeightMm = 40;

  static Future<bool> printDirect(
    List<ChildTicketEntry> entries, {
    required String branchName,
    String? preferredPrinterName,
  }) async {
    if (entries.isEmpty) return true;
    final printers = await Printing.listPrinters();
    final target = preferredPrinterName == null
        ? printers
              .where((printer) => printer.name.toLowerCase().contains('slk-'))
              .firstOrNull
        : printers
              .where((printer) => printer.name == preferredPrinterName)
              .firstOrNull;
    if (target == null) {
      debugPrint('ChildTicketPrinter: receipt printer not found');
      return false;
    }
    return Printing.directPrintPdf(
      printer: target,
      name: 'child-ticket-${entries.first.ticketId}',
      format: PdfPageFormat(
        _paperWidthMm * PdfPageFormat.mm,
        _pageHeightMm * PdfPageFormat.mm,
        marginAll: 0,
      ),
      usePrinterSettings: true,
      dynamicLayout: false,
      onLayout: (_) => buildPdf(entries, branchName: branchName),
    );
  }

  static Future<Uint8List> buildPdf(
    List<ChildTicketEntry> entries, {
    required String branchName,
    DateTime? now,
  }) async {
    final document = pw.Document();
    final regular = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final stamp = DateFormat('dd.MM.yy HH:mm').format(now ?? DateTime.now());
    final pageFormat = PdfPageFormat(
      _paperWidthMm * PdfPageFormat.mm,
      _pageHeightMm * PdfPageFormat.mm,
      marginLeft: _leftPaddingMm * PdfPageFormat.mm,
      marginRight: _rightPaddingMm * PdfPageFormat.mm,
      marginTop: _verticalPaddingMm * PdfPageFormat.mm,
      marginBottom: _verticalPaddingMm * PdfPageFormat.mm,
    );

    for (final entry in entries) {
      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (_) => pw.Center(
            child: pw.SizedBox(
              width: _contentWidthMm * PdfPageFormat.mm,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(
                    'PIXEL PARK',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: bold, fontSize: 11),
                  ),
                  if (branchName.isNotEmpty)
                    pw.Text(
                      asciiText(branchName),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: regular, fontSize: 8),
                    ),
                  pw.SizedBox(height: 3),
                  _nameBanner(asciiText(entry.childName).toUpperCase(), bold),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          asciiText(entry.planName).toUpperCase(),
                          style: pw.TextStyle(font: bold, fontSize: 13),
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        entry.priceUzs == null
                            ? 'DAQIQABAY'
                            : _money(entry.priceUzs!),
                        style: pw.TextStyle(font: bold, fontSize: 15),
                      ),
                    ],
                  ),
                  pw.Divider(
                    borderStyle: pw.BorderStyle.dashed,
                    thickness: 1,
                    height: 8,
                  ),
                  pw.Text(
                    '${entry.ticketId}   $stamp',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: regular, fontSize: 7),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return document.save();
  }

  static pw.Widget _nameBanner(String name, pw.Font bold) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: pw.BoxDecoration(
      color: PdfColors.black,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _star(),
        pw.SizedBox(width: 5),
        pw.Flexible(
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            child: pw.Text(
              name,
              maxLines: 1,
              style: pw.TextStyle(
                font: bold,
                fontSize: 17,
                color: PdfColors.white,
              ),
            ),
          ),
        ),
        pw.SizedBox(width: 5),
        _star(),
      ],
    ),
  );

  static pw.Widget _star() => pw.SizedBox(
    width: 8,
    height: 8,
    child: pw.CustomPaint(
      size: const PdfPoint(8, 8),
      painter: (canvas, size) {
        const points = 5;
        final cx = size.x / 2;
        final cy = size.y / 2;
        canvas.setFillColor(PdfColors.white);
        for (var i = 0; i < points * 2; i++) {
          final radius = i.isEven ? size.x / 2 : size.x / 5;
          final angle = -math.pi / 2 + i * math.pi / points;
          final x = cx + radius * math.cos(angle);
          final y = cy - radius * math.sin(angle);
          i == 0 ? canvas.moveTo(x, y) : canvas.lineTo(x, y);
        }
        canvas
          ..closePath()
          ..fillPath();
      },
    ),
  );

  static String _money(int value) {
    final digits = value.toString().replaceAllMapped(
      RegExp(r'(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return "${digits.trim()} SO'M";
  }

  static const _translit = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo', //
    'ж': 'j', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
    'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
    'ф': 'f', 'х': 'x', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sh', 'ъ': '',
    'ы': 'i', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya', 'ў': 'o', 'қ': 'q',
    'ғ': 'g', 'ҳ': 'h',
  };

  /// Helvetica (built-in) is Latin-only: transliterate Cyrillic (keeping
  /// the original letter case), unify the various apostrophes, and replace
  /// anything else non-ASCII with '?'.
  @visibleForTesting
  static String asciiText(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final lower = char.toLowerCase();
      final mapped = _translit[lower];
      if (mapped != null) {
        buffer.write(lower == char ? mapped : _capitalize(mapped));
      } else if ('‘’ʻʼ`´'.contains(char)) {
        buffer.write("'");
      } else if (rune < 128) {
        buffer.write(char);
      } else {
        buffer.write('?');
      }
    }
    return buffer.toString().trim();
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
