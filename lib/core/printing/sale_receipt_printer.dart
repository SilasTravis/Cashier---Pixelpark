import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/pos_sale/domain/sale_receipt.dart';
import '../utils/receipt_id.dart';
import 'receipt_art.dart';

class SaleReceiptPrinter {
  static const double _paperWidthMm = 79;
  static const double _leftPaddingMm = 3;
  static const double _rightPaddingMm = 13;
  static const double _topPaddingMm = 8;
  static const double _bottomPaddingMm = 10;
  static const double _contentWidthMm = 63;

  /// The cashback claim QR's printed side, in mm, and the app-download QR
  /// below it. Both carry a white quiet zone; the receipt paper is the
  /// quiet zone, nothing else may intrude. Verified decodable from a
  /// 203 dpi monochrome render of the receipt.
  static const double _claimQrMm = 27;
  static const double _downloadQrMm = 17;
  static const double _quietZoneMm = 2.5;

  /// Where the "Ilova yo'qmi?" QR sends a parent without the app.
  static const appDownloadUrl = 'https://pixelpark.uz/s/cashdow';

  static bool hasPrintableProducts(SaleReceipt receipt) =>
      receipt.items.isNotEmpty || receipt.cashback != null;

  /// Printed under the header of a receipt rung up offline, so whoever reads
  /// the paper later knows why it isn't in the server history yet.
  static String? offlineNotice(SaleReceipt receipt) =>
      receipt.isOffline ? 'OFFLINE - internet qaytganda sinxronlanadi' : null;

  /// The till's receipt printer: the one picked in Settings, else the first
  /// SLK thermal printer. Shared with the shift close-out check.
  static Future<Printer?> findReceiptPrinter(
    String? preferredPrinterName,
  ) async {
    final printers = await Printing.listPrinters();
    return preferredPrinterName == null
        ? printers
              .where((printer) => printer.name.toLowerCase().contains('slk-'))
              .firstOrNull
        : printers
              .where((printer) => printer.name == preferredPrinterName)
              .firstOrNull;
  }

  static Future<bool> printDirect(
    SaleReceipt receipt, {
    required String branchName,
    required String cashierName,
    String? preferredPrinterName,
  }) async {
    if (!hasPrintableProducts(receipt)) return true;
    final target = await findReceiptPrinter(preferredPrinterName);
    if (target == null) {
      debugPrint('SaleReceiptPrinter: SLK receipt printer not found');
      return false;
    }
    final rendered = await render(
      receipt,
      branchName: branchName,
      cashierName: cashierName,
    );
    return Printing.directPrintPdf(
      printer: target,
      name: 'sale-${formatReceiptId(receipt.id)}',
      format: _paperFormat(rendered.heightMm),
      usePrinterSettings: true,
      dynamicLayout: false,
      onLayout: (_) async => rendered.bytes,
    );
  }

  static Future<bool> print(
    SaleReceipt receipt, {
    required String branchName,
    required String cashierName,
  }) async {
    final rendered = await render(
      receipt,
      branchName: branchName,
      cashierName: cashierName,
    );
    return Printing.layoutPdf(
      name: 'sale-${formatReceiptId(receipt.id)}',
      format: _paperFormat(rendered.heightMm),
      onLayout: (_) async => rendered.bytes,
    );
  }

  static PdfPageFormat _paperFormat(double heightMm) => PdfPageFormat(
    _paperWidthMm * PdfPageFormat.mm,
    heightMm * PdfPageFormat.mm,
    marginAll: 0,
  );

  static Future<Uint8List> buildPdf(
    SaleReceipt receipt, {
    required String branchName,
    required String cashierName,
  }) async => (await render(
    receipt,
    branchName: branchName,
    cashierName: cashierName,
  )).bytes;

  /// Lays the receipt out on an endless roll and returns the PDF together
  /// with the height it actually took — the paper is cut to exactly that,
  /// so no estimate can clip the QR or leave a blank tail.
  @visibleForTesting
  static Future<({Uint8List bytes, double heightMm})> render(
    SaleReceipt receipt, {
    required String branchName,
    required String cashierName,
  }) async {
    final art = await ReceiptArt.load();
    final items = receipt.items;
    final grossOfPrinted = items.fold<int>(
      0,
      (sum, item) => sum + item.lineTotalUzs,
    );
    // The discount is sale-level, not per line — clamp defensively so the
    // printed total never goes negative.
    final discountUzs = receipt.discountUzs.clamp(0, grossOfPrinted);
    final netOfPrinted = grossOfPrinted - discountUzs;
    final payment = _paymentForPrintedProducts(receipt, netOfPrinted);
    final ui = _Ui(art);

    final page = pw.Page(
      pageFormat: const PdfPageFormat(
        _paperWidthMm * PdfPageFormat.mm,
        double.infinity,
        marginLeft: _leftPaddingMm * PdfPageFormat.mm,
        marginRight: _rightPaddingMm * PdfPageFormat.mm,
        marginTop: _topPaddingMm * PdfPageFormat.mm,
        marginBottom: _bottomPaddingMm * PdfPageFormat.mm,
      ),
      build: (_) => pw.SizedBox(
        width: _contentWidthMm * PdfPageFormat.mm,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            ui.header(branchName),
            if (offlineNotice(receipt) case final notice?) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                notice,
                textAlign: pw.TextAlign.center,
                style: ui.text(art.bold, 9),
              ),
            ],
            ui.wavy(),
            ui.row('Chek', formatReceiptId(receipt.id), size: 8.5),
            ui.row(
              'Sana',
              DateFormat(
                'dd.MM.yyyy HH:mm',
              ).format(receipt.createdAt.toLocal()),
              size: 8.5,
            ),
            if (cashierName.isNotEmpty)
              ui.row('Kassir', cashierName, size: 8.5),
            ui.dotted(),
            for (final item in items) ...[
              pw.Text(item.nameSnapshot, style: ui.text(art.semiBold, 9.5)),
              ui.row(
                '${item.qty} x ${_money(item.priceSnapshotUzs)}',
                _money(item.lineTotalUzs),
              ),
              pw.SizedBox(height: 2.5),
            ],
            ui.wavy(),
            if (discountUzs > 0) ...[
              ui.row(
                'Chegirma'
                    '${receipt.discount != null ? ' (${receipt.discount!.name})' : ''}',
                '-${_money(discountUzs)}',
              ),
              pw.SizedBox(height: 3),
            ],
            ui.total(_money(netOfPrinted)),
            pw.SizedBox(height: 2),
            if (payment.cashUzs > 0) ui.row('Naqd', _money(payment.cashUzs)),
            if (payment.cardUzs > 0) ui.row('Karta', _money(payment.cardUzs)),
            if (payment.balanceUzs > 0)
              ui.row('Balans', _money(payment.balanceUzs)),
            ui.thanks(),
            if (receipt.cashback case final cashback?) ui.cashback(cashback),
            ui.footer(),
          ],
        ),
      ),
    );
    final document = pw.Document()..addPage(page);
    final bytes = await document.save();
    return (bytes: bytes, heightMm: page.pageFormat.height / PdfPageFormat.mm);
  }

  /// "26.10.2026 gacha" — the last day the parent can claim, local time.
  static String cashbackExpiryText(SaleCashback cashback) =>
      '${DateFormat('dd.MM.yyyy').format(cashback.expiresAt.toLocal())} gacha';

  static String _money(int value) {
    final digits = value.toString();
    return '${digits.replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (_) => ' ')} so\'m';
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
}

/// The receipt's building blocks, bound to the loaded fonts.
class _Ui {
  _Ui(this.art);

  final ReceiptArt art;

  static const _mm = PdfPageFormat.mm;

  pw.TextStyle text(pw.Font font, double size) =>
      pw.TextStyle(font: font, fontSize: size);

  pw.Widget row(String label, String value, {pw.Font? font, double size = 9}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(label, style: text(font ?? art.regular, size)),
            ),
            pw.SizedBox(width: 8),
            // At most two thirds of the line, so a long cashier name wraps
            // instead of running off the paper; the label takes the rest.
            pw.ConstrainedBox(
              constraints: const pw.BoxConstraints(maxWidth: 42 * _mm),
              child: pw.Text(
                value,
                textAlign: pw.TextAlign.right,
                style: text(font ?? art.regular, size),
              ),
            ),
          ],
        ),
      );

  pw.Widget wavy() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.SvgImage(
      svg: ReceiptArt.wavy,
      width: SaleReceiptPrinter._contentWidthMm * _mm,
      height: 2 * _mm,
      fit: pw.BoxFit.fill,
    ),
  );

  pw.Widget dotted() => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Divider(borderStyle: pw.BorderStyle.dotted, thickness: 1.2),
  );

  pw.Widget header(String branchName) => pw.Column(
    children: [
      pw.SvgImage(
        svg: ReceiptArt.garland,
        width: SaleReceiptPrinter._contentWidthMm * _mm,
        height: 7 * _mm,
      ),
      pw.SizedBox(height: 3),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          ReceiptArt.svg(ReceiptArt.confettiLeft, 9, 6),
          pw.SizedBox(width: 3),
          pw.Text(
            'PIXEL PARK',
            style: text(art.display, 21).copyWith(letterSpacing: 1.5),
          ),
          pw.SizedBox(width: 3),
          ReceiptArt.svg(ReceiptArt.confettiRight, 9, 6),
        ],
      ),
      if (branchName.isNotEmpty)
        pw.Text(
          branchName,
          textAlign: pw.TextAlign.center,
          style: text(art.semiBold, 8.5),
        ),
      pw.SizedBox(height: 1.5),
      pw.Text(
        "o'yin  *  kulgu  *  do'stlar",
        style: text(art.bold, 7.5).copyWith(letterSpacing: 1),
      ),
    ],
  );

  pw.Widget total(String amount) => pw.Stack(
    overflow: pw.Overflow.visible,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 1.6),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: row('JAMI', amount, font: art.bold, size: 13),
      ),
      pw.Positioned(
        right: -4,
        top: -5,
        child: ReceiptArt.svg(ReceiptArt.sparkle, 3.4, 3.4),
      ),
      pw.Positioned(
        left: -4,
        bottom: -4,
        child: ReceiptArt.svg(ReceiptArt.sparkle, 2.4, 2.4),
      ),
    ],
  );

  pw.Widget thanks() => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 6),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Image(art.bear, width: 15 * _mm),
        pw.SizedBox(width: 4),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'RAHMAT!',
              style: text(art.display, 19).copyWith(letterSpacing: 1.5),
            ),
            pw.Text("Yana o'ynagani keling!", style: text(art.bold, 8)),
            pw.SizedBox(height: 2),
          ],
        ),
        pw.SizedBox(width: 4),
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: ReceiptArt.svg(ReceiptArt.balloon, 4.5, 8),
        ),
      ],
    ),
  );

  pw.Widget _qr(String data, double sizeMm) => pw.Padding(
    padding: const pw.EdgeInsets.all(SaleReceiptPrinter._quietZoneMm * _mm),
    child: pw.BarcodeWidget(
      barcode: pw.Barcode.qrCode(),
      data: data,
      width: sizeMm * _mm,
      height: sizeMm * _mm,
      drawText: false,
    ),
  );

  pw.Widget _starRule() => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.8),
        ),
        pw.SizedBox(width: 4),
        ReceiptArt.svg(ReceiptArt.star, 2.6, 2.6),
        pw.SizedBox(width: 2),
        ReceiptArt.svg(ReceiptArt.starOutline, 3.4, 3.4),
        pw.SizedBox(width: 2),
        ReceiptArt.svg(ReceiptArt.star, 2.6, 2.6),
        pw.SizedBox(width: 4),
        pw.Expanded(
          child: pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.8),
        ),
      ],
    ),
  );

  /// Claim QR + amount, then the app-download QR for parents who don't
  /// have the app yet.
  pw.Widget cashback(SaleCashback cashback) => pw.Column(
    children: [
      _starRule(),
      pw.Row(
        children: [
          _qr(cashback.qrPayload, SaleReceiptPrinter._claimQrMm),
          pw.SizedBox(width: 1),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    ReceiptArt.svg(ReceiptArt.coin, 4.2, 4.2),
                    pw.SizedBox(width: 2),
                    pw.Flexible(
                      child: pw.Text(
                        SaleReceiptPrinter._money(cashback.amountUzs),
                        style: text(art.display, 14.5),
                      ),
                    ),
                  ],
                ),
                pw.Text('sizga qaytadi!', style: text(art.display, 11)),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Pixel Park ilovasida shu QR ni skanerlang',
                  style: text(art.semiBold, 8),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  SaleReceiptPrinter.cashbackExpiryText(cashback),
                  style: text(art.bold, 8),
                ),
                pw.SizedBox(height: 1),
                ReceiptArt.svg(ReceiptArt.arrow, 11, 5.5),
              ],
            ),
          ),
        ],
      ),
      wavy(),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          _qr(
            SaleReceiptPrinter.appDownloadUrl,
            SaleReceiptPrinter._downloadQrMm,
          ),
          pw.SizedBox(width: 2),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Ilova yo'qmi?", style: text(art.display, 11)),
              pw.Text(
                'Kamerangiz bilan skanerlab',
                style: text(art.semiBold, 8),
              ),
              pw.Text('yuklab oling', style: text(art.semiBold, 8)),
              pw.SizedBox(height: 1.5),
              pw.Text('pixelpark.uz/s/cashdow', style: text(art.regular, 7.5)),
            ],
          ),
        ],
      ),
    ],
  );

  pw.Widget footer() => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        ReceiptArt.svg(ReceiptArt.confettiLeft, 7, 4.7),
        pw.SizedBox(width: 4),
        ReceiptArt.svg(ReceiptArt.smile, 4, 4),
        pw.SizedBox(width: 3),
        pw.Text("Ko'rishguncha!", style: text(art.display, 10)),
        pw.SizedBox(width: 4),
        ReceiptArt.svg(ReceiptArt.confettiRight, 7, 4.7),
      ],
    ),
  );
}
