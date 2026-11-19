import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

enum ThermalDocument { receipt, label, parking }

/// On Windows, printer discovery and GDI spool calls are synchronous on the
/// Flutter platform thread. A Dart timeout alone cannot unfreeze that thread.
/// Run the driver in a disposable headless process with no till/session state.
class DirectPrintJob {
  // USB driver calls share a spooler. Keep at most one process per paper
  // type alive, and expire work that could no longer reach this customer.
  static final _pending = <bool, Future<void>>{};
  static const _deadline = Duration(seconds: 20);

  static const workerFlag = '--cashier-print-job';

  static Future<bool> submit({
    required Uint8List bytes,
    required PdfPageFormat format,
    required String name,
    required String? printerName,
    ThermalDocument document = ThermalDocument.receipt,
  }) async {
    try {
      if (!Platform.isWindows) {
        return await _send(
          bytes,
          format,
          name,
          printerName,
          document,
        ).timeout(_deadline);
      }
      final label = document == ThermalDocument.label;
      final waiting = Stopwatch()..start();
      final done = Completer<void>();
      final previous = _pending[label];
      _pending[label] = done.future;
      try {
        if (previous != null) await previous;
        if (waiting.elapsed >= _deadline) return false;
        final payload = jsonEncode({
          'name': name,
          'printer': printerName,
          'document': document.name,
          'width': format.width,
          'height': format.height,
          'pdf': base64Encode(bytes),
        });
        final worker = await Process.start(Platform.resolvedExecutable, [
          workerFlag,
        ]);
        return await finishWorker(
          worker,
          payload,
          deadline: _deadline - waiting.elapsed,
        );
      } finally {
        done.complete();
        if (identical(_pending[label], done.future)) _pending.remove(label);
      }
    } catch (error) {
      debugPrint('Direct print job failed: $error');
      return false;
    }
  }

  @visibleForTesting
  static Future<bool> finishWorker(
    Process worker,
    String payload, {
    Duration deadline = const Duration(seconds: 20),
  }) async {
    // Drain pipes even when a driver writes verbose diagnostic output.
    final streams = Future.wait([
      worker.stdout.drain<void>(),
      worker.stderr.drain<void>(),
    ]);
    Future<bool> finish() async {
      worker.stdin.encoding = utf8;
      worker.stdin.write(payload);
      await worker.stdin.close();
      final code = await worker.exitCode;
      await streams;
      return code == 0;
    }

    try {
      return await finish().timeout(deadline);
    } catch (_) {
      worker.kill();
      rethrow;
    }
  }

  static Future<bool> runWorker() async {
    final job = jsonDecode(await stdin.transform(utf8.decoder).join()) as Map;
    return _send(
      base64Decode(job['pdf'] as String),
      PdfPageFormat(
        (job['width'] as num).toDouble(),
        (job['height'] as num).toDouble(),
        marginAll: 0,
      ),
      job['name'] as String,
      job['printer'] as String?,
      ThermalDocument.values.byName(job['document'] as String),
    );
  }

  /// PDFium rasterizes on Windows into a transparent bitmap: every blank
  /// pixel is RGBA (0,0,0,0). The native spooler reads RGB only, so an
  /// unpainted background printed as solid black. Composite onto paper white.
  @visibleForTesting
  static Uint8List flattenOnWhite(Uint8List rgba) {
    final out = Uint8List.fromList(rgba);
    for (var i = 0; i + 3 < out.length; i += 4) {
      final a = out[i + 3];
      if (a == 255) continue;
      final paper = 255 * (255 - a);
      out[i] = (out[i] * a + paper) ~/ 255;
      out[i + 1] = (out[i + 1] * a + paper) ~/ 255;
      out[i + 2] = (out[i + 2] * a + paper) ~/ 255;
      out[i + 3] = 255;
    }
    return out;
  }

  static Future<bool> _send(
    Uint8List bytes,
    PdfPageFormat format,
    String name,
    String? printerName,
    ThermalDocument document,
  ) async {
    final printers = await Printing.listPrinters();
    final label = document == ThermalDocument.label;
    final target = printers
        .where(
          (p) => printerName != null
              ? p.name == printerName
              : p.name.toLowerCase().contains(label ? 'godex' : 'slk-'),
        )
        .firstOrNull;
    if (target == null || !target.isAvailable) return false;

    if (document != ThermalDocument.receipt && Platform.isWindows) {
      // Godex requires opaque bitmaps. For parking slips, the same native
      // spooler also checks StartDoc/EndDoc before reporting success.
      final pages = <Map<String, Object>>[];
      await for (final page in Printing.raster(bytes, dpi: 203)) {
        pages.add({
          'width': page.width,
          'height': page.height,
          'pixels': flattenOnWhite(page.pixels),
        });
      }
      if (pages.isEmpty) return false;
      return await const MethodChannel(
            'cashier/native_label_printer',
          ).invokeMethod<bool>('printRgbaPages', {
            'printerName': target.name,
            if (!label) ...{
              'paperWidth': (format.width * 10 / PdfPageFormat.mm).round(),
              'paperLength': (format.height * 10 / PdfPageFormat.mm).round(),
            },
            'jobName': name,
            'pages': pages,
          }) ??
          false;
    }
    return Printing.directPrintPdf(
      printer: target,
      format: format,
      name: name,
      usePrinterSettings: true,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }
}
