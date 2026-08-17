// The Windows print path (PDFium drawing straight into the label driver's
// GDI device context) silently drops vector/text/alpha content on thermal
// drivers — labels feed but print blank. The fix rasterizes each page and
// submits an image-only PDF. These tests pin down that image-only PDF:
// it must exist, be page-sized to the 58×40mm label, and embed the raster
// as a plain OPAQUE image (no /SMask soft mask — alpha would put the GDI
// AlphaBlend call right back on the flaky-driver path).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'package:cashier_app/core/printing/gate_pass_label_printer.dart';

/// A [width]×[height] RGBA raster with a mix of colors and non-opaque
/// alpha values — the alpha must NOT survive into the PDF.
PdfRasterBase _fakeRaster(int width, int height) {
  final pixels = Uint8List(width * height * 4);
  for (var i = 0; i < width * height; i++) {
    pixels[i * 4] = i.isEven ? 0x00 : 0xFF; // R
    pixels[i * 4 + 1] = 0x80; // G
    pixels[i * 4 + 2] = 0xFF; // B
    pixels[i * 4 + 3] = i.isEven ? 0xFF : 0x40; // A: some translucent
  }
  return PdfRasterBase(width, height, true, pixels);
}

void main() {
  test('rasterizedLabelPdf builds an image-only PDF with no soft mask',
      () async {
    final bytes = await GatePassLabelPrinter.rasterizedLabelPdf(
      Stream.fromIterable([_fakeRaster(46, 32), _fakeRaster(46, 32)]),
    );

    expect(bytes, isNotNull);
    final pdf = latin1.decode(bytes!);
    expect(pdf, startsWith('%PDF'));
    // Two pages, one per sticker.
    expect('/Type /Page '.allMatches(pdf).length +
        '/Type /Page\n'.allMatches(pdf).length +
        '/Type/Page'.allMatches(pdf).length,
        greaterThanOrEqualTo(2));
    // The embedded raster must be opaque: a soft mask means the alpha
    // channel leaked through and Windows GDI printing would need
    // AlphaBlend again.
    expect(pdf.contains('/SMask'), isFalse);
    // Page is the physical 58×40mm label (in points: ~164.4 × ~113.4).
    expect(pdf, contains('164.4'));
    expect(pdf, contains('113.3'));
  });

  test('rasterizedLabelPdf returns null when rasterization yields no pages',
      () async {
    final bytes = await GatePassLabelPrinter.rasterizedLabelPdf(
      const Stream.empty(),
    );
    expect(bytes, isNull);
  });
}
