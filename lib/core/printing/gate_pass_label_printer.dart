import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart'
    show MethodChannel, PlatformException, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// One gate-pass sticker to print. [invertName] renders the name strip as
/// a filled dark bar with the name in white — the PARENT sticker style,
/// distinguishable from a child sticker at arm's length.
typedef GatePassLabelEntry = ({String qrData, String name, bool invertName});

/// Prints 58×40mm gate-pass stickers on a thermal label printer (Godex
/// G500, 203dpi) via the OS print dialog — no vendor SDK needed.
///
/// Each sticker = branded background + our QR code + the child's name.
/// A batch prints as ONE document with ONE PAGE PER STICKER — the printer
/// advances to the next die-cut label between pages using its own gap
/// sensor. (Stacking several labels onto one tall page does NOT work: the
/// page content drifts across the physical label boundaries and bleeds
/// onto the next card. The driver's "Label gap length" must match the
/// roll's real 3mm gap.)
///
/// ## The background asset
///
/// `assets/images/gate_pass_label_bg.png` is derived from the "nakleyka
/// pixel" B/W design (GAME TIME + character + Pixel Park logo):
///
///  * the baked-in QR was erased (its black border frame kept) — our QR is
///    drawn there,
///  * the "WELCOME TO THE PIXEL PARK" footer was erased — the child's name
///    is drawn there,
///  * rotated to landscape 58×40mm and rasterized to exactly 463×320 px —
///    the printer's native dot grid at 203dpi — with every pixel pure black
///    or white. Anything gray/antialiased gets dithered into visible noise
///    by the thermal driver; pre-thresholded pixel-per-dot art is what
///    keeps the print clean,
///  * the registration safe margins are baked in: art pre-shrunk to
///    [_labelScale] and centered, margins white.
///
/// Because the margins are baked into the asset, the background is drawn
/// FULL-BLEED (one asset pixel = one printer dot; scaling it here would
/// resample the 1-bit art back into grays). Only the QR/name overlays go
/// through the safe-area mapping — they are PDF vectors and stay sharp.
class GatePassLabelPrinter {
  static const _windowsPrintChannel = MethodChannel(
    'cashier/native_label_printer',
  );
  // ---- Label geometry (mm) ------------------------------------------------

  static const double _labelWidthMm = 58.0;
  static const double _labelHeightMm = 40.0;

  /// Feed registration can drift a couple mm sideways, so everything is
  /// shrunk/centered into a safe area 3mm in from both side edges — drift
  /// eats blank margin instead of clipping the art. Baked into the bg asset
  /// too: change one, change both (regenerate the asset).
  static const double _safeMarginMm = 3.0;
  static const double _labelScale =
      (_labelWidthMm - 2 * _safeMarginMm) / _labelWidthMm;

  /// Measured registration correction for our printer: test prints landed
  /// off toward the label's left edge, so everything (background AND
  /// overlays) is nudged this much to the right. Dialed in over test
  /// prints (3mm overshot slightly). Re-measure on a new printer/roll if
  /// prints drift again.
  static const double _regOffsetXMm = 2.0;

  /// Design-space rects (mm, top-down, in the un-shrunk 58×40 design),
  /// measured off the 1200dpi render the asset was made from. QR rect is
  /// the emptied interior of the design's QR frame; the name strip is where
  /// the welcome footer used to be (left edge of the rotated design).
  static const double _qrLeftMm = 6.69;
  static const double _qrTopMm = 18.08;
  static const double _qrRightMm = 26.65;
  static const double _qrBottomMm = 38.04;

  static const double _nameLeftMm = 0.0;
  static const double _nameTopMm = 0.0;
  static const double _nameRightMm = 4.45;
  static const double _nameBottomMm = 40.0;

  /// White quiet zone kept between the QR modules and the frame.
  static const double _qrQuietZoneMm = 1.5;

  static const double _maxNameFontPt = 10.0;

  /// Helvetica-Bold's average glyph advance ≈ 0.6× font size — close
  /// enough to size/center a short name without querying real font metrics.
  static const double _avgGlyphAdvance = 0.6;

  /// Godex G500 native resolution. Rasterizing at exactly this dpi keeps
  /// the raster 1:1 with the printer's dot grid (and with the bg asset's
  /// pixel-per-dot art), so the Windows raster path loses nothing vs the
  /// vector original.
  static const double _printerDpi = 203.0;

  // ---- Public API ---------------------------------------------------------

  /// Prints straight to the label printer with NO OS dialog: picks the
  /// first printer whose name contains "godex" (or the OS default printer
  /// as a fallback), and uses the printer's own saved driver settings —
  /// which is where the label-gap/media configuration lives. If no printer
  /// is found at all, falls back to the [print] dialog so the cashier can
  /// pick one manually.
  ///
  /// Returns false when the direct submission did NOT happen (no printer,
  /// or the plugin reported failure) — callers must surface that instead of
  /// letting the sticker vanish silently.
  static Future<bool> printDirect(List<GatePassLabelEntry> entries) async {
    assert(entries.isNotEmpty, 'GatePassLabelPrinter.printDirect: no entries');
    final printers = await Printing.listPrinters();
    debugPrint(
      'GatePassLabelPrinter: printers=${printers.map((p) => '${p.name}${p.isDefault ? '*' : ''}').join(', ')}',
    );
    Printer? target;
    for (final p in printers) {
      if (p.name.toLowerCase().contains('godex')) {
        target = p;
        break;
      }
    }
    target ??= printers.where((p) => p.isDefault).firstOrNull;
    if (target == null) {
      debugPrint('GatePassLabelPrinter: no printer found — opening dialog');
      await print(entries);
      return true;
    }
    debugPrint('GatePassLabelPrinter: direct print → ${target.name}');
    if (Platform.isWindows) {
      return _printDirectWindows(entries, target);
    }
    final ok = await Printing.directPrintPdf(
      printer: target,
      // The label size MUST be passed here: on macOS the plugin takes the
      // job's paper size from this format (defaulting to A4/Letter if
      // omitted, which prints our 58×40 label into a corner of a blank
      // letter-sized page). On Windows usePrinterSettings hands media
      // handling to the driver's saved stock settings instead.
      format: PdfPageFormat(
        _mm(_labelWidthMm),
        _mm(_labelHeightMm),
        marginAll: 0,
      ),
      onLayout: (_) => _printablePdf(entries),
      name: _jobName(entries),
      usePrinterSettings: true,
      // false = skip the OS print-options modal entirely and send straight
      // to the printer. (directPrintPdf defaults this to true, which on
      // macOS runs NSPrintOperation.runModal — the popup we're avoiding.)
      dynamicLayout: false,
    );
    debugPrint('GatePassLabelPrinter: direct print result=$ok');
    return ok;
  }

  /// Windows' PDFium-to-printer-HDC path can produce a successful but blank
  /// job on thermal drivers. Send opaque raster pages to a native DIB spooler
  /// so the driver receives the same simple bitmap operation as its test page.
  static Future<bool> _printDirectWindows(
    List<GatePassLabelEntry> entries,
    Printer target,
  ) async {
    final vector = await _buildPdf(entries);
    final pages = <Map<String, Object>>[];
    await for (final page in Printing.raster(vector, dpi: _printerDpi)) {
      pages.add({
        'width': page.width,
        'height': page.height,
        'pixels': page.pixels,
      });
    }
    if (pages.isEmpty) {
      debugPrint('GatePassLabelPrinter: Windows raster produced 0 pages');
      return false;
    }
    try {
      final ok = await _windowsPrintChannel.invokeMethod<bool>(
        'printRgbaPages',
        {
          'printerName': target.name,
          'jobName': _jobName(entries),
          'pages': pages,
        },
      );
      debugPrint('GatePassLabelPrinter: native Windows print result=$ok');
      return ok ?? false;
    } on PlatformException catch (error) {
      debugPrint(
        'GatePassLabelPrinter: native Windows print failed: '
        '${error.code}: ${error.message}',
      );
      return false;
    }
  }

  /// Prints via the OS print dialog (manual printer choice).
  static Future<void> print(List<GatePassLabelEntry> entries) {
    assert(entries.isNotEmpty, 'GatePassLabelPrinter.print: no entries');
    return Printing.layoutPdf(
      onLayout: (_) => _printablePdf(entries),
      name: _jobName(entries),
    );
  }

  static String _jobName(List<GatePassLabelEntry> entries) =>
      entries.length == 1
      ? 'gate-pass-${entries.single.name}'
      : 'gate-pass-batch';

  // ---- PDF assembly -------------------------------------------------------

  static double _mm(double mm) => mm * PdfPageFormat.mm;

  /// Design-space mm → page mm, applying the safe-area shrink/center.
  static double _pageX(double designXMm) =>
      _regOffsetXMm + _safeMarginMm + designXMm * _labelScale;

  static double _pageY(double designYMm) =>
      (_labelHeightMm - _labelHeightMm * _labelScale) / 2 +
      designYMm * _labelScale;

  static Future<Uint8List> _buildPdf(List<GatePassLabelEntry> entries) async {
    final bg = pw.MemoryImage(
      (await rootBundle.load(
        'assets/images/gate_pass_label_bg.png',
      )).buffer.asUint8List(),
    );
    final font = pw.Font.helveticaBold();

    final doc = pw.Document();
    for (final entry in entries) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            _mm(_labelWidthMm),
            _mm(_labelHeightMm),
            marginAll: 0,
          ),
          build: (context) => pw.Stack(
            children: [
              // Explicit white under everything (the shifted background
              // leaves a transparent sliver at the left edge otherwise).
              pw.Positioned.fill(child: pw.Container(color: PdfColors.white)),
              ..._label(bg, font, entry),
            ],
          ),
        ),
      );
    }
    return doc.save();
  }

  // ---- Windows raster path ------------------------------------------------

  /// The PDF that actually goes to the printer.
  ///
  /// On macOS that's the vector PDF as-is: the OS rasterizes it itself
  /// before the driver sees anything. On Windows the printing plugin
  /// instead draws the PDF's vectors/text/images straight into the printer
  /// driver's GDI device context (PDFium's FPDF_RenderPage-to-HDC path) —
  /// and thermal label drivers like the Godex one implement only a small
  /// slice of GDI, silently dropping the rest: the job spools and labels
  /// feed, but they come out BLANK. So on Windows we do the OS's job
  /// ourselves: rasterize every page at the printer's native dpi and
  /// submit an image-only PDF — the driver then only has to blit one
  /// opaque bitmap, which every driver supports.
  static Future<Uint8List> _printablePdf(
    List<GatePassLabelEntry> entries,
  ) async {
    final vector = await _buildPdf(entries);
    if (!Platform.isWindows) {
      return vector;
    }
    final raster = await rasterizedLabelPdf(
      Printing.raster(vector, dpi: _printerDpi),
    );
    if (raster == null) {
      // Rasterization produced nothing — send the vector PDF rather than
      // no job at all (worst case it reproduces the blank print).
      debugPrint(
        'GatePassLabelPrinter: raster produced 0 pages, '
        'falling back to vector PDF',
      );
      return vector;
    }
    return raster;
  }

  /// Re-wraps rasterized pages into an image-only PDF (one full-bleed
  /// image per label page). Returns null when [pages] yields nothing.
  @visibleForTesting
  static Future<Uint8List?> rasterizedLabelPdf(
    Stream<PdfRasterBase> pages,
  ) async {
    final doc = pw.Document();
    var pageCount = 0;
    await for (final page in pages) {
      pageCount++;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            _mm(_labelWidthMm),
            _mm(_labelHeightMm),
            marginAll: 0,
          ),
          build: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(_OpaqueRasterImage(page), fit: pw.BoxFit.fill),
          ),
        ),
      );
    }
    if (pageCount == 0) {
      return null;
    }
    return doc.save();
  }

  static List<pw.Widget> _label(
    pw.MemoryImage bg,
    pw.Font font,
    GatePassLabelEntry entry,
  ) {
    // QR: centered in the emptied frame with a quiet zone. The frame is
    // square; use the smaller side so a re-measured asset can't stretch it.
    final qrLeft = _qrLeftMm + _qrQuietZoneMm;
    final qrTop = _qrTopMm + _qrQuietZoneMm;
    final qrSize =
        math.min(_qrRightMm - _qrLeftMm, _qrBottomMm - _qrTopMm) -
        2 * _qrQuietZoneMm;

    // Name: vertical (top-to-bottom) in the strip, auto-shrunk to fit.
    final stripLengthPt = _mm((_nameBottomMm - _nameTopMm) * _labelScale);
    final nameLength = entry.name.isEmpty ? 1 : entry.name.length;
    final fontPt = math.min(
      _maxNameFontPt,
      stripLengthPt / (nameLength * _avgGlyphAdvance * _labelScale),
    );
    final nameCenterXMm = (_nameLeftMm + _nameRightMm) / 2;
    final nameCenterYMm = (_nameTopMm + _nameBottomMm) / 2;

    return [
      // Background, full-bleed 1:1 (see class docs), nudged by the same
      // registration offset as the overlays. The 3mm sliding off the right
      // edge is the asset's own baked white margin — nothing is lost.
      pw.Positioned(
        left: _mm(_regOffsetXMm),
        top: 0,
        child: pw.SizedBox(
          width: _mm(_labelWidthMm),
          height: _mm(_labelHeightMm),
          child: pw.Image(bg, fit: pw.BoxFit.fill),
        ),
      ),
      pw.Positioned(
        left: _mm(_pageX(qrLeft)),
        top: _mm(_pageY(qrTop)),
        child: pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: entry.qrData,
          width: _mm(qrSize * _labelScale),
          height: _mm(qrSize * _labelScale),
          drawText: false,
        ),
      ),
      // Parent style: a filled dark bar over the whole name strip; the
      // 1-bit thermal driver prints pure black + knocked-out white text
      // crisply (anything gray would dither — see the class docs).
      if (entry.invertName)
        pw.Positioned(
          left: _mm(_pageX(_nameLeftMm)),
          top: _mm(_pageY(_nameTopMm)),
          child: pw.Container(
            width: _mm((_nameRightMm - _nameLeftMm) * _labelScale),
            height: _mm((_nameBottomMm - _nameTopMm) * _labelScale),
            decoration: pw.BoxDecoration(
              color: PdfColors.black,
              borderRadius: pw.BorderRadius.circular(_mm(0.8)),
            ),
          ),
        ),
      // rotateBox re-lays-out the rotated child's bounding box, so
      // (left, top) anchors the top-left of the ROTATED box: pre-rotation
      // the text box is (textWidth × fontSize), post-rotation it becomes
      // (fontSize × textWidth) — offsetting by half of each centers it.
      pw.Positioned(
        left: _mm(_pageX(nameCenterXMm)) - (fontPt * _labelScale) / 2,
        top:
            _mm(_pageY(nameCenterYMm)) -
            (entry.name.length * fontPt * _labelScale * _avgGlyphAdvance) / 2,
        child: pw.Transform.rotateBox(
          angle: -math.pi / 2, // bottom-to-top read, matching the art
          child: pw.Text(
            entry.name,
            style: pw.TextStyle(
              font: font,
              fontSize: fontPt * _labelScale,
              fontWeight: pw.FontWeight.bold,
              color: entry.invertName ? PdfColors.white : PdfColors.black,
            ),
          ),
        ),
      ),
    ];
  }
}

/// Embeds a rasterized page as a plain OPAQUE /DeviceRGB image.
///
/// The stock providers (MemoryImage/RawImage) always attach the alpha
/// channel as a /SMask soft mask — and GDI paints soft-masked images with
/// AlphaBlend, one of the calls flaky label drivers drop. The raster is
/// fully opaque anyway (the page paints solid white first), so the alpha
/// channel is dead weight: strip it and embed bare RGB.
class _OpaqueRasterImage extends pw.ImageProvider {
  _OpaqueRasterImage(this._page)
    : super(_page.width, _page.height, PdfImageOrientation.topLeft, null);

  final PdfRasterBase _page;

  @override
  PdfImage buildImage(pw.Context context, {int? width, int? height}) {
    final pixelCount = _page.width * _page.height;
    final rgba = _page.pixels;
    final rgb = Uint8List(pixelCount * 3);
    for (var i = 0; i < pixelCount; i++) {
      rgb[i * 3] = rgba[i * 4];
      rgb[i * 3 + 1] = rgba[i * 4 + 1];
      rgb[i * 3 + 2] = rgba[i * 4 + 2];
    }
    return PdfImage(
      context.document,
      image: rgb,
      width: _page.width,
      height: _page.height,
      alpha: false,
    );
  }
}
