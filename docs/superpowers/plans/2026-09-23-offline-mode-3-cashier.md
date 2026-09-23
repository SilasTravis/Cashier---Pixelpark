# Offline Mode — Plan 3 of 3: Cashier app (Flutter)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the internet drops, the cashier confirms offline mode and keeps selling from the product grid (including offline-only VIP/hourly plan items). Receipts print as usual and are queued locally. When the connection returns, a second confirmation switches back online and syncs the queue. Unsynced sales appear in history and on their own page, with a support code and Retry.

**Architecture:**
- **Detection.** A `ConnectivityMonitor` (a 15 s `/health` poll, plus reports from a Dio interceptor) feeds a global `AppModeCubit`. The cubit owns the mode (`online`/`offline`/`syncing`) and which confirmation modal is due. A `ModePromptHost` in the shell renders those modals.
- **Storage.** Everything offline lives in its own Hive box behind `OfflineStore`, which logout never clears.
- **Repositories.** The existing repositories gain an offline branch: products, discounts and shift come from cache, and an offline shift can be opened locally.
- **Selling.** `OfflineCheckout` persists a sale *before* its receipt prints.
- **Sync.** `OfflineSyncService` replays the queue to `POST /v1/pos/offline/sync` and applies the per-sale results.

**Tech Stack:** Flutter 3.4x desktop (macOS/Windows), flutter_bloc 9, get_it, dartz, hive_ce, dio 5 + dio_retry_plus, intl_utils (`dart run intl_utils:generate`), flutter_test + fake_async.

**Spec:** `docs/superpowers/specs/2026-09-23-offline-mode-design.md`. **Depends on:** Plan 1 (backend contract, reproduced in Task 5). This plan also applies the three planning-time revisions listed in Plan 1: `includeOffline=true` on the products fetch, a shift reference (`shiftId`/`shiftOfflineRequestId`) on every sale, and a `shifts` array.

## Global Constraints

- Branch `feat/offline-mode` (already created from `main` @ `c05c5bc`; the spec is committed there as `58b8d7b`). Merging to `main` **is a release** (GitHub Actions self-update). Don't merge until Plan 1 is on the prod backend.
- **Baseline:** `flutter test` → 183 tests, all passing. `flutter analyze` → 4 pre-existing `avoid_print` infos in `scratch_*.dart`, nothing else. Keep it that way.
- Tests use hand-written fakes (subclass `…Impl` with `Dio()`, like `test/topup_double_submit_test.dart`) and a temp-dir Hive box (like `test/pos_account_search_history_test.dart`). Don't add mocktail/bloc_test.
- Every user-visible string goes through `AppLocalization`. Add it to `lib/l10n/intl_uz.arb`, `intl_ru.arb` and `intl_en.arb`, then run `dart run intl_utils:generate`. Uzbek uses the `‘` apostrophe (e.g. `yo‘q`), matching the existing arb. Failure messages built inside repositories/blocs stay hardcoded Uzbek, as the code already does (`"Internet aloqasi yo'q"`).
- Offline payment is cash + card only. The Savdo screen already offers nothing else.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Don't push without the user's go-ahead.

## File map

| File | Responsibility |
|------|----------------|
| `lib/features/products/domain/product.dart` | `offlineOnly`, `fromJson`/`toJson` |
| `lib/features/pos_sale/domain/discount.dart` | `Discount.toJson` |
| `lib/features/pos_sale/domain/sale_receipt.dart` | `isOffline` |
| `lib/features/shift/domain/shift.dart` | `toCacheJson`/`fromCacheJson` |
| `lib/core/printing/sale_receipt_printer.dart` | The `OFFLINE` line |
| `lib/features/offline/domain/offline_sale.dart` | New: queued sale; receipt and sync-payload builders |
| `lib/features/offline/domain/offline_shift.dart` | New: a shift opened offline |
| `lib/features/offline/data/offline_store.dart` | New: Hive box `cashier_offline_box` (mode, queue, shift, caches) |
| `lib/core/connectivity/connectivity_monitor.dart` | New: health poll and events |
| `lib/core/network/connectivity_interceptor.dart` | New: reports connection-class Dio errors |
| `lib/core/network/api_client.dart` | 10 s connect timeout; install the interceptor |
| `lib/features/offline/data/offline_sync_remote_data_source.dart` | New: `POST /v1/pos/offline/sync` |
| `lib/features/offline/application/offline_sync_service.dart` | New: batch, send, apply results |
| `lib/core/offline/app_mode_cubit.dart` (+ `app_mode_state.dart` part) | New: mode, prompts, counts |
| `lib/features/products/data/*`, `lib/features/pos_sale/data/pos_sale_repository_impl.dart`, `lib/features/shift/data/shift_repository_impl.dart` | Cache + offline branches |
| `lib/features/offline/application/offline_checkout.dart` | New: record a sale locally |
| `lib/features/pos_sale/presentation/bloc/*` | Offline mode in the Savdo bloc |
| `lib/core/offline/widgets/mode_prompt_host.dart`, `offline_banner.dart` | New: the modals and the header strip |
| `lib/features/shell/...` | Sidebar gating, the Unsynced tab, banner, prompt host |
| `lib/features/offline/presentation/...` | New: Unsynced page, sale tile, history section |
| `lib/features/sales_history/presentation/pages/sales_history_page.dart` | Wrap it with the offline section |
| `lib/features/settings/presentation/pages/settings_page.dart` | Block logout while sales are queued |
| `lib/injector_container.dart`, `lib/app.dart`, `lib/main.dart` | Wiring |

---

### Task 1: Offline domain models and the OFFLINE receipt line

**Files:**
- Modify: `lib/features/products/domain/product.dart`, `lib/features/products/data/products_remote_data_source.dart` (use `Product.fromJson`)
- Modify: `lib/features/pos_sale/domain/discount.dart` (add `Discount.toJson`)
- Modify: `lib/features/pos_sale/domain/sale_receipt.dart` (add `isOffline`)
- Modify: `lib/features/shift/domain/shift.dart` (cache JSON)
- Modify: `lib/core/printing/sale_receipt_printer.dart`
- Create: `lib/features/offline/domain/offline_sale.dart`, `lib/features/offline/domain/offline_shift.dart`
- Test: `test/offline_models_test.dart` (new), `test/sale_receipt_printer_test.dart` (add a case)

**Interfaces:**
- Produces:
  - `Product({…, bool offlineOnly = false})`, `Product.fromJson(Map<String, dynamic>)`, `Map<String, dynamic> Product.toJson()`
  - `Map<String, dynamic> Discount.toJson()` (round-trips through `Discount.fromJson`)
  - `SaleReceipt({…, bool isOffline = false})`
  - `Map<String, dynamic> Shift.toCacheJson()`, `Shift.fromCacheJson(Map)` (totals come back as `ShiftTotals.zero`)
  - `static String? SaleReceiptPrinter.offlineNotice(SaleReceipt)`
  - `enum OfflineSaleStatus { pending, failed }`
  - `OfflineSaleLine({productId, name, priceUzs, qty})` with `lineTotalUzs`
  - `OfflineSale({offlineRequestId, cashierId, createdAt, shiftId?, shiftOfflineRequestId?, lines, discount?, cashUzs, cardUzs, status = pending, failureCode?, failureMessage?, attempts = 0, lastAttemptAt?})` with `grossUzs`, `discountUzs`, `totalUzs`, `supportCode`, `isFailed`, `markFailed({code, message, at})`, `toReceipt()`, `toJson()`, `fromJson`, `toSyncJson({String? serverShiftIdForOfflineShift})`
  - `OfflineShift({offlineRequestId, cashierId, openedAt, openingCashUzs?, serverShiftId?})` with `isSynced`, `toShift()` (id `offline:<offlineRequestId>`, status `open`), `withServerShiftId(String)`, `toJson()`, `fromJson`, `toSyncJson()`

- [ ] **Step 1: Write the failing tests**

Create `test/offline_models_test.dart`:

```dart
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:cashier_app/features/offline/domain/offline_shift.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:flutter_test/flutter_test.dart';

const _flyer = Discount(
  id: 'disc-1',
  name: 'Flayer',
  kind: DiscountKind.percent,
  value: 10,
);

OfflineSale _sale({
  String? shiftId = 'shift-1',
  String? shiftOfflineRequestId,
  Discount? discount = _flyer,
}) => OfflineSale(
  offlineRequestId: '35b4fb47-a84f-483f-b73c-44ff6a04be23',
  cashierId: 'cashier-1',
  createdAt: DateTime.utc(2026, 9, 23, 10, 15),
  shiftId: shiftId,
  shiftOfflineRequestId: shiftOfflineRequestId,
  lines: const [
    OfflineSaleLine(productId: 'vip', name: 'VIP', priceUzs: 75000, qty: 2),
  ],
  discount: discount,
  cashUzs: 135000,
  cardUzs: 0,
);

void main() {
  group('OfflineSale', () {
    test('totals follow the same discount formula as the server', () {
      final sale = _sale();
      expect(sale.grossUzs, 150000);
      expect(sale.discountUzs, 15000);
      expect(sale.totalUzs, 135000);
    });

    test('survives a JSON round trip, including a failure', () {
      final failed = _sale().markFailed(
        code: 'PRODUCT_NOT_FOUND',
        message: 'Mahsulot topilmadi',
        at: DateTime.utc(2026, 9, 23, 12),
      );
      expect(OfflineSale.fromJson(failed.toJson()), failed);
      expect(failed.isFailed, isTrue);
      expect(failed.attempts, 1);
    });

    test('its support code is the receipt number printed on paper', () {
      expect(_sale().supportCode, '35b4fb47');
    });

    test('builds a printable offline receipt', () {
      final receipt = _sale().toReceipt();
      expect(receipt.isOffline, isTrue);
      expect(receipt.id, '35b4fb47-a84f-483f-b73c-44ff6a04be23');
      expect(receipt.grossUzs, 150000);
      expect(receipt.discountUzs, 15000);
      expect(receipt.subtotalUzs, 135000);
      expect(receipt.discount?.name, 'Flayer');
      expect(receipt.items.single.lineTotalUzs, 150000);
    });

    test('sync payload names the server shift and the printed prices', () {
      expect(_sale().toSyncJson(), {
        'offlineRequestId': '35b4fb47-a84f-483f-b73c-44ff6a04be23',
        'shiftId': 'shift-1',
        'createdAt': '2026-09-23T10:15:00.000Z',
        'lines': [
          {'productId': 'vip', 'qty': 2, 'priceSnapshotUzs': 75000},
        ],
        'discount': {'id': 'disc-1', 'kind': 'percent', 'value': 10},
        'cashUzs': 135000,
        'cardUzs': 0,
      });
    });

    test('sync payload points at an offline shift until it has a server id', () {
      final sale = _sale(shiftId: null, shiftOfflineRequestId: 'off-shift');
      expect(sale.toSyncJson()['shiftOfflineRequestId'], 'off-shift');
      expect(sale.toSyncJson().containsKey('shiftId'), isFalse);

      final resolved = sale.toSyncJson(serverShiftIdForOfflineShift: 'srv-9');
      expect(resolved['shiftId'], 'srv-9');
      expect(resolved.containsKey('shiftOfflineRequestId'), isFalse);
    });

    test('sync payload omits the discount when none was applied', () {
      expect(_sale(discount: null).toSyncJson().containsKey('discount'), isFalse);
    });
  });

  group('OfflineShift', () {
    final shift = OfflineShift(
      offlineRequestId: 'off-shift',
      cashierId: 'cashier-1',
      openedAt: DateTime.utc(2026, 9, 23, 8),
      openingCashUzs: 20000,
    );

    test('shows in the shell as an open shift with a non-server id', () {
      final local = shift.toShift();
      expect(local.id, 'offline:off-shift');
      expect(local.isOpen, isTrue);
    });

    test('round-trips and remembers its server id once synced', () {
      final synced = shift.withServerShiftId('srv-9');
      expect(OfflineShift.fromJson(synced.toJson()), synced);
      expect(synced.isSynced, isTrue);
      expect(shift.isSynced, isFalse);
      expect(shift.toSyncJson(), {
        'offlineRequestId': 'off-shift',
        'openedAt': '2026-09-23T08:00:00.000Z',
        'openingCashUzs': 20000,
      });
    });
  });

  group('cache JSON of existing models', () {
    test('Product keeps offlineOnly, defaulting to false for older backends', () {
      const vip = Product(
        id: 'vip',
        name: 'VIP',
        priceUzs: 75000,
        category: 'Tariflar',
        icon: 'ph-crown',
        offlineOnly: true,
      );
      expect(Product.fromJson(vip.toJson()), vip);
      final legacy = Map<String, dynamic>.from(vip.toJson())..remove('offlineOnly');
      expect(Product.fromJson(legacy).offlineOnly, isFalse);
    });

    test('Discount round-trips', () {
      expect(Discount.fromJson(_flyer.toJson()), _flyer);
    });

    test('Shift round-trips its identity (totals are not cached)', () {
      final shift = Shift(
        id: 'shift-1',
        openedAt: DateTime.utc(2026, 9, 23, 8),
        closedAt: null,
        status: 'open',
        totals: ShiftTotals.zero,
      );
      expect(Shift.fromCacheJson(shift.toCacheJson()), shift);
    });
  });
}
```

Add to `test/sale_receipt_printer_test.dart` inside `main()`:

```dart
  test('an offline receipt carries the OFFLINE notice and still renders', () async {
    final offline = SaleReceipt(
      id: '35b4fb47-a84f-483f-b73c-44ff6a04be23',
      subtotalUzs: 75000,
      cashUzs: 75000,
      cardUzs: 0,
      createdAt: DateTime.utc(2026, 9, 23, 10),
      isOffline: true,
      items: const [
        SaleReceiptItem(
          productId: 'vip',
          nameSnapshot: 'VIP',
          priceSnapshotUzs: 75000,
          qty: 1,
          lineTotalUzs: 75000,
        ),
      ],
    );
    expect(SaleReceiptPrinter.offlineNotice(offline), contains('OFFLINE'));

    final online = SaleReceipt(
      id: offline.id,
      subtotalUzs: offline.subtotalUzs,
      cashUzs: offline.cashUzs,
      cardUzs: 0,
      createdAt: offline.createdAt,
      items: offline.items,
    );
    expect(SaleReceiptPrinter.offlineNotice(online), isNull);

    final bytes = await SaleReceiptPrinter.buildPdf(
      offline,
      branchName: 'Algoritm',
      cashierName: 'Zaira',
    );
    expect(latin1.decode(bytes), startsWith('%PDF'));
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/offline_models_test.dart test/sale_receipt_printer_test.dart`
Expected: compile errors, because `offline_sale.dart` doesn't exist and `isOffline` / `offlineOnly` aren't defined.

- [ ] **Step 3: Extend the existing models**

`product.dart`, full replacement:

```dart
import 'package:equatable/equatable.dart';

class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    required this.priceUzs,
    required this.category,
    required this.icon,
    this.offlineOnly = false,
  });

  final String id;
  final String name;
  final int priceUzs;
  final String category;

  /// Phosphor icon class name from the design system (e.g. `ph-ticket`).
  final String icon;

  /// Only sold in offline mode — e.g. the VIP / hourly plans, which online
  /// mint a QR and so can't be issued without the server. Hidden from the
  /// grid online; the backend also refuses them at online checkout.
  final bool offlineOnly;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    priceUzs: json['priceUzs'] as int,
    category: json['category'] as String,
    icon: json['icon'] as String,
    offlineOnly: json['offlineOnly'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'priceUzs': priceUzs,
    'category': category,
    'icon': icon,
    'offlineOnly': offlineOnly,
  };

  @override
  List<Object?> get props => [id, name, priceUzs, category, icon, offlineOnly];
}
```

`products_remote_data_source.dart`: replace `.map((json) => _productFromJson(json as Map<String, dynamic>))` with `.map((json) => Product.fromJson(json as Map<String, dynamic>))` and delete `_productFromJson`.

`discount.dart`, add to `Discount` after `fromJson`:

```dart
  /// Cache shape for offline mode — the inverse of [Discount.fromJson].
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'value': value,
    'scope': scope.key,
    'active': active,
  };
```

`sale_receipt.dart`: add the constructor param `this.isOffline = false,`, the field below, and `isOffline` at the end of `props`:

```dart
  /// Rung up while the terminal was offline — not on the server yet. The
  /// printer marks the paper; [id] is the offline request id.
  final bool isOffline;
```

`shift.dart`, add to `Shift`:

```dart
  /// Offline-mode cache of the shift's identity. Totals are deliberately not
  /// cached — they come back as zero and refresh from the server once online.
  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'openedAt': openedAt.toUtc().toIso8601String(),
    'closedAt': closedAt?.toUtc().toIso8601String(),
    'status': status,
  };

  factory Shift.fromCacheJson(Map<String, dynamic> json) => Shift(
    id: json['id'] as String,
    openedAt: DateTime.parse(json['openedAt'] as String),
    closedAt: json['closedAt'] == null
        ? null
        : DateTime.parse(json['closedAt'] as String),
    status: json['status'] as String,
    totals: ShiftTotals.zero,
  );
```

(The round-trip test compares UTC `DateTime`s. `DateTime.parse` of a `Z` string returns UTC, so equality holds.)

- [ ] **Step 4: The OFFLINE line on paper**

In `sale_receipt_printer.dart`, add the static method:

```dart
  /// Printed under the header of a receipt rung up offline, so whoever reads
  /// the paper later knows why it isn't in the server history yet. ASCII
  /// only — the receipt uses the built-in Helvetica.
  static String? offlineNotice(SaleReceipt receipt) =>
      receipt.isOffline ? 'OFFLINE - internet qaytganda sinxronlanadi' : null;
```

In `buildPdf`, directly after the `if (branchName.isNotEmpty) pw.Text(branchName, …)` element, add:

```dart
                if (offlineNotice(receipt) case final notice?) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    notice,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: bold, fontSize: 9),
                  ),
                ],
```

In `_receiptHeightMm`, before the `return`, add `if (receipt.isOffline) height += 6;`.

- [ ] **Step 5: Create the offline models**

Create `lib/features/offline/domain/offline_sale.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../../../core/utils/receipt_id.dart';
import '../../pos_sale/domain/discount.dart';
import '../../pos_sale/domain/sale_receipt.dart';

enum OfflineSaleStatus { pending, failed }

class OfflineSaleLine extends Equatable {
  const OfflineSaleLine({
    required this.productId,
    required this.name,
    required this.priceUzs,
    required this.qty,
  });

  final String productId;
  final String name;

  /// The unit price printed on the receipt — the server records exactly this.
  final int priceUzs;
  final int qty;

  int get lineTotalUzs => priceUzs * qty;

  factory OfflineSaleLine.fromJson(Map<String, dynamic> json) =>
      OfflineSaleLine(
        productId: json['productId'] as String,
        name: json['name'] as String,
        priceUzs: json['priceUzs'] as int,
        qty: json['qty'] as int,
      );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'priceUzs': priceUzs,
    'qty': qty,
  };

  @override
  List<Object?> get props => [productId, name, priceUzs, qty];
}

/// One sale rung up while the terminal was offline, waiting to reach
/// `POST /v1/pos/offline/sync`. [offlineRequestId] is minted when the sale is
/// rung up and is the server's idempotency key, so any retry is safe.
class OfflineSale extends Equatable {
  const OfflineSale({
    required this.offlineRequestId,
    required this.cashierId,
    required this.createdAt,
    this.shiftId,
    this.shiftOfflineRequestId,
    required this.lines,
    this.discount,
    required this.cashUzs,
    required this.cardUzs,
    this.status = OfflineSaleStatus.pending,
    this.failureCode,
    this.failureMessage,
    this.attempts = 0,
    this.lastAttemptAt,
  });

  final String offlineRequestId;
  final String cashierId;
  final DateTime createdAt;

  /// The server shift it was rung under, when the terminal had one cached…
  final String? shiftId;

  /// …or the shift this terminal opened offline (see `OfflineShift`).
  final String? shiftOfflineRequestId;
  final List<OfflineSaleLine> lines;

  /// The discount exactly as the terminal applied it. The server honours
  /// these kind/value numbers even if the discount was disabled since.
  final Discount? discount;
  final int cashUzs;
  final int cardUzs;
  final OfflineSaleStatus status;
  final String? failureCode;
  final String? failureMessage;
  final int attempts;
  final DateTime? lastAttemptAt;

  int get grossUzs => lines.fold(0, (sum, line) => sum + line.lineTotalUzs);
  int get discountUzs => discount?.appliedDiscountUzs(grossUzs) ?? 0;
  int get totalUzs => grossUzs - discountUzs;
  bool get isFailed => status == OfflineSaleStatus.failed;

  /// What the cashier reads to support — the same 8 characters printed as
  /// the receipt number.
  String get supportCode => formatReceiptId(offlineRequestId);

  OfflineSale markFailed({
    required String? code,
    required String message,
    required DateTime at,
  }) => OfflineSale(
    offlineRequestId: offlineRequestId,
    cashierId: cashierId,
    createdAt: createdAt,
    shiftId: shiftId,
    shiftOfflineRequestId: shiftOfflineRequestId,
    lines: lines,
    discount: discount,
    cashUzs: cashUzs,
    cardUzs: cardUzs,
    status: OfflineSaleStatus.failed,
    failureCode: code,
    failureMessage: message,
    attempts: attempts + 1,
    lastAttemptAt: at,
  );

  SaleReceipt toReceipt() => SaleReceipt(
    id: offlineRequestId,
    subtotalUzs: totalUzs,
    grossUzs: grossUzs,
    discountUzs: discountUzs,
    discount: discount == null
        ? null
        : DiscountSnapshot(
            id: discount!.id,
            name: discount!.name,
            kind: discount!.kind,
            value: discount!.value,
          ),
    cashUzs: cashUzs,
    cardUzs: cardUzs,
    createdAt: createdAt,
    isOffline: true,
    items: [
      for (final line in lines)
        SaleReceiptItem(
          productId: line.productId,
          nameSnapshot: line.name,
          priceSnapshotUzs: line.priceUzs,
          qty: line.qty,
          lineTotalUzs: line.lineTotalUzs,
        ),
    ],
  );

  /// One entry of the `sales` array in `POST /v1/pos/offline/sync`. Once the
  /// offline shift has a server id, pass it so a retry doesn't depend on
  /// the server resolving the offline id again.
  Map<String, dynamic> toSyncJson({String? serverShiftIdForOfflineShift}) => {
    'offlineRequestId': offlineRequestId,
    if (shiftId != null)
      'shiftId': shiftId
    else if (serverShiftIdForOfflineShift != null)
      'shiftId': serverShiftIdForOfflineShift
    else if (shiftOfflineRequestId != null)
      'shiftOfflineRequestId': shiftOfflineRequestId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lines': [
      for (final line in lines)
        {
          'productId': line.productId,
          'qty': line.qty,
          'priceSnapshotUzs': line.priceUzs,
        },
    ],
    if (discount != null)
      'discount': {
        'id': discount!.id,
        'kind': discount!.kind.name,
        'value': discount!.value,
      },
    'cashUzs': cashUzs,
    'cardUzs': cardUzs,
  };

  Map<String, dynamic> toJson() => {
    'offlineRequestId': offlineRequestId,
    'cashierId': cashierId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'shiftId': shiftId,
    'shiftOfflineRequestId': shiftOfflineRequestId,
    'lines': [for (final line in lines) line.toJson()],
    'discount': discount?.toJson(),
    'cashUzs': cashUzs,
    'cardUzs': cardUzs,
    'status': status.name,
    'failureCode': failureCode,
    'failureMessage': failureMessage,
    'attempts': attempts,
    'lastAttemptAt': lastAttemptAt?.toUtc().toIso8601String(),
  };

  factory OfflineSale.fromJson(Map<String, dynamic> json) => OfflineSale(
    offlineRequestId: json['offlineRequestId'] as String,
    cashierId: json['cashierId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    shiftId: json['shiftId'] as String?,
    shiftOfflineRequestId: json['shiftOfflineRequestId'] as String?,
    lines: [
      for (final line in json['lines'] as List)
        OfflineSaleLine.fromJson(Map<String, dynamic>.from(line as Map)),
    ],
    discount: json['discount'] == null
        ? null
        : Discount.fromJson(Map<String, dynamic>.from(json['discount'] as Map)),
    cashUzs: json['cashUzs'] as int,
    cardUzs: json['cardUzs'] as int,
    status: json['status'] == 'failed'
        ? OfflineSaleStatus.failed
        : OfflineSaleStatus.pending,
    failureCode: json['failureCode'] as String?,
    failureMessage: json['failureMessage'] as String?,
    attempts: json['attempts'] as int? ?? 0,
    lastAttemptAt: json['lastAttemptAt'] == null
        ? null
        : DateTime.parse(json['lastAttemptAt'] as String),
  );

  @override
  List<Object?> get props => [
    offlineRequestId,
    cashierId,
    createdAt,
    shiftId,
    shiftOfflineRequestId,
    lines,
    discount,
    cashUzs,
    cardUzs,
    status,
    failureCode,
    failureMessage,
    attempts,
    lastAttemptAt,
  ];
}
```

Create `lib/features/offline/domain/offline_shift.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../../shift/domain/shift.dart';

/// A shift the cashier opened while the terminal was offline. The server
/// creates it first on sync; [serverShiftId] is its real id afterwards.
class OfflineShift extends Equatable {
  const OfflineShift({
    required this.offlineRequestId,
    required this.cashierId,
    required this.openedAt,
    this.openingCashUzs,
    this.serverShiftId,
  });

  final String offlineRequestId;
  final String cashierId;
  final DateTime openedAt;
  final int? openingCashUzs;
  final String? serverShiftId;

  bool get isSynced => serverShiftId != null;

  /// How the shell shows it offline. The `offline:` prefix keeps it from
  /// ever being mistaken for a server id.
  Shift toShift() => Shift(
    id: 'offline:$offlineRequestId',
    openedAt: openedAt,
    closedAt: null,
    status: 'open',
    totals: ShiftTotals.zero,
  );

  OfflineShift withServerShiftId(String id) => OfflineShift(
    offlineRequestId: offlineRequestId,
    cashierId: cashierId,
    openedAt: openedAt,
    openingCashUzs: openingCashUzs,
    serverShiftId: id,
  );

  Map<String, dynamic> toSyncJson() => {
    'offlineRequestId': offlineRequestId,
    'openedAt': openedAt.toUtc().toIso8601String(),
    'openingCashUzs': ?openingCashUzs,
  };

  Map<String, dynamic> toJson() => {
    'offlineRequestId': offlineRequestId,
    'cashierId': cashierId,
    'openedAt': openedAt.toUtc().toIso8601String(),
    'openingCashUzs': openingCashUzs,
    'serverShiftId': serverShiftId,
  };

  factory OfflineShift.fromJson(Map<String, dynamic> json) => OfflineShift(
    offlineRequestId: json['offlineRequestId'] as String,
    cashierId: json['cashierId'] as String,
    openedAt: DateTime.parse(json['openedAt'] as String),
    openingCashUzs: json['openingCashUzs'] as int?,
    serverShiftId: json['serverShiftId'] as String?,
  );

  @override
  List<Object?> get props => [
    offlineRequestId,
    cashierId,
    openedAt,
    openingCashUzs,
    serverShiftId,
  ];
}
```

(`'openingCashUzs': ?openingCashUzs` is the null-aware map entry the codebase already uses, e.g. `'discountId': ?discountId`.)

- [ ] **Step 6: Run the tests**

Run: `flutter test test/offline_models_test.dart test/sale_receipt_printer_test.dart`
Expected: PASS.

Run: `flutter test && flutter analyze`
Expected: 183 + new tests pass; analyzer shows only the 4 baseline infos.

- [ ] **Step 7: Commit**

```bash
git add lib/features/offline/domain lib/features/products lib/features/pos_sale/domain lib/features/shift/domain lib/core/printing test/offline_models_test.dart test/sale_receipt_printer_test.dart
git commit -m "feat(offline): queued-sale and offline-shift models, OFFLINE receipt line

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `OfflineStore` (its own Hive box)

**Files:**
- Create: `lib/features/offline/data/offline_store.dart`
- Test: `test/offline_store_test.dart`

**Interfaces:**
- Consumes: `OfflineSale`, `OfflineShift`, `Product`, `Discount`, `Shift` (Task 1)
- Produces: `class OfflineStore extends ChangeNotifier` with:
  - `static const boxName = 'cashier_offline_box'`
  - `bool get isOfflineMode`, `Future<void> setOfflineMode(bool)`
  - `List<OfflineSale> sales({String? cashierId})` (oldest first), `Future<void> putSale(OfflineSale)`, `Future<void> removeSales(Iterable<String> ids)`
  - `OfflineShift? offlineShift(String cashierId)`, `Future<void> saveOfflineShift(OfflineShift)`, `Future<void> clearOfflineShift(String cashierId)`
  - `Shift? cachedShift(String cashierId)`, `Future<void> cacheShift(String cashierId, Shift)`, `Future<void> clearCachedShift(String cashierId)`
  - `List<Product>? cachedProducts(String branchId)`, `Future<void> cacheProducts(String branchId, List<Product>)`
  - `List<Discount>? cachedDiscounts()`, `Future<void> cacheDiscounts(List<Discount>)`
  - Every write calls `notifyListeners()`.

- [ ] **Step 1: Write the failing test**

Create `test/offline_store_test.dart`:

```dart
import 'dart:io';

import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:cashier_app/features/offline/domain/offline_shift.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

OfflineSale _sale(String id, {String cashierId = 'cashier-1', int minute = 0}) =>
    OfflineSale(
      offlineRequestId: id,
      cashierId: cashierId,
      createdAt: DateTime.utc(2026, 9, 23, 10, minute),
      shiftId: 'shift-1',
      lines: const [
        OfflineSaleLine(productId: 'vip', name: 'VIP', priceUzs: 75000, qty: 1),
      ],
      cashUzs: 75000,
      cardUzs: 0,
    );

void main() {
  late Directory temp;
  late Box<dynamic> box;
  late OfflineStore store;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_offline_store');
    Hive.init(temp.path);
    box = await Hive.openBox<dynamic>(OfflineStore.boxName);
    store = OfflineStore(box);
  });

  tearDown(() async {
    await box.close();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('offline mode persists and defaults to online', () async {
    expect(store.isOfflineMode, isFalse);
    await store.setOfflineMode(true);
    expect(OfflineStore(box).isOfflineMode, isTrue);
  });

  test('queues sales oldest first, per cashier, and removes synced ones', () async {
    await store.putSale(_sale('b', minute: 5));
    await store.putSale(_sale('a', minute: 1));
    await store.putSale(_sale('c', cashierId: 'cashier-2'));

    expect(store.sales(cashierId: 'cashier-1').map((s) => s.offlineRequestId), ['a', 'b']);
    expect(store.sales().length, 3);

    await store.removeSales(['a', 'c']);
    expect(store.sales().map((s) => s.offlineRequestId), ['b']);
  });

  test('putSale replaces the same sale, e.g. when it is marked failed', () async {
    await store.putSale(_sale('a'));
    await store.putSale(
      _sale('a').markFailed(code: 'X', message: 'bad', at: DateTime.utc(2026)),
    );
    expect(store.sales().single.isFailed, isTrue);
  });

  test('keeps the offline shift and the cached server shift per cashier', () async {
    final offline = OfflineShift(
      offlineRequestId: 'off-1',
      cashierId: 'cashier-1',
      openedAt: DateTime.utc(2026, 9, 23, 8),
    );
    await store.saveOfflineShift(offline);
    expect(store.offlineShift('cashier-1'), offline);
    expect(store.offlineShift('cashier-2'), isNull);
    await store.clearOfflineShift('cashier-1');
    expect(store.offlineShift('cashier-1'), isNull);

    final shift = Shift(
      id: 'shift-1',
      openedAt: DateTime.utc(2026, 9, 23, 8),
      closedAt: null,
      status: 'open',
      totals: ShiftTotals.zero,
    );
    await store.cacheShift('cashier-1', shift);
    expect(store.cachedShift('cashier-1'), shift);
    await store.clearCachedShift('cashier-1');
    expect(store.cachedShift('cashier-1'), isNull);
  });

  test('caches the catalog per branch and the discount list', () async {
    const vip = Product(
      id: 'vip',
      name: 'VIP',
      priceUzs: 75000,
      category: 'Tariflar',
      icon: 'ph-crown',
      offlineOnly: true,
    );
    const flyer = Discount(id: 'd', name: 'Flayer', kind: DiscountKind.percent, value: 10);

    expect(store.cachedProducts('branch-1'), isNull);
    await store.cacheProducts('branch-1', const [vip]);
    await store.cacheDiscounts(const [flyer]);

    expect(store.cachedProducts('branch-1'), const [vip]);
    expect(store.cachedProducts('branch-2'), isNull);
    expect(store.cachedDiscounts(), const [flyer]);
  });

  test('notifies listeners on every write', () async {
    var notified = 0;
    store.addListener(() => notified++);
    await store.putSale(_sale('a'));
    await store.removeSales(['a']);
    await store.setOfflineMode(true);
    expect(notified, 3);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/offline_store_test.dart`
Expected: compile error, because `offline_store.dart` doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/features/offline/data/offline_store.dart`:

```dart
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
    final all = [
      for (final key in _box.keys)
        if (key is String && key.startsWith(_salePrefix))
          OfflineSale.fromJson(_decode(_box.get(key))),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return cashierId == null
        ? all
        : all.where((sale) => sale.cashierId == cashierId).toList();
  }

  Future<void> putSale(OfflineSale sale) => _write(
    '$_salePrefix${sale.offlineRequestId}',
    jsonEncode(sale.toJson()),
  );

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

  Future<void> cacheShift(String cashierId, Shift shift) => _write(
    '$_cachedShiftPrefix$cashierId',
    jsonEncode(shift.toCacheJson()),
  );

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

  Future<void> cacheProducts(String branchId, List<Product> products) =>
      _write(
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
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/offline_store_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/offline/data/offline_store.dart test/offline_store_test.dart
git commit -m "feat(offline): persistent offline store in its own Hive box

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Connectivity detection (health poll and request failures)

**Files:**
- Create: `lib/core/connectivity/connectivity_monitor.dart`, `lib/core/network/connectivity_interceptor.dart`
- Modify: `lib/core/network/api_client.dart`
- Test: `test/connectivity_monitor_test.dart`

**Interfaces:**
- Produces:
  - `class ConnectivityEvent { final bool reachable; final bool fromUserRequest; }` (Equatable)
  - `typedef HealthProbe = Future<bool> Function();`
  - `ConnectivityMonitor({required HealthProbe probe, Duration interval = 15s, int failuresBeforeUnreachable = 2})` with `Stream<ConnectivityEvent> events`, `void start()`, `void stop()`, `Future<bool> checkNow()` (probes once and emits nothing), `void reportRequestFailure()`, `Future<void> dispose()`
  - `HealthProbe httpHealthProbe(String Function() baseUrl, {Dio? dio})`
  - `ConnectivityInterceptor(void Function() onConnectionFailure)` and `static bool ConnectivityInterceptor.isConnectionError(DioException)`
  - `Dio buildDio(LocalSource, TokenRefresher, {void Function()? onConnectionFailure})`

- [ ] **Step 1: Write the failing test**

Create `test/connectivity_monitor_test.dart`:

```dart
import 'dart:io';

import 'package:cashier_app/core/connectivity/connectivity_monitor.dart';
import 'package:cashier_app/core/network/connectivity_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectivityMonitor', () {
    test('needs two failed polls in a row before reporting an outage', () {
      fakeAsync((async) {
        final monitor = ConnectivityMonitor(probe: () async => false);
        final events = <ConnectivityEvent>[];
        monitor.events.listen(events.add);
        monitor.start();

        async.elapse(const Duration(seconds: 15));
        expect(events, isEmpty);

        async.elapse(const Duration(seconds: 15));
        expect(events, [const ConnectivityEvent(reachable: false)]);
        monitor.stop();
      });
    });

    test('a successful poll resets the failure count and reports reachable', () {
      fakeAsync((async) {
        final answers = [false, true, false];
        final monitor = ConnectivityMonitor(probe: () async => answers.removeAt(0));
        final events = <ConnectivityEvent>[];
        monitor.events.listen(events.add);
        monitor.start();

        async.elapse(const Duration(seconds: 45));
        expect(events, [const ConnectivityEvent(reachable: true)]);
        monitor.stop();
      });
    });

    test('a throwing probe counts as a failure', () {
      fakeAsync((async) {
        final monitor = ConnectivityMonitor(
          probe: () async => throw const SocketException('down'),
          failuresBeforeUnreachable: 1,
        );
        final events = <ConnectivityEvent>[];
        monitor.events.listen(events.add);
        monitor.start();

        async.elapse(const Duration(seconds: 15));
        expect(events.single.reachable, isFalse);
        monitor.stop();
      });
    });

    test('a failed real request is reported at once, flagged as user-initiated', () async {
      final monitor = ConnectivityMonitor(probe: () async => true);
      final next = monitor.events.first;
      monitor.reportRequestFailure();
      expect(await next, const ConnectivityEvent(reachable: false, fromUserRequest: true));
    });

    test('checkNow returns the probe answer without emitting', () async {
      final monitor = ConnectivityMonitor(probe: () async => true);
      final events = <ConnectivityEvent>[];
      monitor.events.listen(events.add);

      expect(await monitor.checkNow(), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
    });
  });

  group('ConnectivityInterceptor', () {
    DioException error(DioExceptionType type, {Object? cause}) => DioException(
      requestOptions: RequestOptions(path: '/v1/pos/sales'),
      type: type,
      error: cause,
    );

    test('classifies only network failures as connection errors', () {
      expect(ConnectivityInterceptor.isConnectionError(error(DioExceptionType.connectionError)), isTrue);
      expect(ConnectivityInterceptor.isConnectionError(error(DioExceptionType.connectionTimeout)), isTrue);
      expect(ConnectivityInterceptor.isConnectionError(error(DioExceptionType.receiveTimeout)), isTrue);
      expect(
        ConnectivityInterceptor.isConnectionError(
          error(DioExceptionType.unknown, cause: const SocketException('x')),
        ),
        isTrue,
      );
      expect(ConnectivityInterceptor.isConnectionError(error(DioExceptionType.badResponse)), isFalse);
      expect(ConnectivityInterceptor.isConnectionError(error(DioExceptionType.cancel)), isFalse);
    });

    test('reports a connection error and passes every error on', () {
      var reports = 0;
      var passedOn = 0;
      final interceptor = ConnectivityInterceptor(() => reports++);
      final handler = _Handler(() => passedOn++);

      interceptor.onError(error(DioExceptionType.connectionError), handler);
      interceptor.onError(error(DioExceptionType.badResponse), handler);

      expect(reports, 1);
      expect(passedOn, 2);
    });
  });
}

/// A real handler completes a completer nobody listens to, which the test
/// runner reports as an unhandled error — so only count the hand-offs.
class _Handler extends ErrorInterceptorHandler {
  _Handler(this._onNext);

  final void Function() _onNext;

  @override
  void next(DioException err) => _onNext();
}
```

(`_Handler` overrides `next` on purpose: a real `ErrorInterceptorHandler` completes an internal completer nobody awaits, which `flutter test` reports as an unhandled error.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/connectivity_monitor_test.dart`
Expected: compile error, because the files don't exist.

- [ ] **Step 3: Implement the monitor**

Create `lib/core/connectivity/connectivity_monitor.dart`:

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

/// One reachability observation. [fromUserRequest] marks a real request the
/// cashier just made that failed to connect (vs. the background poll): after
/// a declined offline prompt, only those re-offer offline mode.
class ConnectivityEvent extends Equatable {
  const ConnectivityEvent({required this.reachable, this.fromUserRequest = false});

  final bool reachable;
  final bool fromUserRequest;

  @override
  List<Object?> get props => [reachable, fromUserRequest];
}

typedef HealthProbe = Future<bool> Function();

/// Polls the backend's health endpoint and relays request failures. Two
/// consecutive failed polls count as an outage, so a single dropped packet
/// never interrupts the cashier.
class ConnectivityMonitor {
  ConnectivityMonitor({
    required HealthProbe probe,
    this.interval = const Duration(seconds: 15),
    this.failuresBeforeUnreachable = 2,
  }) : _probe = probe;

  final HealthProbe _probe;
  final Duration interval;
  final int failuresBeforeUnreachable;

  final _events = StreamController<ConnectivityEvent>.broadcast();
  Timer? _timer;
  int _failures = 0;
  bool _probing = false;

  Stream<ConnectivityEvent> get events => _events.stream;

  void start() => _timer ??= Timer.periodic(interval, (_) => _tick());

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// The "Onlaynni tekshirish" button: one probe, answered directly. The
  /// caller decides what to do, so nothing is emitted.
  Future<bool> checkNow() async {
    final reachable = await _safeProbe();
    if (reachable) _failures = 0;
    return reachable;
  }

  /// Called by `ConnectivityInterceptor` when a real request can't connect.
  void reportRequestFailure() {
    if (_events.isClosed) return;
    _events.add(const ConnectivityEvent(reachable: false, fromUserRequest: true));
  }

  Future<void> _tick() async {
    if (_probing) return;
    _probing = true;
    try {
      if (await _safeProbe()) {
        _failures = 0;
        _events.add(const ConnectivityEvent(reachable: true));
      } else if (++_failures >= failuresBeforeUnreachable) {
        _events.add(const ConnectivityEvent(reachable: false));
      }
    } finally {
      _probing = false;
    }
  }

  Future<bool> _safeProbe() async {
    try {
      return await _probe();
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    stop();
    await _events.close();
  }
}

/// `GET {baseUrl}/health` on a bare client — no auth, no retry interceptor,
/// 5 s timeouts — so an outage is noticed in seconds.
HealthProbe httpHealthProbe(String Function() baseUrl, {Dio? dio}) {
  final client =
      dio ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
  return () async {
    final response = await client.get<dynamic>(
      '${baseUrl()}/health',
      options: Options(validateStatus: (_) => true),
    );
    return response.statusCode == 200;
  };
}
```

- [ ] **Step 4: Implement the interceptor and install it**

Create `lib/core/network/connectivity_interceptor.dart`:

```dart
import 'dart:io';

import 'package:dio/dio.dart';

/// Tells the connectivity monitor when a real request failed to reach the
/// server, so the offline prompt can appear right after a failed action
/// instead of waiting for the next health poll. Never swallows the error.
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor(this._onConnectionFailure);

  final void Function() _onConnectionFailure;

  static bool isConnectionError(DioException e) => switch (e.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => true,
    DioExceptionType.unknown => e.error is SocketException,
    _ => false,
  };

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (isConnectionError(err)) _onConnectionFailure();
    handler.next(err);
  }
}
```

In `api_client.dart`:
- Change the signature to `Dio buildDio(LocalSource localSource, TokenRefresher tokenRefresher, {void Function()? onConnectionFailure})` and document the new parameter in the doc comment.
- Change `connectTimeout: const Duration(seconds: 30)` to `connectTimeout: const Duration(seconds: 10)`, with the comment `// 10 s, not 30: with two retries a dead network must be noticed in seconds.`
- After `dio.interceptors.add(RetryInterceptor(...));`, add:

```dart
  // Last, so it sees each attempt's final error after the retry logic.
  if (onConnectionFailure != null) {
    dio.interceptors.add(ConnectivityInterceptor(onConnectionFailure));
  }
```

and import `connectivity_interceptor.dart`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/connectivity_monitor_test.dart && flutter test && flutter analyze`
Expected: all pass; analyzer shows only the baseline infos.

- [ ] **Step 6: Commit**

```bash
git add lib/core/connectivity lib/core/network test/connectivity_monitor_test.dart
git commit -m "feat(offline): detect outages from a health poll and failed requests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `OfflineSyncService` and its remote

**Files:**
- Create: `lib/features/offline/data/offline_sync_remote_data_source.dart`, `lib/features/offline/application/offline_sync_service.dart`
- Test: `test/offline_sync_service_test.dart`

**Interfaces:**
- Consumes: `OfflineStore` (Task 2), `OfflineSale.toSyncJson`, `OfflineShift.toSyncJson`/`withServerShiftId`, `ConnectivityInterceptor.isConnectionError` (Task 3), `NoInternetException`, `ServerException`
- Produces:
  - `enum OfflineSyncStatus { created, duplicate, rejected }`
  - `OfflineSyncItemResult({offlineRequestId, status, serverId?, code?, message?})`
  - `OfflineSyncResult({shifts, sales})`
  - `abstract class OfflineSyncRemoteDataSource { Future<OfflineSyncResult> sync({required List<Map<String, dynamic>> shifts, required List<Map<String, dynamic>> sales}); }` and `OfflineSyncRemoteDataSourceImpl(Dio)`
  - `SyncReport({int syncedCount = 0, List<OfflineSale> failed = const [], String? transportError})` with `transportFailed` and `static const empty`
  - `OfflineSyncService(OfflineStore store, OfflineSyncRemoteDataSource remote, String? Function() currentCashierId, {DateTime Function()? clock})` with `static const batchSize = 200` and `Future<SyncReport> sync({Set<String>? onlyIds, bool includeFailed = false})`

The wire contract (from Plan 1, Task 5):

```jsonc
// POST /v1/pos/offline/sync → 200
{ "shifts": [{ "offlineRequestId", "status": "created|duplicate|rejected", "shiftId", "code", "message": {uz,ru,en} }],
  "sales":  [{ "offlineRequestId", "status": "...", "saleId", "code", "message": {uz,ru,en} }] }
```

- [ ] **Step 1: Write the failing test**

Create `test/offline_sync_service_test.dart`:

```dart
import 'dart:io';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/features/offline/application/offline_sync_service.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/data/offline_sync_remote_data_source.dart';
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:cashier_app/features/offline/domain/offline_shift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _FakeRemote implements OfflineSyncRemoteDataSource {
  final calls = <({List<Map<String, dynamic>> shifts, List<Map<String, dynamic>> sales})>[];
  Object? throwOnCall;
  OfflineSyncItemResult Function(Map<String, dynamic> sale) saleResult =
      (sale) => OfflineSyncItemResult(
        offlineRequestId: sale['offlineRequestId'] as String,
        status: OfflineSyncStatus.created,
        serverId: 'srv-${sale['offlineRequestId']}',
      );

  @override
  Future<OfflineSyncResult> sync({
    required List<Map<String, dynamic>> shifts,
    required List<Map<String, dynamic>> sales,
  }) async {
    calls.add((shifts: shifts, sales: sales));
    if (throwOnCall != null) throw throwOnCall!;
    return OfflineSyncResult(
      shifts: [
        for (final shift in shifts)
          OfflineSyncItemResult(
            offlineRequestId: shift['offlineRequestId'] as String,
            status: OfflineSyncStatus.created,
            serverId: 'srv-shift',
          ),
      ],
      sales: [for (final sale in sales) saleResult(sale)],
    );
  }
}

OfflineSale _sale(
  String id, {
  String cashierId = 'cashier-1',
  String? shiftId = 'shift-1',
  String? shiftOfflineRequestId,
  int minute = 0,
}) => OfflineSale(
  offlineRequestId: id,
  cashierId: cashierId,
  createdAt: DateTime.utc(2026, 9, 23, 10).add(Duration(minutes: minute)),
  shiftId: shiftId,
  shiftOfflineRequestId: shiftOfflineRequestId,
  lines: const [OfflineSaleLine(productId: 'vip', name: 'VIP', priceUzs: 75000, qty: 1)],
  cashUzs: 75000,
  cardUzs: 0,
);

void main() {
  late Directory temp;
  late Box<dynamic> box;
  late OfflineStore store;
  late _FakeRemote remote;
  late OfflineSyncService service;
  String? cashierId = 'cashier-1';

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_offline_sync');
    Hive.init(temp.path);
    box = await Hive.openBox<dynamic>(OfflineStore.boxName);
    store = OfflineStore(box);
    remote = _FakeRemote();
    cashierId = 'cashier-1';
    service = OfflineSyncService(
      store,
      remote,
      () => cashierId,
      clock: () => DateTime.utc(2026, 9, 23, 12),
    );
  });

  tearDown(() async {
    await box.close();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('drops created and duplicate sales, keeps rejected ones as failed', () async {
    await store.putSale(_sale('a'));
    await store.putSale(_sale('b', minute: 1));
    await store.putSale(_sale('c', minute: 2));
    remote.saleResult = (sale) => switch (sale['offlineRequestId']) {
      'a' => const OfflineSyncItemResult(offlineRequestId: 'a', status: OfflineSyncStatus.created, serverId: 's1'),
      'b' => const OfflineSyncItemResult(offlineRequestId: 'b', status: OfflineSyncStatus.duplicate, serverId: 's0'),
      _ => const OfflineSyncItemResult(
        offlineRequestId: 'c',
        status: OfflineSyncStatus.rejected,
        code: 'PRODUCT_NOT_FOUND',
        message: 'Mahsulot topilmadi',
      ),
    };

    final report = await service.sync();

    expect(report.syncedCount, 2);
    expect(report.failed.single.offlineRequestId, 'c');
    expect(report.transportFailed, isFalse);
    final left = store.sales().single;
    expect(left.offlineRequestId, 'c');
    expect(left.isFailed, isTrue);
    expect(left.failureCode, 'PRODUCT_NOT_FOUND');
    expect(left.failureMessage, 'Mahsulot topilmadi');
    expect(left.attempts, 1);
  });

  test('leaves everything pending when the request itself fails', () async {
    await store.putSale(_sale('a'));
    remote.throwOnCall = NoInternetException();

    final report = await service.sync();

    expect(report.transportFailed, isTrue);
    expect(store.sales().single.isFailed, isFalse);
  });

  test('a server error on the whole request is a transport failure too', () async {
    await store.putSale(_sale('a'));
    remote.throwOnCall = ServerException(message: 'Server xatosi', statusCode: 500);

    final report = await service.sync();

    expect(report.transportError, 'Server xatosi');
    expect(store.sales().single.status, OfflineSaleStatus.pending);
  });

  test('sends the offline shift first, then refers to its server id', () async {
    await store.saveOfflineShift(
      OfflineShift(offlineRequestId: 'off-1', cashierId: 'cashier-1', openedAt: DateTime.utc(2026, 9, 23, 8)),
    );
    await store.putSale(_sale('a', shiftId: null, shiftOfflineRequestId: 'off-1'));
    remote.saleResult = (sale) => const OfflineSyncItemResult(
      offlineRequestId: 'a',
      status: OfflineSyncStatus.rejected,
      code: 'X',
      message: 'bad',
    );

    await service.sync();

    expect(remote.calls.single.shifts.single['offlineRequestId'], 'off-1');
    expect(store.offlineShift('cashier-1')!.serverShiftId, 'srv-shift');

    remote.saleResult = (sale) => const OfflineSyncItemResult(
      offlineRequestId: 'a',
      status: OfflineSyncStatus.created,
      serverId: 's1',
    );
    await service.sync(includeFailed: true);

    expect(remote.calls.last.shifts, isEmpty);
    expect(remote.calls.last.sales.single['shiftId'], 'srv-shift');
  });

  test('forgets the offline shift once nothing queued refers to it', () async {
    await store.saveOfflineShift(
      OfflineShift(offlineRequestId: 'off-1', cashierId: 'cashier-1', openedAt: DateTime.utc(2026, 9, 23, 8)),
    );
    await store.putSale(_sale('a', shiftId: null, shiftOfflineRequestId: 'off-1'));

    await service.sync();

    expect(store.sales(), isEmpty);
    expect(store.offlineShift('cashier-1'), isNull);
    expect(store.cachedShift('cashier-1')?.id, 'srv-shift');
  });

  test('splits a long queue into batches of 200, shift only in the first', () async {
    await store.saveOfflineShift(
      OfflineShift(offlineRequestId: 'off-1', cashierId: 'cashier-1', openedAt: DateTime.utc(2026, 9, 23, 8)),
    );
    for (var i = 0; i < 450; i++) {
      await store.putSale(_sale('s$i', minute: i));
    }

    final report = await service.sync();

    expect(remote.calls.map((c) => c.sales.length), [200, 200, 50]);
    expect(remote.calls.map((c) => c.shifts.length), [1, 0, 0]);
    expect(report.syncedCount, 450);
  });

  test('skips failed sales on the automatic sync, resends them on retry', () async {
    await store.putSale(_sale('a').markFailed(code: 'X', message: 'bad', at: DateTime.utc(2026)));
    await store.putSale(_sale('b', minute: 1));

    await service.sync();
    expect(remote.calls.single.sales.map((s) => s['offlineRequestId']), ['b']);

    await service.sync(onlyIds: {'a'}, includeFailed: true);
    expect(remote.calls.last.sales.map((s) => s['offlineRequestId']), ['a']);
  });

  test("never sends another cashier's sales", () async {
    await store.putSale(_sale('mine'));
    await store.putSale(_sale('theirs', cashierId: 'cashier-2'));

    await service.sync();

    expect(remote.calls.single.sales.map((s) => s['offlineRequestId']), ['mine']);
    expect(store.sales().single.offlineRequestId, 'theirs');
  });

  test('does nothing when nobody is signed in or nothing is queued', () async {
    expect(await service.sync(), SyncReport.empty);
    cashierId = null;
    await store.putSale(_sale('a'));
    expect(await service.sync(), SyncReport.empty);
    expect(remote.calls, isEmpty);
  });

  test('concurrent sync calls share one run', () async {
    await store.putSale(_sale('a'));

    await Future.wait([service.sync(), service.sync()]);

    expect(remote.calls.length, 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/offline_sync_service_test.dart`
Expected: compile error, because the files don't exist.

- [ ] **Step 3: Implement the remote**

Create `lib/features/offline/data/offline_sync_remote_data_source.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/network/connectivity_interceptor.dart';

enum OfflineSyncStatus {
  created,
  duplicate,
  rejected;

  static OfflineSyncStatus fromWire(Object? value) => switch (value) {
    'created' => created,
    'duplicate' => duplicate,
    _ => rejected,
  };
}

/// The server's verdict on one shift or sale of a sync request.
class OfflineSyncItemResult extends Equatable {
  const OfflineSyncItemResult({
    required this.offlineRequestId,
    required this.status,
    this.serverId,
    this.code,
    this.message,
  });

  final String offlineRequestId;
  final OfflineSyncStatus status;

  /// `shiftId` / `saleId` on the server — null when rejected.
  final String? serverId;
  final String? code;

  /// Uzbek text of the `{uz, ru, en}` message, falling back to English.
  final String? message;

  factory OfflineSyncItemResult.fromJson(Map<String, dynamic> json, String idKey) {
    final rawMessage = json['message'];
    return OfflineSyncItemResult(
      offlineRequestId: json['offlineRequestId'] as String,
      status: OfflineSyncStatus.fromWire(json['status']),
      serverId: json[idKey] as String?,
      code: json['code'] as String?,
      message: rawMessage is Map
          ? (rawMessage['uz'] ?? rawMessage['en'])?.toString()
          : rawMessage as String?,
    );
  }

  @override
  List<Object?> get props => [offlineRequestId, status, serverId, code, message];
}

class OfflineSyncResult {
  const OfflineSyncResult({required this.shifts, required this.sales});

  final List<OfflineSyncItemResult> shifts;
  final List<OfflineSyncItemResult> sales;

  factory OfflineSyncResult.fromJson(Map<String, dynamic> json) =>
      OfflineSyncResult(
        shifts: [
          for (final item in json['shifts'] as List? ?? const [])
            OfflineSyncItemResult.fromJson(Map<String, dynamic>.from(item as Map), 'shiftId'),
        ],
        sales: [
          for (final item in json['sales'] as List? ?? const [])
            OfflineSyncItemResult.fromJson(Map<String, dynamic>.from(item as Map), 'saleId'),
        ],
      );
}

abstract class OfflineSyncRemoteDataSource {
  Future<OfflineSyncResult> sync({
    required List<Map<String, dynamic>> shifts,
    required List<Map<String, dynamic>> sales,
  });
}

class OfflineSyncRemoteDataSourceImpl implements OfflineSyncRemoteDataSource {
  OfflineSyncRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<OfflineSyncResult> sync({
    required List<Map<String, dynamic>> shifts,
    required List<Map<String, dynamic>> sales,
  }) async {
    try {
      final response = await dio.post(
        '/v1/pos/offline/sync',
        data: {'shifts': shifts, 'sales': sales},
      );
      return OfflineSyncResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (ConnectivityInterceptor.isConnectionError(e)) {
        throw NoInternetException();
      }
      throw ServerException.fromJson(e.response?.data);
    }
  }
}
```

- [ ] **Step 4: Implement the service**

Create `lib/features/offline/application/offline_sync_service.dart`:

```dart
import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../../../core/error/exceptions.dart';
import '../../shift/domain/shift.dart';
import '../data/offline_store.dart';
import '../data/offline_sync_remote_data_source.dart';
import '../domain/offline_sale.dart';
import '../domain/offline_shift.dart';

class SyncReport extends Equatable {
  const SyncReport({
    this.syncedCount = 0,
    this.failed = const [],
    this.transportError,
  });

  static const empty = SyncReport();

  final int syncedCount;
  final List<OfflineSale> failed;

  /// Set when a request never got per-sale answers (no internet, 5xx, 401…).
  /// Every sale of that request is still pending and safe to resend.
  final String? transportError;

  bool get transportFailed => transportError != null;

  @override
  List<Object?> get props => [syncedCount, failed, transportError];
}

/// Replays the signed-in cashier's queue to `POST /v1/pos/offline/sync`,
/// offline shift first. Created/duplicate sales leave the queue; rejected
/// ones stay as `failed` with the server's reason, never deleted.
class OfflineSyncService {
  OfflineSyncService(
    this._store,
    this._remote,
    this._currentCashierId, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const batchSize = 200;

  final OfflineStore _store;
  final OfflineSyncRemoteDataSource _remote;
  final String? Function() _currentCashierId;
  final DateTime Function() _clock;

  Future<SyncReport>? _inFlight;

  /// [includeFailed]: the automatic sync on reconnect only sends pending
  /// sales; the Unsynced page's Retry resends failed ones too.
  Future<SyncReport> sync({Set<String>? onlyIds, bool includeFailed = false}) =>
      _inFlight ??= _sync(onlyIds, includeFailed).whenComplete(
        () => _inFlight = null,
      );

  Future<SyncReport> _sync(Set<String>? onlyIds, bool includeFailed) async {
    final cashierId = _currentCashierId();
    if (cashierId == null) return SyncReport.empty;

    var shift = _store.offlineShift(cashierId);
    final queue = _store
        .sales(cashierId: cashierId)
        .where((sale) => includeFailed || !sale.isFailed)
        .where((sale) => onlyIds == null || onlyIds.contains(sale.offlineRequestId))
        .toList();
    if (queue.isEmpty && (shift == null || shift.isSynced)) {
      return SyncReport.empty;
    }

    final batches = <List<OfflineSale>>[
      for (var i = 0; i < queue.length; i += batchSize)
        queue.sublist(i, math.min(i + batchSize, queue.length)),
    ];
    if (batches.isEmpty) batches.add(const []); // shift-only request

    var synced = 0;
    final failed = <OfflineSale>[];
    for (final batch in batches) {
      final OfflineSyncResult result;
      try {
        result = await _remote.sync(
          shifts: shift != null && !shift.isSynced ? [shift.toSyncJson()] : const [],
          sales: [for (final sale in batch) _payload(sale, shift)],
        );
      } on NoInternetException {
        return SyncReport(syncedCount: synced, failed: failed, transportError: "Internet aloqasi yo'q");
      } on ServerException catch (e) {
        return SyncReport(syncedCount: synced, failed: failed, transportError: e.message);
      }

      shift = await _applyShiftResults(shift, result.shifts);

      final byId = {for (final sale in batch) sale.offlineRequestId: sale};
      final done = <String>[];
      for (final item in result.sales) {
        final sale = byId[item.offlineRequestId];
        if (sale == null) continue;
        if (item.status == OfflineSyncStatus.rejected) {
          final marked = sale.markFailed(
            code: item.code,
            message: item.message ?? 'Server savdoni qabul qilmadi',
            at: _clock(),
          );
          await _store.putSale(marked);
          failed.add(marked);
        } else {
          done.add(item.offlineRequestId);
        }
      }
      await _store.removeSales(done);
      synced += done.length;
    }

    await _releaseOfflineShiftIfDone(cashierId);
    return SyncReport(syncedCount: synced, failed: failed);
  }

  Map<String, dynamic> _payload(OfflineSale sale, OfflineShift? shift) =>
      sale.toSyncJson(
        serverShiftIdForOfflineShift:
            shift != null && sale.shiftOfflineRequestId == shift.offlineRequestId
            ? shift.serverShiftId
            : null,
      );

  Future<OfflineShift?> _applyShiftResults(
    OfflineShift? shift,
    List<OfflineSyncItemResult> results,
  ) async {
    if (shift == null) return null;
    for (final item in results) {
      if (item.offlineRequestId == shift!.offlineRequestId &&
          item.status != OfflineSyncStatus.rejected &&
          item.serverId != null) {
        shift = shift.withServerShiftId(item.serverId!);
        await _store.saveOfflineShift(shift);
      }
    }
    return shift;
  }

  /// A synced offline shift is only kept while some queued sale still names
  /// it; after that the server's own shift (cached online) takes over.
  Future<void> _releaseOfflineShiftIfDone(String cashierId) async {
    final shift = _store.offlineShift(cashierId);
    if (shift == null || !shift.isSynced) return;
    final stillReferenced = _store
        .sales(cashierId: cashierId)
        .any((sale) => sale.shiftOfflineRequestId == shift.offlineRequestId);
    if (stillReferenced) return;
    // Keep the till on that shift even if it drops offline again before the
    // shell has reloaded the server shift.
    if (_store.cachedShift(cashierId) == null) {
      await _store.cacheShift(
        cashierId,
        Shift(
          id: shift.serverShiftId!,
          openedAt: shift.openedAt,
          closedAt: null,
          status: 'open',
          totals: ShiftTotals.zero,
        ),
      );
    }
    await _store.clearOfflineShift(cashierId);
  }
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/offline_sync_service_test.dart && flutter analyze`
Expected: PASS (10 tests); analyzer shows only the baseline.

- [ ] **Step 6: Commit**

```bash
git add lib/features/offline/data/offline_sync_remote_data_source.dart lib/features/offline/application/offline_sync_service.dart test/offline_sync_service_test.dart
git commit -m "feat(offline): sync queued sales in batches with per-sale results

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `AppModeCubit`: mode, prompts, queue counts

**Files:**
- Create: `lib/core/offline/app_mode_cubit.dart`, `lib/core/offline/app_mode_state.dart`
- Test: `test/app_mode_cubit_test.dart`

**Interfaces:**
- Consumes: `ConnectivityEvent` (Task 3), `OfflineStore` (Task 2), `SyncReport` (Task 4)
- Produces:
  - `enum AppMode { online, offline, syncing }`, `enum ModePrompt { none, goOffline, goOnline }`
  - `AppModeState({mode, prompt, pendingCount, failedCount, lastReport})` with `isOffline` (true for `offline` **and** `syncing`) and `queuedCount`
  - `typedef RunSync = Future<SyncReport> Function({Set<String>? onlyIds, bool includeFailed});`
  - `AppModeCubit({required Stream<ConnectivityEvent> connectivity, required Future<bool> Function() checkNow, required OfflineStore store, required RunSync sync, required String? Function() currentCashierId, DateTime Function()? clock, Duration postponeFor = 5 min})`
  - Methods: `acceptOffline()`, `declineOffline()`, `Future<bool> checkOnlineNow()`, `postponeOnline()`, `acceptOnline()`, `Future<SyncReport> retry({Set<String>? ids})`, `reportShown()`, `refreshCounts()`

Rules, from spec D4/D12/D13:
- **Online.**
  - An unreachable event raises `goOffline`, unless the cashier declined earlier and the event is only a background poll. After a decline, only a failed *user* request re-offers.
  - A reachable event clears a decline, and also clears a stale `goOffline` prompt.
- **Offline.**
  - A reachable event raises `goOnline`, unless the cashier pressed "Keyinroq" less than 5 minutes ago.
  - `checkOnlineNow()` raises it regardless of that 5-minute window.
  - An unreachable event clears a stale `goOnline` prompt.
- **`acceptOnline()`.** It goes `syncing` → sync, then:
  - on success → `online`, persisted;
  - on a transport failure → back to `offline`, with the report kept for the UI and the re-offer postponed.
- **Persistence.** The mode persists through `OfflineStore.setOfflineMode`, so a restart comes back in the same mode.

- [ ] **Step 1: Write the failing test**

Create `test/app_mode_cubit_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:cashier_app/core/connectivity/connectivity_monitor.dart';
import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/features/offline/application/offline_sync_service.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _down = ConnectivityEvent(reachable: false);
const _downOnRequest = ConnectivityEvent(reachable: false, fromUserRequest: true);
const _up = ConnectivityEvent(reachable: true);

OfflineSale _sale(String id, {bool failed = false}) {
  final sale = OfflineSale(
    offlineRequestId: id,
    cashierId: 'cashier-1',
    createdAt: DateTime.utc(2026, 9, 23, 10),
    shiftId: 'shift-1',
    lines: const [OfflineSaleLine(productId: 'vip', name: 'VIP', priceUzs: 75000, qty: 1)],
    cashUzs: 75000,
    cardUzs: 0,
  );
  return failed ? sale.markFailed(code: 'X', message: 'bad', at: DateTime.utc(2026)) : sale;
}

void main() {
  late Directory temp;
  late Box<dynamic> box;
  late OfflineStore store;
  late StreamController<ConnectivityEvent> events;
  late DateTime now;
  late bool probeAnswer;
  late SyncReport nextReport;
  late List<({Set<String>? onlyIds, bool includeFailed})> syncCalls;

  AppModeCubit build() => AppModeCubit(
    connectivity: events.stream,
    checkNow: () async => probeAnswer,
    store: store,
    sync: ({Set<String>? onlyIds, bool includeFailed = false}) async {
      syncCalls.add((onlyIds: onlyIds, includeFailed: includeFailed));
      return nextReport;
    },
    currentCashierId: () => 'cashier-1',
    clock: () => now,
  );

  Future<void> send(ConnectivityEvent event) async {
    events.add(event);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_app_mode');
    Hive.init(temp.path);
    box = await Hive.openBox<dynamic>(OfflineStore.boxName);
    store = OfflineStore(box);
    events = StreamController<ConnectivityEvent>.broadcast();
    now = DateTime.utc(2026, 9, 23, 10);
    probeAnswer = true;
    nextReport = SyncReport.empty;
    syncCalls = [];
  });

  tearDown(() async {
    await events.close();
    await box.close();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('comes back offline after a restart during an outage', () async {
    await store.setOfflineMode(true);
    final cubit = build();
    addTearDown(cubit.close);
    expect(cubit.state.mode, AppMode.offline);
  });

  test('an outage asks first; accepting switches to offline and persists it', () async {
    final cubit = build();
    addTearDown(cubit.close);

    await send(_down);
    expect(cubit.state.prompt, ModePrompt.goOffline);
    expect(cubit.state.mode, AppMode.online);

    await cubit.acceptOffline();
    expect(cubit.state.mode, AppMode.offline);
    expect(cubit.state.prompt, ModePrompt.none);
    expect(store.isOfflineMode, isTrue);
  });

  test('after declining, only a failed real request asks again', () async {
    final cubit = build();
    addTearDown(cubit.close);

    await send(_down);
    cubit.declineOffline();
    expect(cubit.state.prompt, ModePrompt.none);

    await send(_down);
    expect(cubit.state.prompt, ModePrompt.none);

    await send(_downOnRequest);
    expect(cubit.state.prompt, ModePrompt.goOffline);
  });

  test('the internet coming back clears a decline and a stale offline prompt', () async {
    final cubit = build();
    addTearDown(cubit.close);

    await send(_down);
    await send(_up);
    expect(cubit.state.prompt, ModePrompt.none);

    await send(_down);
    cubit.declineOffline();
    await send(_up);
    await send(_down);
    expect(cubit.state.prompt, ModePrompt.goOffline);
  });

  test('offline: reachability offers to go online, "later" holds it for 5 minutes', () async {
    await store.setOfflineMode(true);
    final cubit = build();
    addTearDown(cubit.close);

    await send(_up);
    expect(cubit.state.prompt, ModePrompt.goOnline);

    cubit.postponeOnline();
    now = now.add(const Duration(minutes: 4));
    await send(_up);
    expect(cubit.state.prompt, ModePrompt.none);

    now = now.add(const Duration(minutes: 2));
    await send(_up);
    expect(cubit.state.prompt, ModePrompt.goOnline);
  });

  test('"check online" asks at once, even inside the postpone window', () async {
    await store.setOfflineMode(true);
    final cubit = build();
    addTearDown(cubit.close);

    await send(_up);
    cubit.postponeOnline();

    expect(await cubit.checkOnlineNow(), isTrue);
    expect(cubit.state.prompt, ModePrompt.goOnline);
  });

  test('"check online" with no internet reports false and asks nothing', () async {
    await store.setOfflineMode(true);
    probeAnswer = false;
    final cubit = build();
    addTearDown(cubit.close);

    expect(await cubit.checkOnlineNow(), isFalse);
    expect(cubit.state.prompt, ModePrompt.none);
  });

  test('going online syncs, then switches and remembers the report', () async {
    await store.setOfflineMode(true);
    nextReport = const SyncReport(syncedCount: 3);
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.acceptOnline();

    expect(syncCalls.single.includeFailed, isFalse);
    expect(cubit.state.mode, AppMode.online);
    expect(cubit.state.lastReport, nextReport);
    expect(store.isOfflineMode, isFalse);

    cubit.reportShown();
    expect(cubit.state.lastReport, isNull);
  });

  test('a sync that cannot reach the server leaves the terminal offline', () async {
    await store.setOfflineMode(true);
    nextReport = const SyncReport(transportError: "Internet aloqasi yo'q");
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.acceptOnline();

    expect(cubit.state.mode, AppMode.offline);
    expect(cubit.state.lastReport?.transportFailed, isTrue);
    expect(store.isOfflineMode, isTrue);

    await send(_up); // postponed after the failed attempt
    expect(cubit.state.prompt, ModePrompt.none);
  });

  test('retry resends failed sales too, and only online', () async {
    final cubit = build();
    addTearDown(cubit.close);

    await cubit.retry(ids: {'a'});
    expect(syncCalls.single.onlyIds, {'a'});
    expect(syncCalls.single.includeFailed, isTrue);

    await cubit.acceptOffline();
    await cubit.retry();
    expect(syncCalls, hasLength(1));
  });

  test('tracks pending and failed counts from the store', () async {
    final cubit = build();
    addTearDown(cubit.close);

    await store.putSale(_sale('a'));
    await store.putSale(_sale('b', failed: true));

    expect(cubit.state.pendingCount, 1);
    expect(cubit.state.failedCount, 1);
    expect(cubit.state.queuedCount, 2);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/app_mode_cubit_test.dart`
Expected: compile error, because `app_mode_cubit.dart` doesn't exist.

- [ ] **Step 3: Implement**

Create `lib/core/offline/app_mode_state.dart`:

```dart
part of 'app_mode_cubit.dart';

enum AppMode { online, offline, syncing }

/// Which confirmation modal the shell owes the cashier right now.
enum ModePrompt { none, goOffline, goOnline }

class AppModeState extends Equatable {
  const AppModeState({
    this.mode = AppMode.online,
    this.prompt = ModePrompt.none,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastReport,
  });

  final AppMode mode;
  final ModePrompt prompt;
  final int pendingCount;
  final int failedCount;

  /// Outcome of the last sync until the UI has shown it
  /// ([AppModeCubit.reportShown]).
  final SyncReport? lastReport;

  /// Syncing counts as offline for gating — no online-only action may start
  /// while the queue is being replayed.
  bool get isOffline => mode != AppMode.online;
  int get queuedCount => pendingCount + failedCount;

  AppModeState copyWith({
    AppMode? mode,
    ModePrompt? prompt,
    int? pendingCount,
    int? failedCount,
    SyncReport? lastReport,
    bool clearReport = false,
  }) => AppModeState(
    mode: mode ?? this.mode,
    prompt: prompt ?? this.prompt,
    pendingCount: pendingCount ?? this.pendingCount,
    failedCount: failedCount ?? this.failedCount,
    lastReport: clearReport ? null : (lastReport ?? this.lastReport),
  );

  @override
  List<Object?> get props => [mode, prompt, pendingCount, failedCount, lastReport];
}
```

Create `lib/core/offline/app_mode_cubit.dart`:

```dart
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/offline/application/offline_sync_service.dart';
import '../../features/offline/data/offline_store.dart';
import '../../features/offline/domain/offline_sale.dart';
import '../connectivity/connectivity_monitor.dart';

part 'app_mode_state.dart';

typedef RunSync =
    Future<SyncReport> Function({Set<String>? onlyIds, bool includeFailed});

/// App-wide online/offline mode. Never switches on its own: it raises a
/// [ModePrompt] and waits for the cashier to confirm (spec D13).
class AppModeCubit extends Cubit<AppModeState> {
  AppModeCubit({
    required Stream<ConnectivityEvent> connectivity,
    required Future<bool> Function() checkNow,
    required OfflineStore store,
    required RunSync sync,
    required String? Function() currentCashierId,
    DateTime Function()? clock,
    this.postponeFor = const Duration(minutes: 5),
  }) : _checkNow = checkNow,
       _store = store,
       _sync = sync,
       _currentCashierId = currentCashierId,
       _clock = clock ?? DateTime.now,
       super(
         AppModeState(
           mode: store.isOfflineMode ? AppMode.offline : AppMode.online,
         ),
       ) {
    _subscription = connectivity.listen(_onConnectivity);
    _store.addListener(refreshCounts);
    refreshCounts();
  }

  final Duration postponeFor;
  final Future<bool> Function() _checkNow;
  final OfflineStore _store;
  final RunSync _sync;
  final String? Function() _currentCashierId;
  final DateTime Function() _clock;
  late final StreamSubscription<ConnectivityEvent> _subscription;

  DateTime? _declinedAt;
  DateTime? _postponedAt;

  void _onConnectivity(ConnectivityEvent event) {
    switch (state.mode) {
      case AppMode.online:
        if (event.reachable) {
          _declinedAt = null;
          if (state.prompt == ModePrompt.goOffline) {
            emit(state.copyWith(prompt: ModePrompt.none));
          }
          return;
        }
        if (state.prompt != ModePrompt.none) return;
        if (_declinedAt != null && !event.fromUserRequest) return;
        emit(state.copyWith(prompt: ModePrompt.goOffline));
      case AppMode.offline:
        if (!event.reachable) {
          if (state.prompt == ModePrompt.goOnline) {
            emit(state.copyWith(prompt: ModePrompt.none));
          }
          return;
        }
        if (state.prompt != ModePrompt.none || _isPostponed) return;
        emit(state.copyWith(prompt: ModePrompt.goOnline));
      case AppMode.syncing:
        return;
    }
  }

  bool get _isPostponed =>
      _postponedAt != null && _clock().difference(_postponedAt!) < postponeFor;

  Future<void> acceptOffline() async {
    _declinedAt = null;
    await _store.setOfflineMode(true);
    emit(state.copyWith(mode: AppMode.offline, prompt: ModePrompt.none));
  }

  void declineOffline() {
    _declinedAt = _clock();
    emit(state.copyWith(prompt: ModePrompt.none));
  }

  /// "Onlaynni tekshirish". Ignores the postpone window on purpose.
  Future<bool> checkOnlineNow() async {
    final reachable = await _checkNow();
    if (reachable && state.mode == AppMode.offline) {
      emit(state.copyWith(prompt: ModePrompt.goOnline));
    }
    return reachable;
  }

  void postponeOnline() {
    _postponedAt = _clock();
    emit(state.copyWith(prompt: ModePrompt.none));
  }

  Future<void> acceptOnline() async {
    emit(
      state.copyWith(
        mode: AppMode.syncing,
        prompt: ModePrompt.none,
        clearReport: true,
      ),
    );
    final report = await _sync();
    if (report.transportFailed) {
      _postponedAt = _clock();
      emit(state.copyWith(mode: AppMode.offline, lastReport: report));
      return;
    }
    _postponedAt = null;
    await _store.setOfflineMode(false);
    emit(state.copyWith(mode: AppMode.online, lastReport: report));
  }

  /// The Unsynced page's Retry. Resends failed sales too; online only.
  Future<SyncReport> retry({Set<String>? ids}) async {
    if (state.mode != AppMode.online) return SyncReport.empty;
    final report = await _sync(onlyIds: ids, includeFailed: true);
    emit(state.copyWith(lastReport: report));
    return report;
  }

  void reportShown() => emit(state.copyWith(clearReport: true));

  /// Also called by the shell after login — the counts belong to whoever is
  /// signed in.
  void refreshCounts() {
    if (isClosed) return;
    final cashierId = _currentCashierId();
    final sales = cashierId == null
        ? const <OfflineSale>[]
        : _store.sales(cashierId: cashierId);
    final failed = sales.where((sale) => sale.isFailed).length;
    emit(
      state.copyWith(
        pendingCount: sales.length - failed,
        failedCount: failed,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    _store.removeListener(refreshCounts);
    return super.close();
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/app_mode_cubit_test.dart && flutter analyze`
Expected: PASS (11 tests); only the baseline analyzer infos.

- [ ] **Step 5: Commit**

```bash
git add lib/core/offline test/app_mode_cubit_test.dart
git commit -m "feat(offline): app-wide mode cubit with confirm-first prompts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Offline-aware repositories (products, discounts, shift)

**Files:**
- Modify: `lib/features/products/data/products_remote_data_source.dart` (send `includeOffline=true`), `lib/features/products/data/products_repository_impl.dart`
- Modify: `lib/features/pos_sale/data/pos_sale_repository_impl.dart`
- Modify: `lib/features/shift/data/shift_repository_impl.dart`
- Modify: `lib/injector_container.dart` (open the offline box, register `OfflineStore`, pass it)
- Test: `test/offline_repositories_test.dart`

**Interfaces:**
- Consumes: `OfflineStore` (Task 2), `OfflineShift` (Task 1), `LocalSource`
- Produces:
  - `ProductsRepository(ProductsRemoteDataSource remote, OfflineStore store, LocalSource local)`. `listProducts()` works as follows:
    - offline → the cache, or `CacheFailure`;
    - online success → caches the result;
    - online failure → the cache if there is one, else the failure.
  - `PosSaleRepository(PosSaleRemoteDataSource remote, OfflineStore store)`. `fetchDiscounts()` follows the same pattern; `checkout` is unchanged.
  - `ShiftRepository(ShiftRemoteDataSource remote, OfflineStore store, LocalSource local, {String Function()? newId, DateTime Function()? clock})`:
    - `getCurrentShift()`: offline → the cached open shift, else the offline shift's `toShift()`, else `ServerFailure(code: 'SHIFT_NOT_OPEN')`. Online success → caches it; online `SHIFT_NOT_OPEN` → clears the cache.
    - `openShift()`: offline → creates and stores an `OfflineShift`; online success → caches it.
    - `closeShift()`: offline → `ServerFailure(code: 'OFFLINE_UNAVAILABLE')`; pending (non-failed) queued sales → `ServerFailure(code: 'OFFLINE_SALES_PENDING')`; success → clears the cached shift and any fully synced offline shift.
  - DI: `sl<OfflineStore>()` is registered (singleton; box `OfflineStore.boxName`).

- [ ] **Step 1: Write the failing test**

Create `test/offline_repositories_test.dart`:

```dart
import 'dart:io';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/core/error/failure.dart';
import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:cashier_app/features/offline/domain/offline_shift.dart';
import 'package:cashier_app/features/pos_sale/data/pos_sale_remote_data_source.dart';
import 'package:cashier_app/features/pos_sale/data/pos_sale_repository_impl.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';
import 'package:cashier_app/features/products/data/products_remote_data_source.dart';
import 'package:cashier_app/features/products/data/products_repository_impl.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/shift/data/shift_remote_data_source.dart';
import 'package:cashier_app/features/shift/data/shift_repository_impl.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _vip = Product(id: 'vip', name: 'VIP', priceUzs: 75000, category: 'Tariflar', icon: 'ph-crown', offlineOnly: true);
const _flyer = Discount(id: 'd', name: 'Flayer', kind: DiscountKind.percent, value: 10);
final _serverShift = Shift(
  id: 'shift-1',
  openedAt: DateTime.utc(2026, 9, 23, 8),
  closedAt: null,
  status: 'open',
  totals: ShiftTotals.zero,
);

class _Products extends ProductsRemoteDataSourceImpl {
  _Products() : super(Dio());
  Object? error;
  int calls = 0;
  @override
  Future<List<Product>> listProducts() async {
    calls++;
    if (error != null) throw error!;
    return const [_vip];
  }
}

class _Sales extends PosSaleRemoteDataSourceImpl {
  _Sales() : super(Dio());
  Object? error;
  @override
  Future<List<Discount>> fetchDiscounts() async {
    if (error != null) throw error!;
    return const [_flyer];
  }
}

class _Shifts extends ShiftRemoteDataSourceImpl {
  _Shifts() : super(Dio());
  Object? error;
  int calls = 0;
  @override
  Future<Shift> getCurrentShift() async {
    calls++;
    if (error != null) throw error!;
    return _serverShift;
  }

  @override
  Future<Shift> closeShift({String? closingNote}) async {
    calls++;
    return Shift(
      id: _serverShift.id,
      openedAt: _serverShift.openedAt,
      closedAt: DateTime.utc(2026, 9, 23, 20),
      status: 'closed',
      totals: ShiftTotals.zero,
    );
  }
}

void main() {
  late Directory temp;
  late Box<dynamic> offlineBox;
  late Box<dynamic> appBox;
  late OfflineStore store;
  late LocalSource local;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_offline_repos');
    Hive.init(temp.path);
    offlineBox = await Hive.openBox<dynamic>(OfflineStore.boxName);
    appBox = await Hive.openBox<dynamic>('cashier_app_box_test');
    store = OfflineStore(offlineBox);
    local = LocalSource(appBox)
      ..setCashier(
        id: 'cashier-1',
        fullName: 'Zaira',
        username: 'zaira',
        branchId: 'branch-1',
        branchName: 'Algoritm',
      );
  });

  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  group('ProductsRepository', () {
    test('caches the catalog online and serves it offline without calling out', () async {
      final remote = _Products();
      final repository = ProductsRepository(remote, store, local);

      expect((await repository.listProducts()).getOrElse(() => []), const [_vip]);
      await store.setOfflineMode(true);
      remote.error = NoInternetException();

      expect((await repository.listProducts()).getOrElse(() => []), const [_vip]);
      expect(remote.calls, 1);
    });

    test('offline without a cached catalog explains that internet is needed', () async {
      await store.setOfflineMode(true);
      final result = await ProductsRepository(_Products(), store, local).listProducts();
      expect(result.fold((f) => f, (_) => null), isA<CacheFailure>());
    });

    test('falls back to the cache when an online fetch fails', () async {
      final remote = _Products();
      final repository = ProductsRepository(remote, store, local);
      await repository.listProducts();
      remote.error = ServerException(message: 'down', statusCode: 502);

      expect((await repository.listProducts()).isRight(), isTrue);
    });
  });

  group('PosSaleRepository discounts', () {
    test('cached online, served offline', () async {
      final remote = _Sales();
      final repository = PosSaleRepository(remote, store);
      await repository.fetchDiscounts();
      await store.setOfflineMode(true);
      remote.error = NoInternetException();

      expect((await repository.fetchDiscounts()).getOrElse(() => []), const [_flyer]);
    });
  });

  group('ShiftRepository', () {
    ShiftRepository build(_Shifts remote) => ShiftRepository(
      remote,
      store,
      local,
      newId: () => 'off-shift-1',
      clock: () => DateTime.utc(2026, 9, 23, 9),
    );

    test('offline, the cached open shift keeps the till open', () async {
      final remote = _Shifts();
      final repository = build(remote);
      await repository.getCurrentShift();
      await store.setOfflineMode(true);

      final result = await repository.getCurrentShift();

      expect(result.getOrElse(() => throw 'no shift').id, 'shift-1');
      expect(remote.calls, 1);
    });

    test('offline with no shift: opening one creates it locally', () async {
      await store.setOfflineMode(true);
      final repository = build(_Shifts());

      final before = await repository.getCurrentShift();
      expect(before.fold((f) => (f as ServerFailure).code, (_) => null), 'SHIFT_NOT_OPEN');

      final opened = (await repository.openShift(openingCashUzs: 20000)).getOrElse(() => throw 'x');
      expect(opened.id, 'offline:off-shift-1');
      expect(store.offlineShift('cashier-1')!.openingCashUzs, 20000);
      expect((await repository.getCurrentShift()).getOrElse(() => throw 'x').id, 'offline:off-shift-1');
    });

    test('a shift cannot be closed offline', () async {
      await store.setOfflineMode(true);
      final result = await build(_Shifts()).closeShift();
      expect(result.fold((f) => (f as ServerFailure).code, (_) => null), 'OFFLINE_UNAVAILABLE');
    });

    test('closing is blocked while sales still wait to sync, allowed with only failed ones', () async {
      final remote = _Shifts();
      final repository = build(remote);
      final sale = OfflineSale(
        offlineRequestId: 'a',
        cashierId: 'cashier-1',
        createdAt: DateTime.utc(2026, 9, 23, 10),
        shiftId: 'shift-1',
        lines: const [OfflineSaleLine(productId: 'vip', name: 'VIP', priceUzs: 75000, qty: 1)],
        cashUzs: 75000,
        cardUzs: 0,
      );
      await store.putSale(sale);

      final blocked = await repository.closeShift();
      expect(blocked.fold((f) => (f as ServerFailure).code, (_) => null), 'OFFLINE_SALES_PENDING');

      await store.putSale(sale.markFailed(code: 'X', message: 'bad', at: DateTime.utc(2026)));
      await repository.getCurrentShift();
      final closed = await repository.closeShift();
      expect(closed.isRight(), isTrue);
      expect(store.cachedShift('cashier-1'), isNull);
    });

    test('online, "no open shift" clears a stale cached shift', () async {
      final remote = _Shifts();
      final repository = build(remote);
      await repository.getCurrentShift();
      remote.error = ServerException(message: 'Smena ochilmagan', code: 'SHIFT_NOT_OPEN');

      await repository.getCurrentShift();

      expect(store.cachedShift('cashier-1'), isNull);
    });

    test('a fully synced offline shift is forgotten when the shift closes', () async {
      await store.saveOfflineShift(
        OfflineShift(
          offlineRequestId: 'off-1',
          cashierId: 'cashier-1',
          openedAt: DateTime.utc(2026, 9, 23, 8),
          serverShiftId: 'shift-1',
        ),
      );
      await build(_Shifts()).closeShift();
      expect(store.offlineShift('cashier-1'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/offline_repositories_test.dart`
Expected: compile errors, because the repository constructors take the wrong number of arguments.

- [ ] **Step 3: Products**

`products_remote_data_source.dart`: change the call to

```dart
      // includeOffline: the offline-only plan items are cached with the rest
      // and shown only in offline mode (an older backend ignores the flag).
      final response = await dio.get(
        '/v1/pos/products',
        queryParameters: {'includeOffline': 'true'},
      );
```

Replace `products_repository_impl.dart` with:

```dart
import 'package:dartz/dartz.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failure.dart';
import '../../../core/local_source/local_source.dart';
import '../../offline/data/offline_store.dart';
import '../domain/product.dart';
import 'products_remote_data_source.dart';

/// Every good fetch is cached per branch, so the Savdo grid still works
/// offline — and after an app restart during an outage.
class ProductsRepository {
  ProductsRepository(this.remote, this._store, this._local);

  final ProductsRemoteDataSource remote;
  final OfflineStore _store;
  final LocalSource _local;

  Future<Either<Failure, List<Product>>> listProducts() async {
    final branchId = _local.getBranchId();
    final cached = branchId == null ? null : _store.cachedProducts(branchId);
    if (_store.isOfflineMode) {
      return cached != null
          ? Right(cached)
          : Left(
              CacheFailure(
                message: 'Mahsulotlar hali yuklanmagan — internet kerak',
              ),
            );
    }
    try {
      final products = await remote.listProducts();
      if (branchId != null) await _store.cacheProducts(branchId, products);
      return Right(products);
    } on ServerException catch (e) {
      if (cached != null) return Right(cached);
      return Left(
        ServerFailure(
          message: e.message,
          code: e.code,
          statusCode: e.statusCode,
        ),
      );
    } on NoInternetException {
      if (cached != null) return Right(cached);
      return Left(NoInternetFailure());
    }
  }
}
```

- [ ] **Step 4: Discounts**

In `pos_sale_repository_impl.dart`, change the constructor to `PosSaleRepository(this.remote, this._store);`, add `final OfflineStore _store;` plus the import, and replace `fetchDiscounts`:

```dart
  /// Cached like products; offline the picker shows the last known list.
  Future<Either<Failure, List<Discount>>> fetchDiscounts() async {
    final cached = _store.cachedDiscounts();
    if (_store.isOfflineMode) return Right(cached ?? const []);
    final result = await _call(() => remote.fetchDiscounts());
    return result.fold(
      (failure) async => cached != null ? Right(cached) : Left(failure),
      (discounts) async {
        await _store.cacheDiscounts(discounts);
        return Right(discounts);
      },
    );
  }
```

- [ ] **Step 5: Shift**

Replace `shift_repository_impl.dart` with:

```dart
import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/error/failure.dart';
import '../../../core/local_source/local_source.dart';
import '../../offline/data/offline_store.dart';
import '../../offline/domain/offline_shift.dart';
import '../domain/shift.dart';
import 'shift_remote_data_source.dart';

/// Online: the server's shift, cached after every good load. Offline: that
/// cached shift, or one the cashier opens locally (spec D7) — created on the
/// server first when the queue syncs.
class ShiftRepository {
  ShiftRepository(
    this.remote,
    this._store,
    this._local, {
    String Function()? newId,
    DateTime Function()? clock,
  }) : _newId = newId ?? (() => const Uuid().v4()),
       _clock = clock ?? DateTime.now;

  final ShiftRemoteDataSource remote;
  final OfflineStore _store;
  final LocalSource _local;
  final String Function() _newId;
  final DateTime Function() _clock;

  Future<Either<Failure, Shift>> getCurrentShift() async {
    final cashierId = _local.getCashierId();
    if (_store.isOfflineMode) return _localShift(cashierId);
    final result = await _call(remote.getCurrentShift);
    if (cashierId == null) return result;
    return result.fold(
      (failure) async {
        if (failure is ServerFailure && failure.code == 'SHIFT_NOT_OPEN') {
          await _store.clearCachedShift(cashierId);
        }
        return Left(failure);
      },
      (shift) async {
        await _store.cacheShift(cashierId, shift);
        return Right(shift);
      },
    );
  }

  Future<Either<Failure, Shift>> openShift({int? openingCashUzs}) async {
    final cashierId = _local.getCashierId();
    if (_store.isOfflineMode) {
      if (cashierId == null) {
        return Left(CacheFailure(message: 'Kassir aniqlanmadi'));
      }
      final shift = OfflineShift(
        offlineRequestId: _newId(),
        cashierId: cashierId,
        openedAt: _clock(),
        openingCashUzs: openingCashUzs,
      );
      await _store.saveOfflineShift(shift);
      return Right(shift.toShift());
    }
    final result = await _call(
      () => remote.openShift(openingCashUzs: openingCashUzs),
    );
    return result.fold((failure) async => Left(failure), (shift) async {
      if (cashierId != null) await _store.cacheShift(cashierId, shift);
      return Right(shift);
    });
  }

  Future<Either<Failure, Shift>> closeShift({String? closingNote}) async {
    if (_store.isOfflineMode) {
      return Left(
        ServerFailure(
          message: "Offline rejimda smenani yopib bo'lmaydi",
          code: 'OFFLINE_UNAVAILABLE',
        ),
      );
    }
    final cashierId = _local.getCashierId();
    final pending = cashierId == null
        ? 0
        : _store.sales(cashierId: cashierId).where((s) => !s.isFailed).length;
    if (pending > 0) {
      return Left(
        ServerFailure(
          message:
              "$pending ta savdo hali sinxronlanmagan. Avval onlayn rejimda sinxronlang.",
          code: 'OFFLINE_SALES_PENDING',
        ),
      );
    }
    final result = await _call(
      () => remote.closeShift(closingNote: closingNote),
    );
    return result.fold((failure) async => Left(failure), (shift) async {
      if (cashierId != null) await _forgetShift(cashierId);
      return Right(shift);
    });
  }

  Future<void> _forgetShift(String cashierId) async {
    await _store.clearCachedShift(cashierId);
    final offline = _store.offlineShift(cashierId);
    final stillReferenced = _store
        .sales(cashierId: cashierId)
        .any((sale) => sale.shiftOfflineRequestId == offline?.offlineRequestId);
    if (offline != null && offline.isSynced && !stillReferenced) {
      await _store.clearOfflineShift(cashierId);
    }
  }

  Either<Failure, Shift> _localShift(String? cashierId) {
    if (cashierId != null) {
      final cached = _store.cachedShift(cashierId);
      if (cached != null && cached.isOpen) return Right(cached);
      final offline = _store.offlineShift(cashierId);
      if (offline != null) return Right(offline.toShift());
    }
    return Left(
      ServerFailure(message: 'Smena ochilmagan', code: 'SHIFT_NOT_OPEN'),
    );
  }

  Future<Either<Failure, Shift>> _call(Future<Shift> Function() call) async {
    try {
      return Right(await call());
    } on ServerException catch (e) {
      return Left(
        ServerFailure(
          message: e.message,
          code: e.code,
          statusCode: e.statusCode,
        ),
      );
    } on NoInternetException {
      return Left(NoInternetFailure());
    }
  }
}
```

- [ ] **Step 6: DI**

In `injector_container.dart`:
- In `_initHive()`, after opening `cashier_app_box`, add:

```dart
  // Separate box: logout's clearSession() must never touch queued sales.
  final offlineBox = await Hive.openBox<dynamic>(OfflineStore.boxName);
  sl.registerSingleton<OfflineStore>(OfflineStore(offlineBox));
```

- `_shiftFeature`: `ShiftRepository(sl(), sl(), sl())`.
- `_productsFeature`: `ProductsRepository(sl(), sl(), sl())`.
- `_posSaleFeature`: `PosSaleRepository(sl(), sl())`.
- Import `features/offline/data/offline_store.dart`.

Also fix any existing test that builds these repositories directly (`grep -rn "ShiftRepository(\|ProductsRepository(\|PosSaleRepository(" test`). Pass a temp-box `OfflineStore` and a `LocalSource` there, following the setup above.

- [ ] **Step 7: Run the tests**

Run: `flutter test && flutter analyze`
Expected: all pass, including `injector_container_update_service_test.dart` (it runs the real `di.init()`, which now opens the second box). Analyzer shows only the baseline.

- [ ] **Step 8: Commit**

```bash
git add lib/features/products/data lib/features/pos_sale/data lib/features/shift/data lib/injector_container.dart test
git commit -m "feat(offline): cache catalog, discounts and shift; open a shift offline

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Selling offline (`OfflineCheckout` and the Savdo bloc)

**Files:**
- Create: `lib/features/offline/application/offline_checkout.dart`
- Modify: `lib/features/pos_sale/presentation/bloc/pos_sale_bloc.dart`, `pos_sale_event.dart`, `pos_sale_state.dart`
- Modify: `lib/injector_container.dart` (`_posSaleFeature`)
- Test: `test/offline_checkout_test.dart`, `test/pos_sale_offline_test.dart`

**Interfaces:**
- Consumes: `OfflineStore`, `OfflineSale`, `CartLine`, `Discount`, the repositories from Task 6
- Produces:
  - `class NoShiftForOfflineSaleException implements Exception`, `class OfflinePaymentShortException implements Exception`
  - `OfflineCheckout(OfflineStore store, LocalSource local, {String Function()? newId, DateTime Function()? clock})` with `Future<OfflineSale> record({required List<CartLine> lines, required Discount? discount, required int cashUzs, required int cardUzs})`. It persists the sale **before** returning.
  - `PosSaleBloc(PosSaleRepository, ProductsRepository, OfflineCheckout, {bool offlineMode = false})`
  - New event `PosSaleModeChanged(bool offline)`
  - `PosSaleState.offlineMode` and `PosSaleState.sellableProducts` (offline-only items hidden online); `visibleProducts`, `categories` and `cartLines` are built from `sellableProducts`

- [ ] **Step 1: Write the failing tests**

Create `test/offline_checkout_test.dart`:

```dart
import 'dart:io';

import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/features/offline/application/offline_checkout.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/domain/offline_shift.dart';
import 'package:cashier_app/features/pos_sale/domain/cart_line.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _vip = Product(id: 'vip', name: 'VIP', priceUzs: 75000, category: 'Tariflar', icon: 'ph-crown', offlineOnly: true);

void main() {
  late Directory temp;
  late OfflineStore store;
  late LocalSource local;
  late OfflineCheckout checkout;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_offline_checkout');
    Hive.init(temp.path);
    store = OfflineStore(await Hive.openBox<dynamic>(OfflineStore.boxName));
    local = LocalSource(await Hive.openBox<dynamic>('app_test'))
      ..setCashier(id: 'cashier-1', fullName: 'Zaira', username: 'z', branchId: 'b', branchName: 'B');
    checkout = OfflineCheckout(
      store,
      local,
      newId: () => '35b4fb47-a84f-483f-b73c-44ff6a04be23',
      clock: () => DateTime.utc(2026, 9, 23, 10, 15),
    );
  });

  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  Future<void> cacheOpenShift() => store.cacheShift(
    'cashier-1',
    Shift(id: 'shift-1', openedAt: DateTime.utc(2026, 9, 23, 8), closedAt: null, status: 'open', totals: ShiftTotals.zero),
  );

  test('queues the sale under the cached server shift, at the grid price', () async {
    await cacheOpenShift();

    final sale = await checkout.record(
      lines: const [CartLine(product: _vip, qty: 2)],
      discount: null,
      cashUzs: 150000,
      cardUzs: 0,
    );

    expect(sale.shiftId, 'shift-1');
    expect(sale.lines.single.priceUzs, 75000);
    expect(sale.createdAt, DateTime.utc(2026, 9, 23, 10, 15));
    expect(store.sales().single, sale);
  });

  test('uses the offline shift when there is no server shift', () async {
    await store.saveOfflineShift(
      OfflineShift(offlineRequestId: 'off-1', cashierId: 'cashier-1', openedAt: DateTime.utc(2026, 9, 23, 8)),
    );

    final sale = await checkout.record(
      lines: const [CartLine(product: _vip, qty: 1)],
      discount: null,
      cashUzs: 75000,
      cardUzs: 0,
    );

    expect(sale.shiftId, isNull);
    expect(sale.shiftOfflineRequestId, 'off-1');
  });

  test('refuses without any shift, and when underpaid', () async {
    await expectLater(
      checkout.record(lines: const [CartLine(product: _vip, qty: 1)], discount: null, cashUzs: 75000, cardUzs: 0),
      throwsA(isA<NoShiftForOfflineSaleException>()),
    );

    await cacheOpenShift();
    await expectLater(
      checkout.record(lines: const [CartLine(product: _vip, qty: 1)], discount: null, cashUzs: 70000, cardUzs: 0),
      throwsA(isA<OfflinePaymentShortException>()),
    );
    expect(store.sales(), isEmpty);
  });
}
```

Create `test/pos_sale_offline_test.dart`:

```dart
import 'dart:io';

import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/features/offline/application/offline_checkout.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/pos_sale/data/pos_sale_remote_data_source.dart';
import 'package:cashier_app/features/pos_sale/data/pos_sale_repository_impl.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';
import 'package:cashier_app/features/pos_sale/domain/sale_receipt.dart';
import 'package:cashier_app/features/pos_sale/presentation/bloc/pos_sale_bloc.dart';
import 'package:cashier_app/features/products/data/products_remote_data_source.dart';
import 'package:cashier_app/features/products/data/products_repository_impl.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

const _popcorn = Product(id: 'popcorn', name: 'Popkorn', priceUzs: 12000, category: 'Gazak', icon: 'ph-popcorn');
const _vip = Product(id: 'vip', name: 'VIP', priceUzs: 75000, category: 'Tariflar', icon: 'ph-crown', offlineOnly: true);

class _Products extends ProductsRemoteDataSourceImpl {
  _Products() : super(Dio());
  @override
  Future<List<Product>> listProducts() async => const [_popcorn, _vip];
}

class _Sales extends PosSaleRemoteDataSourceImpl {
  _Sales() : super(Dio());
  int checkouts = 0;
  @override
  Future<List<Discount>> fetchDiscounts() async => const [];
  @override
  Future<SaleReceipt> checkout({
    required List<CheckoutLine> lines,
    required int cashUzs,
    required int cardUzs,
    String? discountId,
  }) async {
    checkouts++;
    throw UnimplementedError();
  }
}

void main() {
  late Directory temp;
  late OfflineStore store;
  late _Sales sales;
  late PosSaleBloc Function({bool offlineMode}) build;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_pos_offline');
    Hive.init(temp.path);
    store = OfflineStore(await Hive.openBox<dynamic>(OfflineStore.boxName));
    final local = LocalSource(await Hive.openBox<dynamic>('app_test'))
      ..setCashier(id: 'cashier-1', fullName: 'Zaira', username: 'z', branchId: 'b', branchName: 'B');
    await store.cacheShift(
      'cashier-1',
      Shift(id: 'shift-1', openedAt: DateTime.utc(2026, 9, 23, 8), closedAt: null, status: 'open', totals: ShiftTotals.zero),
    );
    sales = _Sales();
    final products = ProductsRepository(_Products(), store, local);
    await products.listProducts(); // warm the cache like an online session would
    build = ({bool offlineMode = false}) => PosSaleBloc(
      PosSaleRepository(sales, store),
      products,
      OfflineCheckout(store, local),
      offlineMode: offlineMode,
    );
  });

  tearDown(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('offline-only plan items are hidden online and sellable offline', () async {
    final online = build();
    addTearDown(online.close);
    online.add(const PosSaleStarted());
    await settle();
    expect(online.state.visibleProducts.map((p) => p.id), ['popcorn']);

    await store.setOfflineMode(true);
    final offline = build(offlineMode: true);
    addTearDown(offline.close);
    offline.add(const PosSaleStarted());
    await settle();
    expect(offline.state.visibleProducts.map((p) => p.id), containsAll(['popcorn', 'vip']));
  });

  test('offline checkout queues the sale and yields an offline receipt, no server call', () async {
    await store.setOfflineMode(true);
    final bloc = build(offlineMode: true);
    addTearDown(bloc.close);
    bloc.add(const PosSaleStarted());
    await settle();

    bloc
      ..add(const PosSaleProductAdded(_vip))
      ..add(const PosSaleProductAdded(_vip))
      ..add(const PosSaleCheckoutRequested(cashUzs: 150000, cardUzs: 0));
    await settle();

    expect(sales.checkouts, 0);
    expect(bloc.state.lastReceipt?.isOffline, isTrue);
    expect(bloc.state.lastReceipt?.subtotalUzs, 150000);
    expect(bloc.state.cart, isEmpty);
    expect(store.sales().single.lines.single.qty, 2);
  });

  test('going back online drops offline-only items from the cart', () async {
    await store.setOfflineMode(true);
    final bloc = build(offlineMode: true);
    addTearDown(bloc.close);
    bloc.add(const PosSaleStarted());
    await settle();
    bloc
      ..add(const PosSaleProductAdded(_vip))
      ..add(const PosSaleProductAdded(_popcorn));
    await settle();

    await store.setOfflineMode(false);
    bloc.add(const PosSaleModeChanged(false));
    await settle();

    expect(bloc.state.offlineMode, isFalse);
    expect(bloc.state.cart.keys, ['popcorn']);
  });
}
```

(Check that `PosSaleProductAdded` and `PosSaleCheckoutRequested` have these const constructors in `pos_sale_event.dart`, and adapt the calls if the parameter names differ.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/offline_checkout_test.dart test/pos_sale_offline_test.dart`
Expected: compile errors, because `OfflineCheckout`, `PosSaleModeChanged` and `offlineMode` are undefined.

- [ ] **Step 3: `OfflineCheckout`**

Create `lib/features/offline/application/offline_checkout.dart`:

```dart
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
      shiftOfflineRequestId = offline.isSynced ? null : offline.offlineRequestId;
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
```

- [ ] **Step 4: The Savdo bloc in offline mode**

`pos_sale_event.dart`, add:

```dart
/// The app switched online ↔ offline (dispatched by `PosSalePage` from
/// `AppModeCubit`). Reloads the catalog from the right source.
class PosSaleModeChanged extends PosSaleEvent {
  const PosSaleModeChanged(this.offline);

  final bool offline;

  @override
  List<Object?> get props => [offline];
}
```

`pos_sale_state.dart`:
- Add the constructor param `this.offlineMode = false,`, the field with its doc comment `/// Offline mode: sales are queued locally; offline-only plan items show.`, the `copyWith` param `bool? offlineMode` → `offlineMode: offlineMode ?? this.offlineMode,`, and `offlineMode` in `props`.
- Add:

```dart
  /// What this mode may sell: offline-only items (VIP / hourly plans sold
  /// without a QR) exist only in offline mode.
  List<Product> get sellableProducts => offlineMode
      ? products
      : products.where((product) => !product.offlineOnly).toList();
```

- In `categories`, `visibleProducts` and `cartLines`, replace `products` with `sellableProducts`.

`pos_sale_bloc.dart`:
- Imports: `../../../offline/application/offline_checkout.dart`.
- Constructor:

```dart
  PosSaleBloc(
    this._repository,
    this._products,
    this._offlineCheckout, {
    bool offlineMode = false,
  }) : super(PosSaleState(offlineMode: offlineMode)) {
```

  Register `on<PosSaleModeChanged>(_onModeChanged);`, and add the field `final OfflineCheckout _offlineCheckout;`.
- Add the handler:

```dart
  Future<void> _onModeChanged(
    PosSaleModeChanged event,
    Emitter<PosSaleState> emit,
  ) async {
    if (event.offline == state.offlineMode) return;
    final byId = {for (final product in state.products) product.id: product};
    final cart = event.offline
        ? state.cart
        : {
            for (final entry in state.cart.entries)
              if (!(byId[entry.key]?.offlineOnly ?? false))
                entry.key: entry.value,
          };
    emit(state.copyWith(offlineMode: event.offline, cart: cart));
    await _onStarted(const PosSaleStarted(), emit);
  }
```

- In `_onCheckoutRequested`, directly after `emit(state.copyWith(isCheckingOut: true, errorMessage: null));`, insert:

```dart
    if (state.offlineMode) {
      try {
        final sale = await _offlineCheckout.record(
          lines: state.cartLines,
          discount: state.selectedDiscount,
          cashUzs: event.cashUzs,
          cardUzs: event.cardUzs,
        );
        emit(
          state.copyWith(
            isCheckingOut: false,
            cart: const {},
            clearSelectedDiscountId: true,
            lastReceipt: sale.toReceipt(),
          ),
        );
      } on NoShiftForOfflineSaleException {
        emit(
          state.copyWith(
            isCheckingOut: false,
            errorMessage: "Offline savdo uchun ochiq smena yo'q",
          ),
        );
      } on OfflinePaymentShortException {
        emit(
          state.copyWith(
            isCheckingOut: false,
            errorMessage: "To'lov summasi yetarli emas",
          ),
        );
      }
      return;
    }
```

- In `_messageOf`, add `CacheFailure(:final message) => message,` before the `_` arm.

`injector_container.dart` `_posSaleFeature`:

```dart
  sl.registerFactory<PosSaleBloc>(
    () => PosSaleBloc(
      sl(),
      sl(),
      sl(),
      offlineMode: sl<OfflineStore>().isOfflineMode,
    ),
  );
  sl.registerLazySingleton<OfflineCheckout>(() => OfflineCheckout(sl(), sl()));
```

(Import `offline_checkout.dart`.)

- [ ] **Step 5: Run the tests**

Run: `flutter test && flutter analyze`
Expected: all pass; only the baseline analyzer infos.

- [ ] **Step 6: Commit**

```bash
git add lib/features/offline/application/offline_checkout.dart lib/features/pos_sale/presentation/bloc lib/injector_container.dart test/offline_checkout_test.dart test/pos_sale_offline_test.dart
git commit -m "feat(offline): sell and print from the Savdo grid while offline

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Strings, the Unsynced page, and unsynced sales in history

**Files:**
- Modify: `lib/l10n/intl_uz.arb`, `intl_ru.arb`, `intl_en.arb` → regenerate `lib/generated/`
- Modify: `lib/core/theme/nocturne_colors.dart` (add `warning`)
- Create: `lib/features/offline/presentation/widgets/offline_sale_tile.dart`, `lib/features/offline/presentation/widgets/offline_history_section.dart`, `lib/features/offline/presentation/pages/unsynced_sales_page.dart`
- Modify: `lib/features/sales_history/presentation/pages/sales_history_page.dart` (`SalesHistoryPage.build` only)
- Test: `test/unsynced_sales_page_test.dart`

**Interfaces:**
- Consumes: `AppModeCubit`/`AppModeState` (Task 5), `OfflineStore` (Task 2), `OfflineSale` (Task 1)
- Produces:
  - `NocturneColors.warning`
  - `OfflineSaleTile({required OfflineSale sale, VoidCallback? onRetry, String? badgeLabel, bool showSupportDetails = true})`
  - `OfflineHistorySection({required OfflineStore store, required String? cashierId, bool expand = false})`
  - `UnsyncedSalesPage({required OfflineStore store, required String? cashierId})` (reads `AppModeCubit` from context)
  - l10n getters (below)

- [ ] **Step 1: Add the strings**

Add these entries before the closing `}` of `intl_uz.arb` (comma after the previous last entry). The `@`-metadata blocks declare the placeholders:

```json
  "offlinePromptTitle": "Internet aloqasi yo‘q",
  "offlinePromptBody": "Server bilan aloqa uzildi. Offline rejimga o‘tib, savdoni davom ettirasizmi? Savdolar kassada saqlanadi va internet qaytganda serverga yuboriladi.",
  "offlinePromptAccept": "Ha, offline rejim",
  "offlinePromptDecline": "Yo‘q",
  "onlinePromptTitle": "Internet qaytdi",
  "onlinePromptBody": "Onlayn rejimga o‘tib, {count} ta savdoni sinxronlaymizmi?",
  "@onlinePromptBody": { "placeholders": { "count": { "type": "int" } } },
  "onlinePromptAccept": "Ha, sinxronlash",
  "onlinePromptLater": "Keyinroq",
  "offlineBanner": "OFFLINE · {count} ta savdo kutmoqda",
  "@offlineBanner": { "placeholders": { "count": { "type": "int" } } },
  "offlineBannerSyncing": "Sinxronlanmoqda…",
  "checkOnline": "Onlaynni tekshirish",
  "stillOffline": "Hali ham internet yo‘q",
  "syncResultTitle": "Sinxronlash natijasi",
  "syncResultBody": "{synced} ta savdo sinxronlandi, {failed} ta xato.",
  "@syncResultBody": { "placeholders": { "synced": { "type": "int" }, "failed": { "type": "int" } } },
  "syncTransportFailed": "Sinxronlab bo‘lmadi: {reason}. Offline rejim davom etadi.",
  "@syncTransportFailed": { "placeholders": { "reason": { "type": "String" } } },
  "syncViewFailures": "Ko‘rish",
  "needsInternet": "Internet kerak",
  "tabUnsynced": "Sinxronlanmagan",
  "unsyncedEmpty": "Barcha savdolar sinxronlangan",
  "unsyncedHint": "Xato bo‘lgan savdo bo‘yicha qo‘llab-quvvatlashga qo‘ng‘iroq qiling va kodni ayting.",
  "unsyncedPending": "Kutmoqda",
  "unsyncedFailed": "Xato",
  "unsyncedSupportCode": "Kod: {code}",
  "@unsyncedSupportCode": { "placeholders": { "code": { "type": "String" } } },
  "unsyncedCodeCopied": "Kod nusxalandi",
  "unsyncedRetry": "Qayta urinish",
  "unsyncedRetryAll": "Hammasini qayta yuborish",
  "unsyncedRetryNeedsOnline": "Qayta yuborish uchun avval onlayn rejimga o‘ting",
  "notSyncedBadge": "Sinxronlanmagan",
  "historyOfflineNotice": "Offline rejim: faqat hali sinxronlanmagan savdolar ko‘rsatiladi",
  "logoutBlockedUnsynced": "{count} ta savdo sinxronlanmagan. Chiqishdan oldin onlayn rejimda sinxronlang.",
  "@logoutBlockedUnsynced": { "placeholders": { "count": { "type": "int" } } },
  "closeShiftUnsyncedWarning": "{count} ta savdo serverga o‘tmadi (xato). Smenani yopishdan oldin qo‘llab-quvvatlashga murojaat qiling.",
  "@closeShiftUnsyncedWarning": { "placeholders": { "count": { "type": "int" } } },
  "closeShiftOffline": "Offline rejimda smenani yopib bo‘lmaydi"
```

Add the same keys (same placeholders) to `intl_ru.arb`:

```json
  "offlinePromptTitle": "Нет подключения к интернету",
  "offlinePromptBody": "Связь с сервером потеряна. Перейти в офлайн-режим и продолжить продажи? Продажи сохранятся на кассе и отправятся на сервер, когда интернет вернётся.",
  "offlinePromptAccept": "Да, офлайн-режим",
  "offlinePromptDecline": "Нет",
  "onlinePromptTitle": "Интернет вернулся",
  "onlinePromptBody": "Перейти в онлайн-режим и синхронизировать продажи ({count})?",
  "onlinePromptAccept": "Да, синхронизировать",
  "onlinePromptLater": "Позже",
  "offlineBanner": "OFFLINE · ожидают продаж: {count}",
  "offlineBannerSyncing": "Синхронизация…",
  "checkOnline": "Проверить связь",
  "stillOffline": "Интернета всё ещё нет",
  "syncResultTitle": "Результат синхронизации",
  "syncResultBody": "Синхронизировано: {synced}, с ошибкой: {failed}.",
  "syncTransportFailed": "Не удалось синхронизировать: {reason}. Офлайн-режим продолжается.",
  "syncViewFailures": "Открыть",
  "needsInternet": "Нужен интернет",
  "tabUnsynced": "Не синхронизировано",
  "unsyncedEmpty": "Все продажи синхронизированы",
  "unsyncedHint": "По продаже с ошибкой позвоните в поддержку и назовите код.",
  "unsyncedPending": "Ожидает",
  "unsyncedFailed": "Ошибка",
  "unsyncedSupportCode": "Код: {code}",
  "unsyncedCodeCopied": "Код скопирован",
  "unsyncedRetry": "Повторить",
  "unsyncedRetryAll": "Отправить все заново",
  "unsyncedRetryNeedsOnline": "Чтобы отправить заново, перейдите в онлайн-режим",
  "notSyncedBadge": "Не синхронизировано",
  "historyOfflineNotice": "Офлайн-режим: показаны только несинхронизированные продажи",
  "logoutBlockedUnsynced": "Несинхронизированных продаж: {count}. Перед выходом синхронизируйте их в онлайн-режиме.",
  "closeShiftUnsyncedWarning": "Продаж с ошибкой синхронизации: {count}. Перед закрытием смены обратитесь в поддержку.",
  "closeShiftOffline": "В офлайн-режиме смену закрыть нельзя"
```

And to `intl_en.arb`:

```json
  "offlinePromptTitle": "No internet connection",
  "offlinePromptBody": "The connection to the server was lost. Switch to offline mode and keep selling? Sales are saved on this till and sent to the server when the internet is back.",
  "offlinePromptAccept": "Yes, go offline",
  "offlinePromptDecline": "No",
  "onlinePromptTitle": "Internet is back",
  "onlinePromptBody": "Switch to online mode and sync {count} sales?",
  "onlinePromptAccept": "Yes, sync",
  "onlinePromptLater": "Later",
  "offlineBanner": "OFFLINE · {count} sales waiting",
  "offlineBannerSyncing": "Syncing…",
  "checkOnline": "Check connection",
  "stillOffline": "Still no internet",
  "syncResultTitle": "Sync result",
  "syncResultBody": "{synced} sales synced, {failed} failed.",
  "syncTransportFailed": "Could not sync: {reason}. Staying offline.",
  "syncViewFailures": "View",
  "needsInternet": "Needs internet",
  "tabUnsynced": "Unsynced",
  "unsyncedEmpty": "All sales are synced",
  "unsyncedHint": "For a failed sale, call support and read them the code.",
  "unsyncedPending": "Waiting",
  "unsyncedFailed": "Failed",
  "unsyncedSupportCode": "Code: {code}",
  "unsyncedCodeCopied": "Code copied",
  "unsyncedRetry": "Retry",
  "unsyncedRetryAll": "Resend all",
  "unsyncedRetryNeedsOnline": "Switch to online mode to resend",
  "notSyncedBadge": "Not synced",
  "historyOfflineNotice": "Offline mode: only sales not yet synced are shown",
  "logoutBlockedUnsynced": "{count} sales are not synced. Sync them in online mode before signing out.",
  "closeShiftUnsyncedWarning": "{count} sales failed to sync. Contact support before closing the shift.",
  "closeShiftOffline": "A shift can't be closed in offline mode"
```

(In the ru/en files, copy the `@key` placeholder blocks exactly as in uz.)

Run: `dart run intl_utils:generate`
Expected: `lib/generated/intl/messages_*.dart` and `lib/generated/l10n.dart` updated; `flutter analyze` is clean.

In `nocturne_colors.dart`, next to `danger`/`success`, add:

```dart
  /// Offline-mode amber — the banner and "waiting" chips.
  static const Color warning = Color(0xFFF5A524);
```

- [ ] **Step 2: Write the failing widget test**

Create `test/unsynced_sales_page_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:cashier_app/core/connectivity/connectivity_monitor.dart';
import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/features/offline/application/offline_sync_service.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/offline/domain/offline_sale.dart';
import 'package:cashier_app/features/offline/presentation/pages/unsynced_sales_page.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory temp;
  late OfflineStore store;
  late StreamController<ConnectivityEvent> events;
  late List<Set<String>?> retried;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_unsynced_page');
    Hive.init(temp.path);
    store = OfflineStore(await Hive.openBox<dynamic>(OfflineStore.boxName));
    events = StreamController<ConnectivityEvent>.broadcast();
    retried = [];
    await store.putSale(
      OfflineSale(
        offlineRequestId: '35b4fb47-a84f-483f-b73c-44ff6a04be23',
        cashierId: 'cashier-1',
        createdAt: DateTime.utc(2026, 9, 23, 10, 15),
        shiftId: 'shift-1',
        lines: const [OfflineSaleLine(productId: 'vip', name: 'VIP', priceUzs: 75000, qty: 2)],
        cashUzs: 150000,
        cardUzs: 0,
      ).markFailed(code: 'PRODUCT_NOT_FOUND', message: 'Mahsulot topilmadi', at: DateTime.utc(2026, 9, 23, 12)),
    );
  });

  tearDown(() async {
    await events.close();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  Future<AppModeCubit> pump(WidgetTester tester, {required bool offline}) async {
    await store.setOfflineMode(offline);
    final cubit = AppModeCubit(
      connectivity: events.stream,
      checkNow: () async => true,
      store: store,
      sync: ({Set<String>? onlyIds, bool includeFailed = false}) async {
        retried.add(onlyIds);
        return SyncReport.empty;
      },
      currentCashierId: () => 'cashier-1',
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalization.delegate],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: UnsyncedSalesPage(store: store, cashierId: 'cashier-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('shows the failed sale with its reason and support code', (tester) async {
    await pump(tester, offline: false);

    expect(find.text('Mahsulot topilmadi'), findsOneWidget);
    expect(find.textContaining('35b4fb47'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
  });

  testWidgets('retry resends that sale when online', (tester) async {
    await pump(tester, offline: false);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(retried, [{'35b4fb47-a84f-483f-b73c-44ff6a04be23'}]);
  });

  testWidgets('retry is disabled offline', (tester) async {
    await pump(tester, offline: true);

    // OutlinedButton.icon builds a private subclass, which find.byType misses.
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Retry'),
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Switch to online mode to resend'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/unsynced_sales_page_test.dart`
Expected: compile error, because `unsynced_sales_page.dart` doesn't exist.

- [ ] **Step 4: The sale tile**

Create `lib/features/offline/presentation/widgets/offline_sale_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/offline_sale.dart';

/// One queued offline sale — used by the Unsynced page (with Retry and the
/// support code) and by the history section (with a "not synced" badge).
class OfflineSaleTile extends StatelessWidget {
  const OfflineSaleTile({
    super.key,
    required this.sale,
    this.onRetry,
    this.badgeLabel,
    this.showSupportDetails = true,
    this.retryEnabled = true,
  });

  final OfflineSale sale;
  final VoidCallback? onRetry;

  /// Overrides the pending/failed chip (history shows "Sinxronlanmagan").
  final String? badgeLabel;
  final bool showSupportDetails;

  /// False renders Retry disabled (offline) instead of hiding it.
  final bool retryEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final chipColor = sale.isFailed ? NocturneColors.danger : NocturneColors.warning;
    final chipText =
        badgeLabel ?? (sale.isFailed ? l10n.unsyncedFailed : l10n.unsyncedPending);
    final items = sale.lines.map((l) => '${l.name} ×${l.qty}').join(', ');
    final payment = [
      if (sale.cashUzs > 0) l10n.paymentCash,
      if (sale.cardUzs > 0) l10n.paymentCard,
    ].join(' + ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: chipColor.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(sale.createdAt.toLocal()),
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        chipText,
                        style: AppTextStyles.body.copyWith(fontSize: 11, color: chipColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(items, style: AppTextStyles.body),
                if (showSupportDetails) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SelectableText(
                        l10n.unsyncedSupportCode(sale.supportCode),
                        style: AppTextStyles.body.copyWith(fontFamily: 'monospace'),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        icon: const Icon(PhosphorIconsRegular.copy),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: sale.supportCode));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.unsyncedCodeCopied)),
                          );
                        },
                      ),
                    ],
                  ),
                ],
                if (sale.isFailed && sale.failureMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    sale.failureMessage!,
                    style: AppTextStyles.body.copyWith(color: NocturneColors.danger),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatUzs(sale.totalUzs),
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(payment, style: AppTextStyles.body.copyWith(fontSize: 11)),
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: retryEnabled ? onRetry : null,
                  icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 14),
                  label: Text(l10n.unsyncedRetry),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: The Unsynced page**

Create `lib/features/offline/presentation/pages/unsynced_sales_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/offline/app_mode_cubit.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../generated/l10n.dart';
import '../../data/offline_store.dart';
import '../../domain/offline_sale.dart';
import '../widgets/offline_sale_tile.dart';

/// Every sale of this cashier still on the till (spec D11): waiting or
/// rejected, with the reason and a code to read to support. Failed rows are
/// never deleted from here — only a successful Retry removes them.
class UnsyncedSalesPage extends StatelessWidget {
  const UnsyncedSalesPage({super.key, required this.store, required this.cashierId});

  final OfflineStore store;
  final String? cashierId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return BlocBuilder<AppModeCubit, AppModeState>(
      buildWhen: (previous, current) => previous.mode != current.mode,
      builder: (context, mode) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final sales = cashierId == null
              ? const <OfflineSale>[]
              : store.sales(cashierId: cashierId).reversed.toList();
          if (sales.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PhosphorIconsRegular.cloudCheck, size: 40, color: NocturneColors.success),
                  const SizedBox(height: 8),
                  Text(l10n.unsyncedEmpty, style: AppTextStyles.h5),
                ],
              ),
            );
          }
          final online = !mode.isOffline;
          final cubit = context.read<AppModeCubit>();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        online ? l10n.unsyncedHint : l10n.unsyncedRetryNeedsOnline,
                        style: AppTextStyles.body,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: online ? () => cubit.retry() : null,
                      icon: const Icon(PhosphorIconsRegular.cloudArrowUp, size: 16),
                      label: Text(l10n.unsyncedRetryAll),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: sales.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      return OfflineSaleTile(
                        sale: sale,
                        retryEnabled: online,
                        onRetry: () => cubit.retry(ids: {sale.offlineRequestId}),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

(If `AppTextStyles.h5` doesn't exist in this form, use `AppTextStyles.h4`. The available styles are `body h1..h6 kicker`.)

- [ ] **Step 6: The history section**

Create `lib/features/offline/presentation/widgets/offline_history_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../generated/l10n.dart';
import '../../data/offline_store.dart';
import '../../domain/offline_sale.dart';
import 'offline_sale_tile.dart';

/// Queued offline sales at the top of the history tab (spec D9), badged
/// "Sinxronlanmagan". [expand]: offline, this IS the whole history.
class OfflineHistorySection extends StatelessWidget {
  const OfflineHistorySection({
    super.key,
    required this.store,
    required this.cashierId,
    this.expand = false,
  });

  final OfflineStore store;
  final String? cashierId;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final sales = cashierId == null
            ? const <OfflineSale>[]
            : store.sales(cashierId: cashierId).reversed.toList();
        if (sales.isEmpty && !expand) return const SizedBox.shrink();
        final list = ListView.separated(
          shrinkWrap: !expand,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          itemCount: sales.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, index) => OfflineSaleTile(
            sale: sales[index],
            badgeLabel: l10n.notSyncedBadge,
            showSupportDetails: false,
          ),
        );
        final header = Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(PhosphorIconsRegular.cloudArrowUp, size: 16, color: NocturneColors.warning),
              const SizedBox(width: 6),
              Text(
                '${l10n.notSyncedBadge} (${sales.length})',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
        return expand
            ? Column(children: [header, Expanded(child: list)])
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  header,
                  ConstrainedBox(constraints: const BoxConstraints(maxHeight: 240), child: list),
                ],
              );
      },
    );
  }
}
```

- [ ] **Step 7: Put it in the history tab**

In `sales_history_page.dart`, change `SalesHistoryPage.build`'s `child: _SalesHistoryView(onOpenCustomer: onOpenCustomer),` to `child: _OfflineAwareHistory(onOpenCustomer: onOpenCustomer),` and add at the end of the file:

```dart
/// Offline: only the queued sales (server history can't load). Online: the
/// queued ones on top, then server history as before.
class _OfflineAwareHistory extends StatelessWidget {
  const _OfflineAwareHistory({required this.onOpenCustomer});

  final ValueChanged<Customer> onOpenCustomer;

  @override
  Widget build(BuildContext context) {
    final store = sl<OfflineStore>();
    final cashierId = sl<LocalSource>().getCashierId();
    return BlocBuilder<AppModeCubit, AppModeState>(
      buildWhen: (previous, current) => previous.isOffline != current.isOffline,
      builder: (context, mode) {
        if (mode.isOffline) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  AppLocalization.of(context).historyOfflineNotice,
                  style: AppTextStyles.body.copyWith(color: NocturneColors.warning),
                ),
              ),
              Expanded(
                child: OfflineHistorySection(store: store, cashierId: cashierId, expand: true),
              ),
            ],
          );
        }
        return Column(
          children: [
            OfflineHistorySection(store: store, cashierId: cashierId),
            Expanded(child: _SalesHistoryView(onOpenCustomer: onOpenCustomer)),
          ],
        );
      },
    );
  }
}
```

Add the imports: `app_mode_cubit.dart`, `offline_store.dart`, `offline_history_section.dart`, `local_source.dart`, and `app_text_styles.dart`/`nocturne_colors.dart` if missing. Refund/edit never reach queued sales, because they're rendered by `OfflineSaleTile`, which has no such actions.

- [ ] **Step 8: Run the tests**

Run: `flutter test && flutter analyze`
Expected: all pass (including the 3 new widget tests); only the baseline analyzer infos.

- [ ] **Step 9: Commit**

```bash
git add lib/l10n lib/generated lib/core/theme lib/features/offline/presentation lib/features/sales_history/presentation/pages/sales_history_page.dart test/unsynced_sales_page_test.dart
git commit -m "feat(offline): unsynced-sales page with support code and retry; show them in history

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Wire it into the app (prompts, banner, sidebar, guards)

**Files:**
- Create: `lib/core/offline/widgets/mode_prompt_host.dart`, `lib/core/offline/widgets/offline_banner.dart`
- Modify: `lib/injector_container.dart`, `lib/main.dart`, `lib/app.dart`
- Modify: `lib/features/shell/presentation/model/shell_tab.dart`, `widgets/sidebar.dart`, `pages/shell_page.dart`, `widgets/close_shift_dialog.dart`
- Modify: `lib/features/pos_sale/presentation/pages/pos_sale_page.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
- Test: `test/sidebar_offline_test.dart`, `test/mode_prompt_host_test.dart`

**Interfaces:**
- Consumes: everything above
- Produces:
  - `ShellTab.unsynced`, `ShellTab.primary` (every tab except `unsynced`), `bool ShellTab.needsInternet` (`posAccount`, `visitHistory`, `inside`)
  - `Sidebar({…, List<ShellTab> tabs = ShellTab.primary, Set<ShellTab> disabledTabs = const {}, Map<ShellTab, int> counts = const {}})`. A disabled tile doesn't respond to taps and shows the "Internet kerak" tooltip. A count > 0 renders a pill keyed `Key('nav-count-<tab>')`.
  - `ModePromptHost({required Widget child, VoidCallback? onShowUnsynced})`, `OfflineBanner()`
  - DI: `ConnectivityMonitor`, `OfflineSyncRemoteDataSource`, `OfflineSyncService`, and `AppModeCubit` (lazy singletons)

- [ ] **Step 1: Write the failing widget tests**

Create `test/sidebar_offline_test.dart`:

```dart
import 'package:cashier_app/features/shell/presentation/model/shell_tab.dart';
import 'package:cashier_app/features/shell/presentation/widgets/sidebar.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline, internet-only tabs ignore taps; the unsynced tab shows its count', (tester) async {
    final tapped = <ShellTab>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalization.delegate],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Row(
            children: [
              Sidebar(
                selected: ShellTab.posSale,
                collapsed: false,
                onToggle: () {},
                onSelect: tapped.add,
                cashierName: 'Zaira',
                shiftOpenedAt: DateTime(2026, 9, 23, 9),
                onCloseShift: null,
                updateAvailable: ValueNotifier(false),
                tabs: const [...ShellTab.primary, ShellTab.unsynced],
                disabledTabs: {for (final t in ShellTab.values) if (t.needsInternet) t},
                counts: const {ShellTab.unsynced: 3},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalization.current;

    await tester.tap(find.text(l10n.tabAccount));
    await tester.tap(find.text(l10n.tabSales));
    await tester.tap(find.text(l10n.tabUnsynced));

    expect(tapped, [ShellTab.posSale, ShellTab.unsynced]);
    expect(find.byKey(const Key('nav-count-unsynced')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
```

Create `test/mode_prompt_host_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:cashier_app/core/connectivity/connectivity_monitor.dart';
import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/core/offline/widgets/mode_prompt_host.dart';
import 'package:cashier_app/features/offline/application/offline_sync_service.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory temp;
  late OfflineStore store;
  late StreamController<ConnectivityEvent> events;
  late AppModeCubit cubit;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_prompt_host');
    Hive.init(temp.path);
    store = OfflineStore(await Hive.openBox<dynamic>(OfflineStore.boxName));
    events = StreamController<ConnectivityEvent>.broadcast();
    cubit = AppModeCubit(
      connectivity: events.stream,
      checkNow: () async => true,
      store: store,
      sync: ({Set<String>? onlyIds, bool includeFailed = false}) async =>
          const SyncReport(syncedCount: 2),
      currentCashierId: () => 'cashier-1',
    );
  });

  tearDown(() async {
    await cubit.close();
    await events.close();
    await Hive.close();
    await temp.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalization.delegate],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        locale: const Locale('en'),
        home: BlocProvider.value(
          value: cubit,
          child: const ModePromptHost(child: Scaffold(body: Text('till'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an outage asks before going offline', (tester) async {
    await pump(tester);

    events.add(const ConnectivityEvent(reachable: false, fromUserRequest: true));
    await tester.pumpAndSettle();
    expect(find.text('No internet connection'), findsOneWidget);

    await tester.tap(find.text('Yes, go offline'));
    await tester.pumpAndSettle();
    expect(cubit.state.mode, AppMode.offline);
    expect(find.text('No internet connection'), findsNothing);
  });

  testWidgets('declining keeps the till online', (tester) async {
    await pump(tester);

    events.add(const ConnectivityEvent(reachable: false, fromUserRequest: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(cubit.state.mode, AppMode.online);
  });

  testWidgets('back online: confirm, sync, then show the result', (tester) async {
    await store.setOfflineMode(true);
    cubit.close();
    cubit = AppModeCubit(
      connectivity: events.stream,
      checkNow: () async => true,
      store: store,
      sync: ({Set<String>? onlyIds, bool includeFailed = false}) async =>
          const SyncReport(syncedCount: 2),
      currentCashierId: () => 'cashier-1',
    );
    await pump(tester);

    events.add(const ConnectivityEvent(reachable: true));
    await tester.pumpAndSettle();
    expect(find.text('Internet is back'), findsOneWidget);

    await tester.tap(find.text('Yes, sync'));
    await tester.pumpAndSettle();

    expect(cubit.state.mode, AppMode.online);
    expect(find.text('2 sales synced, 0 failed.'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/sidebar_offline_test.dart test/mode_prompt_host_test.dart`
Expected: compile errors: no `tabs`/`disabledTabs`/`counts` params, no `ShellTab.unsynced`, no `mode_prompt_host.dart`.

- [ ] **Step 3: Tabs and sidebar**

`shell_tab.dart`: append `unsynced(icon: PhosphorIconsRegular.cloudArrowUp);` as the last value (replace the `;` after `settings(...)` with `,`), and add inside the enum:

```dart
  /// Always-present tabs; [unsynced] appears only while sales are queued.
  static const List<ShellTab> primary = [
    posAccount,
    posSale,
    salesHistory,
    visitHistory,
    inside,
    settings,
  ];

  /// Tabs that can't work without the server — disabled in offline mode.
  bool get needsInternet => switch (this) {
    ShellTab.posAccount || ShellTab.visitHistory || ShellTab.inside => true,
    _ => false,
  };
```

Add `ShellTab.unsynced => l10n.tabUnsynced,` to `label`. Then run `grep -rn "switch (tab\|ShellTab\." lib` and add an `unsynced` arm to any other exhaustive switch the analyzer flags (e.g. in `header_bar.dart`).

`sidebar.dart`:
- Add the constructor params `this.tabs = ShellTab.primary, this.disabledTabs = const {}, this.counts = const {},` and their fields (`final List<ShellTab> tabs; final Set<ShellTab> disabledTabs; final Map<ShellTab, int> counts;`).
- Change `for (final tab in ShellTab.values)` to `for (final tab in tabs)`, and pass `disabled: disabledTabs.contains(tab), count: counts[tab] ?? 0,` to `_NavTile`.
- `_NavTile`: add `this.disabled = false, this.count = 0,` and their fields. In `build`:
  - `InkWell(onTap: disabled ? null : onTap, …)`.
  - Wrap the `Padding` returned as `tile` in `Opacity(opacity: disabled ? .38 : 1, child: …)`.
  - After the label `Expanded(...)` inside `if (!collapsed) ...[`, add:

```dart
                  if (count > 0)
                    Container(
                      key: Key('nav-count-${tab.name}'),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: NocturneColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: NocturneColors.bg,
                        ),
                      ),
                    ),
```

  - Replace the final `return collapsed ? Tooltip(...) : tile;` with:

```dart
    final l10n = AppLocalization.of(context);
    if (disabled) return Tooltip(message: l10n.needsInternet, child: tile);
    return collapsed ? Tooltip(message: tab.label(l10n), child: tile) : tile;
```

Existing `test/sidebar_update_badge_test.dart` must still pass unchanged. Its default `tabs` exclude `unsynced`, so no badge key renders for it.

- [ ] **Step 4: The prompt host and the banner**

Create `lib/core/offline/widgets/mode_prompt_host.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../features/offline/application/offline_sync_service.dart';
import '../../../generated/l10n.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/nocturne_colors.dart';
import '../app_mode_cubit.dart';

/// Renders [AppModeCubit]'s prompts as confirm dialogs and shows each sync
/// result once. Lives in the shell so dialogs only appear to a signed-in
/// cashier; a prompt raised earlier (e.g. on the login screen) is shown as
/// soon as the shell mounts.
class ModePromptHost extends StatefulWidget {
  const ModePromptHost({super.key, required this.child, this.onShowUnsynced});

  final Widget child;
  final VoidCallback? onShowUnsynced;

  @override
  State<ModePromptHost> createState() => _ModePromptHostState();
}

class _ModePromptHostState extends State<ModePromptHost> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handle(context.read<AppModeCubit>().state),
    );
  }

  Future<void> _handle(AppModeState state) async {
    if (_open || !mounted) return;
    final cubit = context.read<AppModeCubit>();
    final l10n = AppLocalization.of(context);
    switch (state.prompt) {
      case ModePrompt.goOffline:
        final yes = await _confirm(
          icon: PhosphorIconsRegular.wifiSlash,
          title: l10n.offlinePromptTitle,
          body: l10n.offlinePromptBody,
          accept: l10n.offlinePromptAccept,
          decline: l10n.offlinePromptDecline,
        );
        if (yes) {
          await cubit.acceptOffline();
        } else {
          cubit.declineOffline();
        }
      case ModePrompt.goOnline:
        final yes = await _confirm(
          icon: PhosphorIconsRegular.cloudArrowUp,
          title: l10n.onlinePromptTitle,
          body: l10n.onlinePromptBody(state.queuedCount),
          accept: l10n.onlinePromptAccept,
          decline: l10n.onlinePromptLater,
        );
        if (yes) {
          await cubit.acceptOnline();
        } else {
          cubit.postponeOnline();
        }
      case ModePrompt.none:
        final report = state.lastReport;
        if (report == null) return;
        cubit.reportShown();
        if (report.syncedCount == 0 && report.failed.isEmpty && !report.transportFailed) {
          return;
        }
        await _showReport(report);
    }
  }

  Future<bool> _confirm({
    required IconData icon,
    required String title,
    required String body,
    required String accept,
    required String decline,
  }) async {
    _open = true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NocturneColors.surface,
        icon: Icon(icon, color: NocturneColors.warning, size: 32),
        title: Text(title, style: AppTextStyles.h4),
        content: SizedBox(width: 360, child: Text(body, style: AppTextStyles.body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(decline),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(accept),
          ),
        ],
      ),
    );
    _open = false;
    return result ?? false;
  }

  Future<void> _showReport(SyncReport report) async {
    _open = true;
    final l10n = AppLocalization.of(context);
    final showFailures = report.failed.isNotEmpty && widget.onShowUnsynced != null;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NocturneColors.surface,
        title: Text(l10n.syncResultTitle, style: AppTextStyles.h4),
        content: Text(
          report.transportFailed
              ? l10n.syncTransportFailed(report.transportError!)
              : l10n.syncResultBody(report.syncedCount, report.failed.length),
          style: AppTextStyles.body,
        ),
        actions: [
          if (showFailures)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onShowUnsynced!();
              },
              child: Text(l10n.syncViewFailures),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
    _open = false;
    if (mounted) _handle(context.read<AppModeCubit>().state);
  }

  @override
  Widget build(BuildContext context) => BlocListener<AppModeCubit, AppModeState>(
    listenWhen: (previous, current) =>
        previous.prompt != current.prompt || previous.lastReport != current.lastReport,
    listener: (_, state) => _handle(state),
    child: widget.child,
  );
}
```

Create `lib/core/offline/widgets/offline_banner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../generated/l10n.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/nocturne_colors.dart';
import '../app_mode_cubit.dart';

/// Amber strip above the header whenever the till isn't online: how many
/// sales wait, and the manual "Onlaynni tekshirish" button (spec D12).
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    final reachable = await context.read<AppModeCubit>().checkOnlineNow();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!reachable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalization.of(context).stillOffline)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return BlocBuilder<AppModeCubit, AppModeState>(
      builder: (context, state) {
        if (!state.isOffline) return const SizedBox.shrink();
        final syncing = state.mode == AppMode.syncing;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: NocturneColors.warning.withValues(alpha: .14),
            border: const Border(bottom: BorderSide(color: NocturneColors.warning)),
          ),
          child: Row(
            children: [
              syncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: NocturneColors.warning),
                    )
                  : const Icon(PhosphorIconsRegular.wifiSlash, size: 16, color: NocturneColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  syncing ? l10n.offlineBannerSyncing : l10n.offlineBanner(state.queuedCount),
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: NocturneColors.warning),
                ),
              ),
              if (!syncing)
                TextButton.icon(
                  onPressed: _checking ? null : _check,
                  icon: _checking
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(PhosphorIconsRegular.arrowClockwise, size: 16),
                  label: Text(l10n.checkOnline),
                ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 5: DI, `main`, `App`**

`injector_container.dart`:
- Before `sl.registerLazySingleton<Dio>(...)`, add:

```dart
  sl.registerLazySingleton<ConnectivityMonitor>(
    () => ConnectivityMonitor(
      probe: httpHealthProbe(
        () => sl<LocalSource>().getApiBaseUrl() ?? AppConstants.defaultApiBaseUrl,
      ),
    ),
  );
```

- Change the Dio registration to `() => buildDio(sl(), sl(), onConnectionFailure: sl<ConnectivityMonitor>().reportRequestFailure)`.
- Add `_offlineFeature();` to `init()`, after `_authFeature();`:

```dart
void _offlineFeature() {
  sl.registerLazySingleton<OfflineSyncRemoteDataSource>(
    () => OfflineSyncRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<OfflineSyncService>(
    () => OfflineSyncService(sl(), sl(), () => sl<LocalSource>().getCashierId()),
  );
  // App-wide, like the connection itself — survives login/logout routes.
  sl.registerLazySingleton<AppModeCubit>(
    () => AppModeCubit(
      connectivity: sl<ConnectivityMonitor>().events,
      checkNow: sl<ConnectivityMonitor>().checkNow,
      store: sl(),
      sync: sl<OfflineSyncService>().sync,
      currentCashierId: () => sl<LocalSource>().getCashierId(),
    ),
  );
}
```

- Add the imports: `constants/app_constants.dart`, `core/connectivity/connectivity_monitor.dart`, `core/offline/app_mode_cubit.dart`, the offline data and application files.

`main.dart`: after `di.sl<UpdateService>().startBackgroundChecks();`, add `di.sl<ConnectivityMonitor>().start();` (with the import).

`app.dart`: replace `BlocProvider(create: (_) => sl<LocaleCubit>(), child: …)` with:

```dart
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<LocaleCubit>()),
        // `.value`: the singleton outlives this widget; never closed here.
        BlocProvider<AppModeCubit>.value(value: sl<AppModeCubit>()),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
```

(Keep the rest of the tree identical; import `core/offline/app_mode_cubit.dart`.)

- [ ] **Step 6: The shell**

In `shell_page.dart`, `_ShellViewState` (the state of `_ShellView`, which already sits under `ShellPage`'s `BlocProvider<ShiftBloc>`):
- Add:

```dart
  @override
  void initState() {
    super.initState();
    // Queue counts belong to whoever just signed in.
    context.read<AppModeCubit>().refreshCounts();
  }
```

- At the top of `build`, before `return`, compute:

```dart
    final mode = context.watch<AppModeCubit>().state;
    final tabs = [
      ...ShellTab.primary,
      if (mode.queuedCount > 0 || _tab == ShellTab.unsynced) ShellTab.unsynced,
    ];
    final disabled = mode.isOffline
        ? {for (final tab in ShellTab.values) if (tab.needsInternet) tab}
        : const <ShellTab>{};
    final tab = disabled.contains(_tab) ? ShellTab.posSale : _tab;
```

- Change `return Scaffold(` so the existing `Scaffold` becomes the innermost child of two wrappers. The `Scaffold`'s own contents stay as they are, apart from the edits listed below:

```dart
    return BlocListener<AppModeCubit, AppModeState>(
      // Online again (after sync) → load the real server shift; offline →
      // switch the shift source to the cache / offline shift.
      listenWhen: (previous, current) => previous.isOffline != current.isOffline,
      listener: (context, _) =>
          context.read<ShiftBloc>().add(const ShiftRefreshed()),
      child: ModePromptHost(
        onShowUnsynced: () => setState(() => _tab = ShellTab.unsynced),
        child: Scaffold(
          // … existing Scaffold arguments …
        ),
      ),
    );
```

- Inside the `Scaffold`:
  - Use `tab` (not `_tab`) for `Sidebar.selected`, `HeaderBar(tab:)` and `_TabContent(tab:)`.
  - Pass `tabs: tabs, disabledTabs: disabled, counts: {ShellTab.unsynced: mode.queuedCount}` to `Sidebar`.
  - Pass `onCloseShift: mode.isOffline ? null : () => showCloseShiftDialog(context, state.shift!)`.
  - In the body `Column`, after `const Divider(height: 1),`, add `const OfflineBanner(),`.
- `_TabContent`: add `ShellTab.unsynced => UnsyncedSalesPage(store: sl<OfflineStore>(), cashierId: sl<LocalSource>().getCashierId()),`.
- Imports: `app_mode_cubit.dart`, `mode_prompt_host.dart`, `offline_banner.dart`, `unsynced_sales_page.dart`, `offline_store.dart`.

- [ ] **Step 7: Savdo reacts to mode changes**

In `pos_sale_page.dart`, change `child: Padding(` inside the `BlocProvider` to:

```dart
      child: BlocListener<AppModeCubit, AppModeState>(
        listenWhen: (previous, current) => previous.isOffline != current.isOffline,
        listener: (context, mode) =>
            context.read<PosSaleBloc>().add(PosSaleModeChanged(mode.isOffline)),
        child: Padding(
```

(close the extra parenthesis; import `app_mode_cubit.dart`).

- [ ] **Step 8: Guards — logout and close shift**

`settings_page.dart`, at the top of `_logout`:

```dart
    final queued = context.read<AppModeCubit>().state.queuedCount;
    if (queued > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalization.of(context).logoutBlockedUnsynced(queued))),
      );
      return;
    }
```

(import `app_mode_cubit.dart`.)

In `close_shift_dialog.dart`, inside the content `Column` after the `shiftTotalIncome` row, add:

```dart
                  if (context.read<AppModeCubit>().state.failedCount case final failed when failed > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        l10n.closeShiftUnsyncedWarning(failed),
                        style: AppTextStyles.body.copyWith(color: NocturneColors.warning),
                      ),
                    ),
                  // Shows OFFLINE_SALES_PENDING (and any other close error),
                  // which used to fail silently in this dialog.
                  BlocBuilder<ShiftBloc, ShiftState>(
                    builder: (context, state) => state.errorMessage == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              state.errorMessage!,
                              style: AppTextStyles.body.copyWith(color: NocturneColors.danger),
                            ),
                          ),
                  ),
```

(`context` here is the dialog builder's; `AppModeCubit` is provided above `MaterialApp`, so it resolves. Import `app_mode_cubit.dart`.)

- [ ] **Step 9: Run everything**

Run: `flutter test && flutter analyze`
Expected: all tests pass (183 baseline + every new test); only the 4 baseline analyzer infos.

- [ ] **Step 10: Commit**

```bash
git add lib test
git commit -m "feat(offline): confirm-first mode switching, offline banner, gated sidebar, sync guards

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: End-to-end verification on a real build

- [ ] **Step 1:** `flutter test`, `flutter analyze`, and `flutter build macos --debug`. Expected: all green; report the test count.
- [ ] **Step 2:** Plan 1 must be deployed to `development` (the test API) first. In the Dashboard (Plan 2, or the admin API directly), create "VIP" 75 000 and "Soatlik" 60 000 with **Faqat offline rejimda** on the cashier's test branch.
- [ ] **Step 3:** Run the app against the test API (`flutter run -d macos --dart-define=API_BASE_URL=https://test.api.pixelpark.uz/api`), log in, open a shift, and open Savdo. Expected: VIP/Soatlik are **not** in the grid.
- [ ] **Step 4:** Turn Wi-Fi off. Expected: within ~30 s (or right after a tap that makes a request), the "Internet aloqasi yo‘q" modal appears. Press **Yo‘q** and confirm the app stays online and the modal doesn't loop. Trigger a request again, then accept.
- [ ] **Step 5:** Offline:
  - Check that the banner shows, and that Hisob, Tashrif tarixi and Ichkarida are disabled.
  - Sell 2× VIP + 1 regular product with a discount. The receipt prints with `OFFLINE`.
  - Tarix shows the sale as "Sinxronlanmagan", and the Sinxronlanmagan tab shows a count of 1.
- [ ] **Step 6:** Quit and relaunch while still offline. Expected: the app starts in offline mode with the cached catalog and shift, and the queued sale is still there.
- [ ] **Step 7:** Turn Wi-Fi on. Expected: the "Internet qaytdi" modal appears. Accept it and check:
  - the sync result reads "1 ta savdo sinxronlandi, 0 ta xato";
  - the banner is gone and the Sinxronlanmagan tab has disappeared;
  - the sale is in Tarix from the server, and in the Dashboard sales list with an "Offline" badge and the real time it was rung up.
- [ ] **Step 8:** Rejection path. Go offline, sell, then disable the product's branch assignment. If that isn't possible, use a DB or test-API trick agreed with the user, or skip this step and say so. Go online and check that the sale shows as "Xato" with the reason and a support code, and that Retry works once fixed.
- [ ] **Step 9:** Report the results to the user, with screenshots from Steps 5 and 7. Don't push or merge until they confirm. Merging `feat/offline-mode` into `main` releases to every till.
