import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'direct_print_job.dart';
import 'receipt_art.dart';

class ParkingReceiptPrinter {
  static const _mm = PdfPageFormat.mm;

  // Heavy outlines and solid shapes survive a 203 dpi monochrome print.
  // The P is a path so the parking sign needs no font in the SVG renderer.
  static const _car = '''
<svg viewBox="0 0 150 82">
  <path d="M124 39v32" fill="none" stroke="#000" stroke-width="4"/>
  <rect x="110" y="8" width="28" height="32" rx="5" fill="#000"/>
  <path d="M119 32V16h6a5 5 0 0 1 0 10h-6" fill="none" stroke="#fff" stroke-width="3.4"/>
  <path d="M6 59l3-12q1-5 8-6l7-1 10-15q3-5 10-5h24q7 0 12 6l12 14 9 3q5 1 6 7l1 8q0 4-5 4H12q-7 0-6-3z"
    fill="#fff" stroke="#000" stroke-width="3.6" stroke-linejoin="round"/>
  <path d="M31 39l9-13h13v13zm26 0V26h11q3 0 6 4l8 9z" fill="#000"/>
  <path d="M60 46h6m32 3h6M9 49h5" fill="none" stroke="#000" stroke-width="3" stroke-linecap="round"/>
  <circle cx="28" cy="60" r="9" fill="#000"/><circle cx="28" cy="60" r="3.8" fill="#fff"/>
  <circle cx="86" cy="60" r="9" fill="#000"/><circle cx="86" cy="60" r="3.8" fill="#fff"/>
  <path d="M5 71h133" fill="none" stroke="#000" stroke-width="2.5" stroke-linecap="round"/>
</svg>''';

  static Future<void> printReceipt({
    required String branchName,
    required DateTime issuedAt,
    String? preferredPrinterName,
  }) async {
    final slip = await render(branchName: branchName, issuedAt: issuedAt);
    final ok = await DirectPrintJob.submit(
      bytes: slip.bytes,
      format: slip.format,
      name: 'parking-${issuedAt.millisecondsSinceEpoch}',
      printerName: preferredPrinterName,
      document: ThermalDocument.parking,
    );
    if (!ok) throw StateError('Parking receipt was not confirmed');
  }

  static Future<({Uint8List bytes, PdfPageFormat format})> render({
    required String branchName,
    required DateTime issuedAt,
  }) async {
    final art = await ReceiptArt.load();
    pw.TextStyle type(pw.Font font, double size) =>
        pw.TextStyle(font: font, fontSize: size);
    final page = pw.Page(
      pageFormat: const PdfPageFormat(
        79 * _mm,
        double.infinity,
        marginTop: 5 * _mm,
        marginLeft: 3 * _mm,
        marginRight: 13 * _mm,
        marginBottom: 6 * _mm,
      ),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(art.logo, width: 22 * _mm),
          pw.SizedBox(height: 3 * _mm),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              ReceiptArt.svg(ReceiptArt.sparkle, 3, 3),
              pw.SizedBox(width: 3 * _mm),
              pw.Text(
                'PIXEL BILAN',
                style: type(art.bold, 10).copyWith(letterSpacing: 1.4),
              ),
              pw.SizedBox(width: 3 * _mm),
              ReceiptArt.svg(ReceiptArt.sparkle, 3, 3),
            ],
          ),
          pw.Text('PARKOVKA', style: type(art.display, 24)),
          pw.Text('BEPUL', style: type(art.display, 36)),
          pw.SizedBox(height: 2 * _mm),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Image(art.bear, width: 22 * _mm),
              ReceiptArt.svg(_car, 34, 19),
            ],
          ),
          pw.SizedBox(height: 3 * _mm),
          pw.Text('Sizning xizmatingizdamiz!', style: type(art.bold, 10.5)),
          pw.SizedBox(height: 4 * _mm),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          if (branchName.trim().isNotEmpty)
            pw.Text(
              branchName.trim(),
              textAlign: pw.TextAlign.center,
              style: type(art.bold, 9.5),
            ),
          pw.Text(
            DateFormat('dd.MM.yyyy   HH:mm').format(issuedAt.toLocal()),
            style: type(art.semiBold, 9),
          ),
        ],
      ),
    );
    final doc = pw.Document()..addPage(page);
    final bytes = await doc.save();
    return (bytes: bytes, format: page.pageFormat);
  }
}
