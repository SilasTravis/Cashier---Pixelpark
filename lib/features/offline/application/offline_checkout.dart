import 'package:uuid/uuid.dart';

import '../../../core/local_source/local_source.dart';
import '../../pos_sale/domain/cart_line.dart';
import '../../pos_sale/domain/discount.dart';
import '../data/offline_store.dart';
import '../domain/offline_sale.dart';

class NoShiftForOfflineSaleException implements Exception {}

class OfflinePaymentShortException implements Exception {}

/// Rings a sale up with no server: attaches it to the cached server shift
/// (or the one opened offline) and persists it BEFORE the receipt prints —
/// a crash after this point can lose a printout, never the sale.
class OfflineCheckout {
  OfflineCheckout(
    this._store,
    this._local, {
    String Function()? newId,
    DateTime Function()? clock,
  }) : _newId = newId ?? (() => const Uuid().v4()),
       _clock = clock ?? DateTime.now;

  final OfflineStore _store;
  final LocalSource _local;
  final String Function() _newId;
  final DateTime Function() _clock;

  Future<OfflineSale> record({
    required List<CartLine> lines,
    required Discount? discount,
    required int cashUzs,
    required int cardUzs,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError.value(lines, 'lines', 'cannot be empty');
    }

    final cashierId = _local.getCashierId();
    if (cashierId == null) throw NoShiftForOfflineSaleException();

    String? shiftId;
    String? shiftOfflineRequestId;
    final cached = _store.cachedShift(cashierId);
    final offline = _store.offlineShift(cashierId);
    if (cached != null && cached.isOpen) {
      shiftId = cached.id;
    } else if (offline != null) {
      shiftId = offline.serverShiftId;
      shiftOfflineRequestId = offline.isSynced
          ? null
          : offline.offlineRequestId;
    } else {
      throw NoShiftForOfflineSaleException();
    }

    final sale = OfflineSale(
      offlineRequestId: _newId(),
      cashierId: cashierId,
      createdAt: _clock(),
      shiftId: shiftId,
      shiftOfflineRequestId: shiftOfflineRequestId,
      lines: [
        for (final line in lines)
          OfflineSaleLine(
            productId: line.product.id,
            name: line.product.name,
            priceUzs: line.product.priceUzs,
            qty: line.qty,
          ),
      ],
      discount: discount,
      cashUzs: cashUzs,
      cardUzs: cardUzs,
    );
    if (cashUzs + cardUzs < sale.totalUzs) throw OfflinePaymentShortException();

    await _store.putSale(sale);
    return sale;
  }
}
