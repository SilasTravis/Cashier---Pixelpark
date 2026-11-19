import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'direct_print_job.dart';
import 'receipt_art.dart';

class ParkingReceiptPrinter {
  static const _mm = PdfPageFormat.mm;

  // Open-top car: the bundled Pixel mascot sits behind this foreground.
  // Solid shapes and thick outlines stay legible on the thermal roll.
  static const _parkingScene = '''
<svg viewBox="0 0 240 88">
  <path d="M12 75h157m12 0h44" stroke="#000" stroke-width="2.5" stroke-linecap="round"/>
  <path d="M9 46h13m-18 7h13" stroke="#000" stroke-width="2.3" stroke-linecap="round"/>
  <g fill="#fff" stroke="#000" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round">
    <path d="M103 41l8-18h7l15 19z"/>
    <path d="M25 40q0-4 5-4h17l8 8h42l6-5h28q13 1 25 7l9 5q5 3 5 10v3q0 4-5 4H31q-7 0-8-8l-1-11q0-5 3-9z"/>
    <path d="M62 45l4 12q1 3 5 3h34q4 0 6-4l6-14" fill="none" stroke-width="2.3"/>
  </g>
  <path d="M77 49h10m65 2h8m-136-4h8" stroke="#000" stroke-width="3.4" stroke-linecap="round"/>
  <g fill="#000"><circle cx="47" cy="64" r="11"/><circle cx="139" cy="64" r="11"/></g>
  <g fill="#fff"><circle cx="47" cy="64" r="5"/><circle cx="139" cy="64" r="5"/></g>
  <g fill="#000"><circle cx="47" cy="64" r="2"/><circle cx="139" cy="64" r="2"/></g>
  <path d="M197 37v35m-9 0h18" stroke="#000" stroke-width="4" stroke-linecap="round"/>
  <rect x="181" y="5" width="32" height="35" rx="7" fill="#000"/>
  <path d="M192 31V14h7a5.2 5.2 0 0 1 0 10h-7" fill="none" stroke="#fff" stroke-width="3.8" stroke-linejoin="round"/>
  <path d="M151 8q1 6 7 7-6 1-7 7-1-6-7-7 6-1 7-7z" fill="#000"/>
</svg>''';

  static const _ticketOutline = '''
<svg viewBox="0 0 240 52">
  <path d="M10 2h220q8 0 8 8v8a8 8 0 0 0 0 16v8q0 8-8 8H10q-8 0-8-8v-8a8 8 0 0 0 0-16v-8q0-8 8-8z"
    fill="none" stroke="#000" stroke-width="2.8"/>
  <path d="M16 10v5m0 22v5m208-32v5m0 22v5" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round"/>
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
        marginTop: 4 * _mm,
        marginLeft: 3 * _mm,
        marginRight: 13 * _mm,
        marginBottom: 4 * _mm,
      ),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(art.logo, width: 20 * _mm),
          pw.SizedBox(height: 1.8 * _mm),
          pw.Text(
            'PIXEL BILAN',
            style: type(art.bold, 9.5).copyWith(letterSpacing: 1.5),
          ),
          pw.SizedBox(height: 1 * _mm),
          pw.Stack(
            alignment: pw.Alignment.center,
            children: [
              ReceiptArt.svg(_ticketOutline, 62, 13.4),
              pw.Text('PARKOVKA BEPUL', style: type(art.display, 16.8)),
            ],
          ),
          pw.SizedBox(height: 2.4 * _mm),
          pw.SizedBox(
            width: 60 * _mm,
            height: 22 * _mm,
            child: pw.Stack(
              children: [
                pw.Positioned(
                  left: 10.8 * _mm,
                  top: 0,
                  child: pw.Image(art.bear, width: 16.5 * _mm),
                ),
                ReceiptArt.svg(_parkingScene, 60, 22),
              ],
            ),
          ),
          pw.Text('Sizning xizmatingizdamiz!', style: type(art.bold, 10.5)),
          pw.SizedBox(height: 1.2 * _mm),
          pw.Divider(thickness: 0.8, borderStyle: pw.BorderStyle.dashed),
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
