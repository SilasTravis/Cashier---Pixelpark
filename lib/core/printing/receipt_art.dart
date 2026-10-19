import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fonts, mascot and the small black-only vector doodles of the sale
/// receipt. Everything is pure black on white: the SLK printers are 203 dpi
/// thermal, so greys dither into noise and thin strokes fade.
class ReceiptArt {
  ReceiptArt._(this.regular, this.semiBold, this.bold, this.display, this.bear);

  final pw.Font regular;
  final pw.Font semiBold;
  final pw.Font bold;

  /// Rounded "fun" headline font (Fredoka SemiBold).
  final pw.Font display;

  /// The waving Pixel Park bear, 1-bit, saved as opaque RGB so the PDF
  /// carries no soft mask (GDI drivers drop AlphaBlend'ed images).
  final pw.ImageProvider bear;

  static Future<ReceiptArt>? _cached;

  /// Loaded once per app run; a failed load is not cached so the next print
  /// retries.
  static Future<ReceiptArt> load() =>
      _cached ??= _load().catchError((Object error) {
        _cached = null;
        throw error;
      });

  static Future<ReceiptArt> _load() async {
    Future<pw.Font> font(String name) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$name.ttf'));
    final bear = await rootBundle.load('assets/images/receipt_bear.png');
    return ReceiptArt._(
      await font('Nunito-Regular'),
      await font('Nunito-SemiBold'),
      await font('Nunito-Bold'),
      await font('Fredoka-SemiBold'),
      pw.MemoryImage(bear.buffer.asUint8List()),
    );
  }

  static pw.Widget svg(String svg, double widthMm, double heightMm) =>
      pw.SvgImage(
        svg: svg,
        width: widthMm * PdfPageFormat.mm,
        height: heightMm * PdfPageFormat.mm,
      );

  static const _starPath =
      'M12 1.5l3.1 6.6 7.2.9-5.3 5 1.4 7.1L12 17.6 5.6 21.1 7 14l-5.3-5 7.2-.9z';

  static const star =
      '<svg viewBox="0 0 24 24"><path d="$_starPath" fill="#000"/></svg>';

  static const starOutline =
      '<svg viewBox="0 0 24 24"><path d="$_starPath" fill="none" '
      'stroke="#000" stroke-width="2"/></svg>';

  static const heart =
      '<svg viewBox="0 0 24 24"><path d="M12 21s-8-5.3-8-11a4.5 4.5 0 0 1 '
      '8-2.8A4.5 4.5 0 0 1 20 10c0 5.7-8 11-8 11z" fill="#000"/></svg>';

  static const sparkle =
      '<svg viewBox="0 0 24 24"><path d="M12 0 C13 8 16 11 24 12 C16 13 13 '
      '16 12 24 C11 16 8 13 0 12 C8 11 11 8 12 0z" fill="#000"/></svg>';

  static const balloon =
      '<svg viewBox="0 0 40 70"><ellipse cx="20" cy="20" rx="16" ry="19" '
      'fill="none" stroke="#000" stroke-width="3"/><path d="M11 12 q3 -6 9 '
      '-7" stroke="#000" stroke-width="2.5" fill="none"/><path d="M17 39 '
      'l3 4 3 -4z" fill="#000"/><path d="M20 43 q-6 8 0 14 q6 6 0 12" '
      'stroke="#000" stroke-width="2" fill="none"/></svg>';

  static const smile =
      '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="none" '
      'stroke="#000" stroke-width="2"/><circle cx="8.5" cy="9.5" r="1.5" '
      'fill="#000"/><circle cx="15.5" cy="9.5" r="1.5" fill="#000"/><path '
      'd="M7 14 q5 5 10 0" fill="none" stroke="#000" stroke-width="2" '
      'stroke-linecap="round"/></svg>';

  static const coin =
      '<svg viewBox="0 0 30 30"><circle cx="15" cy="15" r="12.5" '
      'fill="none" stroke="#000" stroke-width="2.4"/><circle cx="15" '
      'cy="15" r="8.5" fill="none" stroke="#000" stroke-width="1.2" '
      'stroke-dasharray="2 2"/><path d="M15 9 v12 M11.5 12 q3.5 -3 7 0 '
      'M11.5 18 q3.5 3 7 0" stroke="#000" stroke-width="2" fill="none" '
      'stroke-linecap="round"/></svg>';

  /// Dashed arrow pointing down-left, at the cashback QR.
  static const arrow =
      '<svg viewBox="0 0 60 30"><path d="M56 6 C40 2 22 6 10 20" '
      'fill="none" stroke="#000" stroke-width="2.4" stroke-linecap="round" '
      'stroke-dasharray="5 4"/><path d="M4 26 L8 13 L17 21z" '
      'fill="#000"/></svg>';

  /// Bunting across the top: alternating filled / outlined flags.
  static const garland =
      '<svg viewBox="0 0 240 28"><path d="M2 4 Q120 22 238 4" fill="none" '
      'stroke="#000" stroke-width="1.6"/>'
      '<path d="M18 7.6 L30 9.8 L22 22z" fill="#000"/>'
      '<path d="M44 11.4 L57 13 L49 26z" fill="none" stroke="#000" '
      'stroke-width="1.6"/>'
      '<path d="M71 14.2 L85 15.4 L77 27z" fill="#000"/>'
      '<path d="M100 15.6 L114 16 L107 27.5z" fill="none" stroke="#000" '
      'stroke-width="1.6"/>'
      '<path d="M126 16 L140 15.6 L133 27.5z" fill="#000"/>'
      '<path d="M155 15.4 L169 14.2 L163 27z" fill="none" stroke="#000" '
      'stroke-width="1.6"/>'
      '<path d="M183 13 L196 11.4 L191 26z" fill="#000"/>'
      '<path d="M210 9.8 L222 7.6 L218 22z" fill="none" stroke="#000" '
      'stroke-width="1.6"/></svg>';

  static const _confettiBody =
      '<path d="M4 10 q4 -6 8 0 t8 0" fill="none" stroke="#000" '
      'stroke-width="2.2" stroke-linecap="round"/>'
      '<circle cx="34" cy="8" r="2.6" fill="#000"/>'
      '<path d="M46 4 l6 3 -6 3z" fill="#000"/>'
      '<circle cx="10" cy="28" r="2.6" fill="none" stroke="#000" '
      'stroke-width="1.8"/>'
      '<path d="M24 22 l4 8 M20 28 l10 -2" stroke="#000" stroke-width="2" '
      'stroke-linecap="round"/>'
      '<path d="M40 30 q3 -5 6 0 t6 0" fill="none" stroke="#000" '
      'stroke-width="2" stroke-linecap="round"/>'
      '<rect x="50" y="18" width="4.5" height="4.5" '
      'transform="rotate(30 52 20)" fill="#000"/>';

  static const confettiLeft = '<svg viewBox="0 0 60 40">$_confettiBody</svg>';

  static const confettiRight =
      '<svg viewBox="0 0 60 40"><g transform="translate(60 0) scale(-1 1)">'
      '$_confettiBody</g></svg>';

  static const wavy =
      '<svg viewBox="0 0 240 8"><path d="M0 4 q5 -4 10 0 t10 0 t10 0 t10 0 '
      't10 0 t10 0 t10 0 t10 0 t10 0 t10 0 t10 0 t10 0 t10 0 t10 0 t10 0 '
      't10 0 t10 0 t10 0 t10 0 t10 0 t10 0 t10 0 t10 0 t10 0" fill="none" '
      'stroke="#000" stroke-width="1.3"/></svg>';
}
