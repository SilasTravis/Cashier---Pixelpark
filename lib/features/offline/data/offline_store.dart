import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../../pos_sale/domain/discount.dart';
import '../../products/domain/product.dart';
import '../../shift/domain/shift.dart';
import '../domain/offline_sale.dart';
import '../domain/offline_shift.dart';

/// Everything offline mode must keep across restarts, in its OWN Hive box.
/// `LocalSource.clearSession` (logout, expired refresh token) never touches
/// this box, so collected money can't vanish with a session.
///
/// Values are stored as JSON strings: nested Hive maps come back as
/// `Map<dynamic, dynamic>`, and a string round trip keeps every model's
/// `fromJson` honest.
class OfflineStore extends ChangeNotifier {
  OfflineStore(this._box);

  static const boxName = 'cashier_offline_box';

  static const _modeKey = 'offlineMode';
  static const _salePrefix = 'sale:';
  static const _offlineShiftPrefix = 'offlineShift:';
  static const _cachedShiftPrefix = 'cachedShift:';
  static const _productsPrefix = 'products:';
  static const _discountsKey = 'discounts';

  final Box<dynamic> _box;

  bool get isOfflineMode => _box.get(_modeKey, defaultValue: false) as bool;

  Future<void> setOfflineMode(bool value) => _write(_modeKey, value);

  List<OfflineSale> sales({String? cashierId}) {
    final all = <OfflineSale>[];
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith(_salePrefix)) continue;
      // One corrupt row must not take the whole queue (sync, counts, the
      // Unsynced page) down with it. It stays in the box for support.
      try {
        all.add(OfflineSale.fromJson(_decode(_box.get(key))));
      } catch (error) {
        debugPrint('OfflineStore: skipping unreadable sale row $key: $error');
      }
    }
    all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return cashierId == null
        ? all
        : all.where((sale) => sale.cashierId == cashierId).toList();
  }

  Future<void> putSale(OfflineSale sale) =>
      _write('$_salePrefix${sale.offlineRequestId}', jsonEncode(sale.toJson()));

  Future<void> removeSales(Iterable<String> ids) async {
    await _box.deleteAll([for (final id in ids) '$_salePrefix$id']);
    notifyListeners();
  }

  OfflineShift? offlineShift(String cashierId) {
    final raw = _box.get('$_offlineShiftPrefix$cashierId');
    return raw == null ? null : OfflineShift.fromJson(_decode(raw));
  }

  Future<void> saveOfflineShift(OfflineShift shift) => _write(
    '$_offlineShiftPrefix${shift.cashierId}',
    jsonEncode(shift.toJson()),
  );

  Future<void> clearOfflineShift(String cashierId) =>
      _delete('$_offlineShiftPrefix$cashierId');

  Shift? cachedShift(String cashierId) {
    final raw = _box.get('$_cachedShiftPrefix$cashierId');
    return raw == null ? null : Shift.fromCacheJson(_decode(raw));
  }

  Future<void> cacheShift(String cashierId, Shift shift) =>
      _write('$_cachedShiftPrefix$cashierId', jsonEncode(shift.toCacheJson()));

  Future<void> clearCachedShift(String cashierId) =>
      _delete('$_cachedShiftPrefix$cashierId');

  List<Product>? cachedProducts(String branchId) {
    final raw = _box.get('$_productsPrefix$branchId');
    if (raw == null) return null;
    return [
      for (final json in jsonDecode(raw as String) as List)
        Product.fromJson(Map<String, dynamic>.from(json as Map)),
    ];
  }

  Future<void> cacheProducts(String branchId, List<Product> products) => _write(
    '$_productsPrefix$branchId',
    jsonEncode([for (final product in products) product.toJson()]),
  );

  List<Discount>? cachedDiscounts() {
    final raw = _box.get(_discountsKey);
    if (raw == null) return null;
    return [
      for (final json in jsonDecode(raw as String) as List)
        Discount.fromJson(Map<String, dynamic>.from(json as Map)),
    ];
  }

  Future<void> cacheDiscounts(List<Discount> discounts) => _write(
    _discountsKey,
    jsonEncode([for (final discount in discounts) discount.toJson()]),
  );

  Future<void> _write(String key, Object value) async {
    await _box.put(key, value);
    notifyListeners();
  }

  Future<void> _delete(String key) async {
    await _box.delete(key);
    notifyListeners();
  }

  static Map<String, dynamic> _decode(Object? raw) =>
      Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
}
