import 'dart:async';

import 'package:flutter/foundation.dart';

import '../local_source/local_source.dart';

typedef PrintParkingReceipt =
    Future<void> Function({
      required String branchName,
      required DateTime issuedAt,
      String? preferredPrinterName,
    });

class ParkingReceiptDispatcher {
  const ParkingReceiptDispatcher(
    this._local, {
    required PrintParkingReceipt printReceipt,
    this.onUnconfirmed,
  }) : _print = printReceipt;

  final LocalSource _local;
  final PrintParkingReceipt _print;
  final VoidCallback? onUnconfirmed;

  /// Captures the branch and printer before checkout can yield to a different
  /// session. Only the successful sale invokes the returned callback.
  void Function(DateTime)? captureForCheckout() {
    try {
      if (!_local.getPrintParkingReceipt()) return null;
      final branch = _local.getBranchName();
      if (branch == null || _local.getBranchId() == null) return null;
      final printer = _local.getReceiptPrinterName();
      return (issuedAt) => unawaited(_dispatch(branch, printer, issuedAt));
    } catch (error) {
      debugPrint('Parking receipt settings unavailable: $error');
      return null;
    }
  }

  Future<void> _dispatch(
    String branch,
    String? printer,
    DateTime issuedAt,
  ) async {
    try {
      await _print(
        branchName: branch,
        preferredPrinterName: printer,
        issuedAt: issuedAt,
      );
    } catch (error) {
      // A spooler can fail after accepting the job. Leave the sale settled
      // and avoid automatically submitting a second copy.
      debugPrint('Parking receipt print failed: $error');
      try {
        onUnconfirmed?.call();
      } catch (noticeError) {
        // The till may be losing its presentation surface during shutdown.
        debugPrint('Parking receipt notice unavailable: $noticeError');
      }
    }
  }
}
