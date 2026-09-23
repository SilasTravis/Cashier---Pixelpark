# Cashier offline mode — design

**Date:** 2026-09-23
**Repos:** `cashier_app` (main work), `maestro_backend`, `Dashboard`
**Status:** approved 2026-09-23; plans in `docs/superpowers/plans/2026-09-23-offline-mode-{1-backend,2-dashboard,3-cashier}.md`

## Goal

When the internet drops, the cashier keeps selling from the product grid. Sales
print as normal receipts, queue locally, and sync to the backend once the
connection is back. VIP and hourly plans normally mint a QR and so need the
server. Offline, they're sold as plain products and printed as a normal
product receipt.

## Revisions made during planning

Code reading during planning changed these points. Where they disagree with the sections below, these win:

1. **`GET /v1/pos/products?includeOffline=true`.** Offline-only rows are returned only when the terminal asks for them. An older cashier build therefore never shows "VIP" online, which would hit `PRODUCT_OFFLINE_ONLY` at checkout.
2. **A shift reference on every sale.** The sync payload takes `shifts: [...]` (usually 0–1 entries) instead of a single `shift`, and every sale names either `shiftId` (the cached server shift) or `shiftOfflineRequestId`. A sale retried days later then lands on the shift it was actually rung under, not whichever shift happens to be open at retry time.
3. **Closed shifts accept their own sales.** A sale can land on a shift that has since closed; `createdAt` is clamped to `[shift.openedAt, shift.closedAt ?? now]`.
4. **Closing a shift.** It's blocked while that cashier has *pending* queued sales. With only *failed* ones, the close dialog warns but allows it, so one bad row can't trap the cashier.
5. **The close-shift dialog now shows `ShiftBloc.errorMessage`.** It used to swallow close errors silently.

## Decisions (from brainstorming)

| # | Decision |
|---|----------|
| D1 | The backend is in scope: a dedicated sync endpoint with idempotency and the real sale time. |
| D2 | Offline plans are ordinary catalog `Product` rows with an `offlineOnly` flag, created in the Dashboard. |
| D3 | A synced offline plan sale is a money record only: no pass, no QR, no child. |
| D4 | The app detects an outage from a failed request **and** from a background health poll. |
| D5 | Offline, the cashier sells cached products (including offline-only ones) and applies cached discounts. Cash and card only. |
| D6 | If a discount was valid when the offline sale was rung up, sync honours it even if it has been disabled since. |
| D7 | Offline sales attach to the cached open shift. If there's none, a shift is opened offline and created **first** on sync. |
| D8 | The last product catalog (plus discounts and the shift) is cached, so it survives an app restart. |
| D9 | History works offline and shows unsynced sales with a "not synced" badge. After sync they're ordinary server sales. |
| D10 | Sync is per sale: good ones go through, rejected ones are shown and kept. |
| D11 | An "Unsynced sales" page lists failures with a support code and a Retry button. |
| D12 | Offline mode has a "Check online" button. |
| D13 | If the cashier declines the offline modal, the app stays online and offers again on the next failed action. It never re-asks in a loop. |

## Part 1 — Backend (`maestro_backend`)

### Schema (one migration)

```prisma
model Product { ... offlineOnly      Boolean   @default(false) @map("offline_only") }
model Sale    { ... offlineRequestId String?   @unique @map("offline_request_id") @db.Uuid
                    offlineSyncedAt  DateTime? @map("offline_synced_at") @db.Timestamptz(6) }
model Shift   { ... offlineRequestId String?   @unique @map("offline_request_id") @db.Uuid }
```

### Products

- `offlineOnly` is added to the entity, the mappers, the admin create/update
  DTOs, and the admin and POS responses.
- `GET /v1/pos/products` also returns offline-only rows, flagged. The cashier
  app filters by mode.
- Online checkout (`POST /v1/pos/sales` and plan-entry-checkout) **rejects** an
  offline-only product with `PRODUCT_OFFLINE_ONLY`, so a stale client can't
  sell one online.

### `POST /v1/pos/offline/sync` (cashier JWT)

Request:

```jsonc
{
  "shift": { "offlineRequestId": "uuid", "openedAt": "iso", "openingCashUzs": 0 }, // or null
  "sales": [{
    "offlineRequestId": "uuid",
    "createdAt": "iso",              // when the cashier rang it up
    "lines": [{ "productId": "uuid", "qty": 2, "priceSnapshotUzs": 75000 }],
    "discount": { "id": "uuid", "kind": "percent", "value": 10 },  // or null
    "cashUzs": 150000,
    "cardUzs": 0
  }]
}
```

Response:

```jsonc
{
  "shift": { "offlineRequestId": "uuid", "status": "created|duplicate|rejected", "shiftId": "uuid", "code": null },
  "sales": [{ "offlineRequestId": "uuid", "status": "created|duplicate|rejected",
              "saleId": "uuid", "code": "…", "message": { "uz": "…", "ru": "…", "en": "…" } }]
}
```

Rules:

1. **Shift first.** If the payload has a `shift`:
   - a row with that `offlineRequestId` already exists → `duplicate`;
   - otherwise, the cashier already has an open shift → reuse it (sales attach
     there, status `duplicate`, and the response returns its id);
   - otherwise, create it with the client's `openedAt`, clamped to no later
     than now.

   With no `shift` in the payload, sales attach to the cashier's current open
   shift. If none is open, every sale is `rejected` with `SHIFT_NOT_OPEN`.
2. **Idempotency.** A sale whose `offlineRequestId` already exists returns
   `duplicate` with the existing `saleId`, and nothing is written. The unique
   index also catches concurrent retries.
3. **Trust the paper, verify the arithmetic.** Lines are recorded at
   `priceSnapshotUzs`, and the discount is applied from the payload's
   `kind`/`value` (then snapshotted, like online sales). That's what makes D6
   work, and it keeps the database identical to the printed receipt. The
   server still enforces:
   - cashier and branch come from the JWT, never from the payload;
   - every `productId` exists and belongs to the cashier's branch (`active` is
     *not* required, because the product may have been disabled during the
     outage);
   - `discount.id` exists and has scope `goods` (`active` not required);
   - the lines aren't empty, `qty ≥ 1`, price ≥ 0, and `cash + card ≥ net`.
4. **Real time.** `createdAt` is the client's time, clamped to
   `[shift.openedAt, now]`. `offlineSyncedAt` is set to now, so finance can
   list every offline sale.
5. **Per-sale isolation.** Each sale runs in its own transaction, so one
   rejection never rolls back the others. A request carries at most 200 sales;
   the client batches beyond that.
6. The sale type is `GOODS_CHECKOUT`, so shift totals, reports, refunds and
   history all work unchanged.

The admin sales list and export gain an `offline` badge/column
(`offlineSyncedAt != null`).

## Part 2 — Dashboard

- The product create/edit dialog gets a **"Faqat offline rejimda"** ("Only in
  offline mode") checkbox with a one-line hint. It's sent as `offlineOnly`.
- The products table shows an `Offline` badge on those rows.
- Types, DTOs and i18n (uz/ru/en) are updated to match.

## Part 3 — Cashier app

### Components

| Unit | Responsibility |
|------|----------------|
| `core/connectivity/connectivity_monitor.dart` | Pings `GET {baseUrl}/health` every 15 s on its own bare Dio (5 s timeout) and exposes `Stream<bool> reachable`. `checkNow()` backs the manual button. Two failed pings in a row count as unreachable. |
| `core/network/connectivity_interceptor.dart` | Reports connection-class Dio errors (connection error, timeout, socket) to the monitor. The datasources don't change. |
| `core/offline/app_mode_cubit.dart` | Holds the global mode: `online`, `offline` or `syncing`. Triggers the two modals through `rootNavigatorKey`. Persists the mode, so a restart during an outage comes back offline. |
| `features/offline/data/offline_store.dart` | A separate Hive box, `cashier_offline_box`, that logout and `clearSession` **don't** wipe. Holds queued sales, a pending offline shift, and the cached products, discounts and current shift. |
| `features/offline/domain/offline_sale.dart` | Fields: `offlineRequestId`, `createdAt`, `cashierId`, lines (id, name, price, qty), discount snapshot, cash, card, `status` (`pending`/`failed`), `failureCode`, `failureMessage`, `attempts`, `lastAttemptAt`. |
| `features/offline/data/offline_sync_remote_data_source.dart` | Calls `POST /v1/pos/offline/sync`. |
| `features/offline/application/offline_sync_service.dart` | Builds batches, sends them and applies the results: `created`/`duplicate` → drop from the queue; `rejected` → mark `failed` with the reason. On a transport failure, everything stays `pending`. |
| `features/offline/presentation/unsynced_sales_page.dart` | The Unsynced sales page (see below). |

### Mode flow

```
online ──(health fails ×2 or a request fails to connect)──▶ modal "Internet yo'q. Offline rejimga o'tilsinmi?"
   ▲        [Ha] → offline          [Yo'q] → stay online; re-offer only on the next failed *user* request
   │
offline ──(health OK, or "Onlaynni tekshirish" OK)──▶ modal "Internet qaytdi. Onlayn rejimga o'tib, N ta savdoni sinxronlaymizmi?"
   │        [Ha] → syncing → online     [Keyinroq] → stay offline, re-offer after 5 min or on the button
   ▼
syncing ── result dialog: "X ta sinxronlandi, Y ta xato" [Ko'rish → Unsynced page]
```

- "Check online" (D12) runs `checkNow()`. If the server is still unreachable,
  a snackbar says "Hali ham internet yo'q".
- If the queue is empty, going online skips the sync step and switches
  straight to `online`.
- `connectTimeout` drops from 30 s to 10 s. With retries, a 30 s timeout can
  take about a minute and a half to notice a dead network; at 10 s it takes
  seconds.

### Offline shell

- The header shows an amber banner: `OFFLINE · N ta savdo kutmoqda` with an
  **Onlaynni tekshirish** button.
- Enabled tabs: **Savdo**, **Tarix**, **Sinxronlanmagan**, **Sozlamalar**.
- Disabled tabs, with an "Internet kerak" tooltip: Hisob (customers, top-up,
  plan QR), Tashrif tarixi and Ichkarida. Closing the shift is disabled too.
- Logout is blocked while the queue holds this cashier's sales, with a message
  explaining why.

### Shift offline (D7)

- `ShiftRepository` caches the current shift after every successful load.
- On an offline start-up or reload, the app uses the cached open shift.
- With no cached shift, the normal "open shift" prompt creates a **local**
  shift (`offlineRequestId`, `openedAt`, opening cash) in the offline box. The
  shell treats it as open. It goes in the sync payload, so the server creates
  it before the sales.

### Selling offline

- `ProductsRepository` caches the last good catalog and serves it offline.
  `Product` gains `offlineOnly`. The grid shows offline-only items **only** in
  offline mode and hides them online.
- Discounts are served from the cache offline.
- An offline checkout:
  1. builds an `OfflineSale` with a fresh UUID and `DateTime.now()`;
  2. saves it to the store **before** printing;
  3. builds a local `SaleReceipt` and prints it with `SaleReceiptPrinter` as
     usual.

  The receipt shows `OFFLINE` under the header, and its number is the short
  form of the `offlineRequestId`.
- Payment is cash or card; the Savdo screen already offers only those.
- If no catalog was ever cached, the grid shows "Mahsulotlar hali
  yuklanmagan — internet kerak".

### History (D9)

- Online: server history as today, with any still-queued sales listed on top
  under a **Sinxronlanmagan** badge.
- Offline: server history can't load, so only the queued sales show, badged.
- Refund and edit are disabled on queued sales, because they don't exist on
  the server yet.
- After a successful sync they leave the queue and show up as normal server
  sales on the next refresh.

### Unsynced sales page (D11)

- A sidebar entry with a count badge, visible whenever the queue isn't empty.
- Each row shows the time, items, total, payment, status (`kutmoqda` /
  `xato`), the failure reason, and a copyable **support code** (first 8
  characters of `offlineRequestId`) the cashier can read out to support.
- **Qayta urinish** retries one row; **Hammasini qayta yuborish** retries
  them all. Retrying is safe because of idempotency.
- Failed rows are never auto-deleted.

### Multi-cashier safety

Each queue entry carries a `cashierId`. Sync sends only the signed-in
cashier's entries, because the server attributes sales by JWT. Other
cashiers' entries stay queued until that cashier logs in again.

## Error handling

| Case | Behaviour |
|------|-----------|
| Sync request times out | Every sale in the request stays `pending`; retrying later is safe (idempotency). |
| Server rejects a sale | It's marked `failed` with a code and message and shown on the Unsynced page. |
| Token expires while offline | The refresher handles the 401 on sync. A definitive rejection sends the cashier to login; the offline box survives. |
| App killed mid-sale | The sale is saved before printing. At worst the receipt didn't print, but the sale is still queued. |
| Terminal clock is wrong | The server clamps `createdAt` into `[shift.openedAt, now]`. |
| Printer fails offline | Same as online: the sale is kept and a reprint is offered. |

## Testing

- **Backend (Jest), sync use case:** create, duplicate, concurrent
  duplicate, offline shift creation and reuse, rejection when no shift is
  open, inactive product/discount accepted, wrong-branch product rejected,
  arithmetic mismatch rejected, `createdAt` clamping, per-sale isolation.
  Also: online checkout rejects `offlineOnly`.
- **Cashier (flutter test):** `OfflineStore` round-trip; `OfflineSyncService`
  applying each result (created, duplicate, rejected, transport failure);
  `AppModeCubit` transitions, including decline and re-offer; offline
  checkout builds the right receipt; product filtering by mode; the shift
  falling back to the cache or a local shift.
- **Dashboard:** type-check, and the form submits `offlineOnly`.
- **Manual:** on a dev build against the test API, disconnect Wi-Fi, sell,
  restart the app offline, reconnect, sync, then check the Dashboard.

## Out of scope

Offline customer lookup, top-ups, balance payments, plan-entry QR, visit
history, closing a shift offline, and refunds of unsynced sales.

## Branches / delivery

- `maestro_backend`: feature branch → `development` (test) first.
- `Dashboard`: feature branch → `stage`.
- `cashier_app`: `feat/offline-mode` from `main`. Merging to `main` is a
  release, so it ships only after the backend is on prod.
