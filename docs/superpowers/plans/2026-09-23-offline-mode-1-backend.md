# Offline Mode — Plan 1 of 3: Backend (maestro_backend)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the backend an `offlineOnly` product flag and a `POST /v1/pos/offline/sync` endpoint. The endpoint records sales rung up while a cashier terminal was offline, exactly as printed, with idempotency and the real sale time.

**Architecture:** One migration adds `products.offline_only`, `sales.offline_request_id` (unique) plus `sales.offline_synced_at`, and `shifts.offline_request_id` (unique). A framework-free `SyncOfflineSalesUseCase` does all the per-sale validation and returns a status for each shift and each sale. The controller translates per-sale errors with the existing `Translator`. `PrismaSaleRepository.createOffline` writes the sale at the client's price snapshots and treats a unique-index race (`P2002`) as a duplicate.

**Tech Stack:** NestJS 11, Prisma 6 (PostgreSQL), class-validator, Jest 30 (`npx jest`, mocked Prisma).

**Spec:** `cashier_app/docs/superpowers/specs/2026-09-23-offline-mode-design.md` (read it first; this plan also records the planning-time revisions listed below).

## Global Constraints

- Work only in the worktree `/Users/apple/Projects/Pixel_projects/maestro_backend/.worktrees/pos-offline-sync` (branch `feat/pos-offline-sync`, cut from `origin/development` @ `332acec`). Never touch the main checkout; it holds someone's uncommitted work.
- The migration folder is `prisma/migrations/63_pos_offline_sync/` (development's latest is `62_`). SQL must be additive and `IF NOT EXISTS`, following the house style in `57_discount_sort_order`.
- Each new error code gets en/uz/ru entries in `src/i18n/messages/{en,uz,ru}.ts`.
- An old cashier build must behave exactly as before: `GET /v1/pos/products` without `includeOffline=true` never returns offline-only rows.
- Money is whole UZS `number` in the domain and `BigInt` in Prisma, as elsewhere in the module.
- Baseline before starting: `npx jest src/modules/pos` → 33 suites, 248 tests, all passing.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Pushing and opening the MR to `development` happen only after the user approves.

## Planning-time revisions to the spec

1. **`includeOffline` query flag.** `GET /v1/pos/products` returns offline-only rows only with `?includeOffline=true`. Without it, an old cashier build would show "VIP" in its online grid and then hit `PRODUCT_OFFLINE_ONLY` at checkout.
2. **A shift reference on every sale.** Each sale carries either `shiftId` (the server shift the terminal had cached) or `shiftOfflineRequestId` (a shift opened offline). A top-level `shifts` array (usually 0–1 entries) replaces the single `shift` object. This keeps a sale retried days later attached to the shift it was actually rung under, rather than whatever shift is open at retry time.
3. **Closed shifts accept their own sales.** A sale can land on a shift that has since closed. `createdAt` is clamped to `[shift.openedAt, shift.closedAt ?? now]`.

## File map

| File | Change |
|------|--------|
| `prisma/schema.prisma` | Add the 4 columns + 2 unique indexes |
| `prisma/migrations/63_pos_offline_sync/migration.sql` | New |
| `src/modules/pos/domain/product.entity.ts` | Add `offlineOnly` and `assertSellableOnline()` |
| `src/modules/pos/domain/sale.entity.ts` | Add `Sale.offlineSyncedAt` and `CreateOfflineSaleInput` |
| `src/modules/pos/domain/shift.entity.ts` | Add `Shift.offlineRequestId`; `OpenShiftInput` gains `offlineRequestId` and `openedAt` |
| `src/modules/pos/domain/pos.exceptions.ts` | Add `ProductOfflineOnlyException` and `OfflineShiftNotFoundException` |
| `src/i18n/messages/{en,uz,ru}.ts` | Add the 2 codes |
| `src/modules/pos/infrastructure/{product,sale,shift}.mapper.ts` | Map the new columns |
| `src/modules/pos/infrastructure/prisma-product.repository.ts` | Persist `offlineOnly` |
| `src/modules/pos/infrastructure/prisma-shift.repository.ts` | Add `findByOfflineRequestId`; `open` takes offline id and time |
| `src/modules/pos/infrastructure/prisma-sale.repository.ts` | Add `findByOfflineRequestId` and `createOffline` |
| `src/modules/pos/application/ports/{sale,shift}.repository.ts` | New abstract methods |
| `src/modules/pos/application/checkout-sale.use-case.ts`, `plan-entry-checkout.use-case.ts` | Refuse offline-only products |
| `src/modules/pos/application/list-pos-products.use-case.ts` | Add the `includeOffline` filter |
| `src/modules/pos/application/sync-offline-sales.use-case.ts` | New, with the core rules |
| `src/modules/pos/presentation/dto/{admin-create-product,admin-update-product}.dto.ts` | Add `offlineOnly` |
| `src/modules/pos/presentation/dto/pos-products-query.dto.ts` | New |
| `src/modules/pos/presentation/dto/offline-sync.dto.ts` | New |
| `src/modules/pos/presentation/responses/{pos,admin-pos}-response.types.ts` | New fields and types |
| `src/modules/pos/presentation/mappers/{pos,admin-pos}-response.mapper.ts` | New fields plus `toOfflineSyncResponse` |
| `src/modules/pos/presentation/pos.controller.ts` | Add the `offline/sync` route; `products` gets its query DTO |
| `src/modules/pos/presentation/export/sales-workbook.builder.ts` | Add an "Offline" column |
| `src/modules/pos/pos.module.ts` | Register `SyncOfflineSalesUseCase` |

---

### Task 1: Schema, migration, and offline fields in the domain

**Files:**
- Modify: `prisma/schema.prisma` (models `Shift` ~L900, `Product` ~L963, `Sale` ~L996)
- Create: `prisma/migrations/63_pos_offline_sync/migration.sql`
- Modify: `src/modules/pos/domain/product.entity.ts`, `sale.entity.ts`, `shift.entity.ts`
- Modify: `src/modules/pos/infrastructure/product.mapper.ts`, `sale.mapper.ts`, `shift.mapper.ts`
- Test: `src/modules/pos/infrastructure/offline-fields.mapper.spec.ts` (new)

**Interfaces:**
- Produces: `Product.offlineOnly: boolean`, `CreateProductInput.offlineOnly?: boolean`, `UpdateProductInput.offlineOnly?: boolean`, `Sale.offlineSyncedAt?: Date | null`, `Shift.offlineRequestId?: string | null`, `OpenShiftInput.offlineRequestId?: string | null`, `OpenShiftInput.openedAt?: Date`, and generated Prisma fields `offlineOnly`, `offlineRequestId`, `offlineSyncedAt`.

- [ ] **Step 1: Write the failing test**

Create `src/modules/pos/infrastructure/offline-fields.mapper.spec.ts`:

```ts
import { toDomainProduct } from './product.mapper';
import { toDomainSale } from './sale.mapper';
import { toDomainShift } from './shift.mapper';

const AT = new Date('2026-09-23T09:00:00.000Z');
const OFFLINE_ID = '11111111-1111-4111-8111-111111111111';

type SaleRow = Parameters<typeof toDomainSale>[0];

const saleRow = (overrides: Record<string, unknown> = {}) =>
  ({
    id: 'sale-1',
    type: 'GOODS_CHECKOUT',
    cashierId: 'cashier-1',
    shiftId: 'shift-1',
    branchId: 'branch-1',
    customerId: null,
    subtotalUzs: 0n,
    grossUzs: 0n,
    discountUzs: 0n,
    discountId: null,
    discountNameSnapshot: null,
    discountKindSnapshot: null,
    discountValueSnapshot: null,
    cashUzs: 0n,
    cardUzs: 0n,
    balanceUzs: 0n,
    paymentProvider: null,
    status: 'paid',
    createdAt: AT,
    offlineRequestId: null,
    offlineSyncedAt: null,
    items: [],
    refunds: [],
    passes: [],
    corrections: [],
    ...overrides,
  }) as unknown as SaleRow;

describe('offline-sync fields in the POS mappers', () => {
  it('maps Product.offlineOnly', () => {
    const product = toDomainProduct({
      id: 'product-1',
      branchId: 'branch-1',
      name: 'VIP',
      priceUzs: 75_000n,
      category: 'Tariflar',
      icon: 'ph ph-crown',
      active: true,
      offlineOnly: true,
      createdAt: AT,
      updatedAt: AT,
    });

    expect(product.offlineOnly).toBe(true);
  });

  it('maps Shift.offlineRequestId', () => {
    const shift = toDomainShift({
      id: 'shift-1',
      cashierId: 'cashier-1',
      branchId: 'branch-1',
      openedAt: AT,
      closedAt: null,
      status: 'open',
      openingCashUzs: null,
      closingNote: null,
      createdAt: AT,
      offlineRequestId: OFFLINE_ID,
    });

    expect(shift.offlineRequestId).toBe(OFFLINE_ID);
  });

  it('maps Sale.offlineSyncedAt, null for a sale rung up online', () => {
    expect(toDomainSale(saleRow()).offlineSyncedAt).toBeNull();
    expect(
      toDomainSale(
        saleRow({ offlineRequestId: OFFLINE_ID, offlineSyncedAt: AT }),
      ).offlineSyncedAt,
    ).toEqual(AT);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npx jest src/modules/pos/infrastructure/offline-fields.mapper.spec.ts`
Expected: FAIL. TypeScript reports that `offlineOnly` / `offlineRequestId` don't exist on the Prisma row types, or the assertions get `undefined`.

- [ ] **Step 3: Edit the Prisma schema**

In `model Shift`, after `closingNote`:

```prisma
  /// Set when the cashier terminal opened this shift while offline — the
  /// idempotency key of `POST /pos/offline/sync`. Null for shifts opened online.
  offlineRequestId String?   @unique @map("offline_request_id") @db.Uuid
```

In `model Product`, after `active`:

```prisma
  /// Only offered by the cashier terminal in offline mode (e.g. VIP / hourly
  /// plans, which normally mint a QR and so need the server). Refused by
  /// online checkout, and hidden from `GET /pos/products` unless the terminal
  /// passes `includeOffline=true`.
  offlineOnly Boolean  @default(false) @map("offline_only")
```

In `model Sale`, after `discountValueSnapshot`:

```prisma
  /// Idempotency key minted by the cashier terminal when an offline sale was
  /// rung up. Null for sales rung up online.
  offlineRequestId      String?   @unique @map("offline_request_id") @db.Uuid
  /// When an offline-rung sale reached the server. Non-null marks a receipt
  /// that was recorded at the terminal's printed prices — see
  /// `SyncOfflineSalesUseCase`.
  offlineSyncedAt       DateTime? @map("offline_synced_at") @db.Timestamptz(6)
```

- [ ] **Step 4: Write the migration**

Create `prisma/migrations/63_pos_offline_sync/migration.sql`:

```sql
-- Cashier offline mode: offline-only catalog items, and idempotent replay of
-- sales/shifts created while the terminal had no internet. Additive +
-- IF NOT EXISTS keeps `prisma migrate deploy` safe to retry.

ALTER TABLE "products" ADD COLUMN IF NOT EXISTS "offline_only" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "sales" ADD COLUMN IF NOT EXISTS "offline_request_id" UUID;
ALTER TABLE "sales" ADD COLUMN IF NOT EXISTS "offline_synced_at" TIMESTAMPTZ(6);
CREATE UNIQUE INDEX IF NOT EXISTS "sales_offline_request_id_key" ON "sales"("offline_request_id");

ALTER TABLE "shifts" ADD COLUMN IF NOT EXISTS "offline_request_id" UUID;
CREATE UNIQUE INDEX IF NOT EXISTS "shifts_offline_request_id_key" ON "shifts"("offline_request_id");
```

Run: `npx prisma validate && npx prisma generate`
Expected: `The schema at prisma/schema.prisma is valid` and `Generated Prisma Client`.

- [ ] **Step 5: Add the domain fields**

`src/modules/pos/domain/product.entity.ts`: add `offlineOnly: boolean;` to `Product` after `active`, and `offlineOnly?: boolean;` to both `CreateProductInput` and `UpdateProductInput`. Add this doc comment on the `Product` field:

```ts
  /** Offered only by the cashier terminal's offline mode; refused online. */
  offlineOnly: boolean;
```

`src/modules/pos/domain/sale.entity.ts`: add to `interface Sale`, after `createdAt`:

```ts
  /** When an offline-rung sale reached the server — null/absent for a sale
   *  rung up online. */
  offlineSyncedAt?: Date | null;
```

`src/modules/pos/domain/shift.entity.ts`: add `offlineRequestId?: string | null;` to `Shift` after `closingNote`. Extend `OpenShiftInput`:

```ts
export interface OpenShiftInput {
  cashierId: string;
  branchId: string;
  openingCashUzs?: number | null;
  /** Set when the shift was opened on an offline terminal. */
  offlineRequestId?: string | null;
  /** The terminal's own opening time for an offline shift; omitted = now. */
  openedAt?: Date;
}
```

- [ ] **Step 6: Map the columns**

`product.mapper.ts`: add `offlineOnly: row.offlineOnly,` after `active`.
`shift.mapper.ts`: add `offlineRequestId: row.offlineRequestId,` after `closingNote`.
`sale.mapper.ts` (`toDomainSale`): add `offlineSyncedAt: row.offlineSyncedAt ?? null,` after `createdAt`.

- [ ] **Step 7: Run the tests**

Run: `npx jest src/modules/pos/infrastructure/offline-fields.mapper.spec.ts`
Expected: PASS (3 tests).

Run: `npx tsc --noEmit -p tsconfig.json`
Expected: no errors. If a spec fixture typed `Product` complains about the missing `offlineOnly`, add `offlineOnly: false` to that fixture.

Run: `npx jest src/modules/pos`
Expected: all suites pass (248 + 3 tests).

- [ ] **Step 8: Commit**

```bash
git add prisma/schema.prisma prisma/migrations/63_pos_offline_sync src/modules/pos/domain src/modules/pos/infrastructure/*.mapper.ts src/modules/pos/infrastructure/offline-fields.mapper.spec.ts
git commit -m "feat(pos): schema for offline-only products and offline sale replay

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Offline-only products: admin flag, POS catalog filter, online checkout guard

**Files:**
- Modify: `src/modules/pos/domain/pos.exceptions.ts`, `src/modules/pos/domain/product.entity.ts`
- Modify: `src/i18n/messages/en.ts`, `uz.ts`, `ru.ts`
- Modify: `src/modules/pos/application/checkout-sale.use-case.ts`, `plan-entry-checkout.use-case.ts` (`sellFromBalance`, ~L215), `list-pos-products.use-case.ts`
- Modify: `src/modules/pos/infrastructure/prisma-product.repository.ts` (`create` ~L62, `update` ~L76)
- Modify: `src/modules/pos/presentation/dto/admin-create-product.dto.ts`, `admin-update-product.dto.ts`
- Create: `src/modules/pos/presentation/dto/pos-products-query.dto.ts`
- Modify: `src/modules/pos/presentation/responses/pos-response.types.ts` (`ProductResponse`), `admin-pos-response.types.ts` (`AdminProductResponse`)
- Modify: `src/modules/pos/presentation/mappers/pos-response.mapper.ts` (`toProductResponse`), `admin-pos-response.mapper.ts` (`toAdminProductResponse`)
- Modify: `src/modules/pos/presentation/pos.controller.ts` (`products()` ~L342)
- Test: `src/modules/pos/application/checkout-sale.use-case.spec.ts` (add a case), `src/modules/pos/application/list-pos-products.use-case.spec.ts` (new), `src/modules/pos/presentation/dto/offline-only-product.dto.spec.ts` (new)

**Interfaces:**
- Consumes: `Product.offlineOnly` (Task 1)
- Produces: `ProductOfflineOnlyException` (code `PRODUCT_OFFLINE_ONLY`), `assertSellableOnline(product: Product): void`, `ListPosProductsUseCase.execute(branchId: string, options?: { includeOffline?: boolean }): Promise<Product[]>`, `ProductResponse.offlineOnly: boolean`, `AdminProductResponse.offlineOnly: boolean`

- [ ] **Step 1: Write the failing tests**

Add to `checkout-sale.use-case.spec.ts`: import `ProductOfflineOnlyException` alongside the other exceptions, then add inside the `describe`:

```ts
  it('refuses an offline-only product at the online till', async () => {
    products.findManyByIds.mockResolvedValue([
      { ...socks(), offlineOnly: true } as Product,
    ]);

    await expect(
      useCase.execute({
        cashierId: 'cashier-1',
        shiftId: 'shift-1',
        branchId: 'branch-1',
        customerId: null,
        lines: [{ productId: SOCKS_ID, qty: 1 }],
        cashUzs: 15_000,
        cardUzs: 0,
      }),
    ).rejects.toBeInstanceOf(ProductOfflineOnlyException);
    expect(sales.create).not.toHaveBeenCalled();
  });
```

Create `src/modules/pos/application/list-pos-products.use-case.spec.ts`:

```ts
import { Product } from '../domain/product.entity';
import { ListPosProductsUseCase } from './list-pos-products.use-case';
import { ProductRepository } from './ports/product.repository';

const product = (id: string, offlineOnly: boolean) =>
  ({ id, offlineOnly }) as unknown as Product;

describe('ListPosProductsUseCase', () => {
  let products: jest.Mocked<ProductRepository>;
  let useCase: ListPosProductsUseCase;

  beforeEach(() => {
    products = {
      listActiveByBranch: jest
        .fn()
        .mockResolvedValue([product('socks', false), product('vip', true)]),
    } as unknown as jest.Mocked<ProductRepository>;
    useCase = new ListPosProductsUseCase(products);
  });

  it('hides offline-only items from a terminal that did not ask for them', async () => {
    const result = await useCase.execute('branch-1');

    expect(result.map((p) => p.id)).toEqual(['socks']);
    expect(products.listActiveByBranch).toHaveBeenCalledWith('branch-1');
  });

  it('returns offline-only items too when the terminal asks for them', async () => {
    const result = await useCase.execute('branch-1', { includeOffline: true });

    expect(result.map((p) => p.id)).toEqual(['socks', 'vip']);
  });
});
```

Create `src/modules/pos/presentation/dto/offline-only-product.dto.spec.ts`:

```ts
import 'reflect-metadata';

import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import { AdminCreateProductDto } from './admin-create-product.dto';
import { AdminUpdateProductDto } from './admin-update-product.dto';
import { PosProductsQueryDto } from './pos-products-query.dto';

const BRANCH_ID = '22222222-2222-4222-8222-222222222222';

const createBody = (extra: Record<string, unknown>) =>
  plainToInstance(AdminCreateProductDto, {
    branchId: BRANCH_ID,
    name: 'VIP',
    priceUzs: 75_000,
    category: 'Tariflar',
    icon: 'ph ph-crown',
    ...extra,
  });

describe('offline-only product DTOs', () => {
  it('accepts offlineOnly on create and update', async () => {
    await expect(validate(createBody({ offlineOnly: true }))).resolves.toHaveLength(0);
    await expect(
      validate(plainToInstance(AdminUpdateProductDto, { offlineOnly: false })),
    ).resolves.toHaveLength(0);
  });

  it('keeps offlineOnly optional so older dashboard builds still work', async () => {
    await expect(validate(createBody({}))).resolves.toHaveLength(0);
  });

  it('rejects a non-boolean offlineOnly', async () => {
    const errors = await validate(createBody({ offlineOnly: 'yes' }));

    expect(errors.some((e) => e.property === 'offlineOnly')).toBe(true);
  });

  it('accepts includeOffline=true|false and nothing else', async () => {
    await expect(
      validate(plainToInstance(PosProductsQueryDto, { includeOffline: 'true' })),
    ).resolves.toHaveLength(0);
    const errors = await validate(
      plainToInstance(PosProductsQueryDto, { includeOffline: 'maybe' }),
    );
    expect(errors.some((e) => e.property === 'includeOffline')).toBe(true);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest src/modules/pos/application/checkout-sale.use-case.spec.ts src/modules/pos/application/list-pos-products.use-case.spec.ts src/modules/pos/presentation/dto/offline-only-product.dto.spec.ts`
Expected: FAIL, because `ProductOfflineOnlyException` and `PosProductsQueryDto` can't be resolved.

- [ ] **Step 3: Add the exception, the guard and i18n**

Append to `src/modules/pos/domain/pos.exceptions.ts`:

```ts
/** An `offlineOnly` catalog item (e.g. the offline VIP plan) reached an
 *  online checkout — only the terminal's offline mode may sell it. */
export class ProductOfflineOnlyException extends DomainException {
  readonly code = 'PRODUCT_OFFLINE_ONLY';
  readonly status = BAD_REQUEST;
  constructor() {
    super('This product can only be sold in offline mode');
  }
}
```

Append to `src/modules/pos/domain/product.entity.ts`:

```ts
import { ProductOfflineOnlyException } from './pos.exceptions';

/** Online checkouts call this per line: offline-only items (VIP / hourly
 *  plans sold without a QR) must never be sold while the server is up. */
export function assertSellableOnline(product: Product): void {
  if (product.offlineOnly) throw new ProductOfflineOnlyException();
}
```

(Put the `import` at the top of the file.)

Add next to `DISCOUNT_INVALID_VALUE` in each catalog:
- `en.ts`: `PRODUCT_OFFLINE_ONLY: 'This product can only be sold in offline mode',`
- `uz.ts`: `PRODUCT_OFFLINE_ONLY: 'Bu mahsulot faqat offline rejimda sotiladi',`
- `ru.ts`: `PRODUCT_OFFLINE_ONLY: 'Этот товар продаётся только в офлайн-режиме',`

- [ ] **Step 4: Guard both online checkout paths**

In `checkout-sale.use-case.ts`, import `assertSellableOnline` from `'../domain/product.entity'`. In the line loop, directly after `if (!product) throw new ProductNotFoundException();`, add:

```ts
      assertSellableOnline(product);
```

In `plan-entry-checkout.use-case.ts`, inside `sellFromBalance`, add the same import and the same line directly after `if (!product) throw new ProductNotFoundException();`. (`sellDirect` goes through `CheckoutSaleUseCase`, so it's already covered.)

- [ ] **Step 5: Filter the POS catalog**

Replace the body of `list-pos-products.use-case.ts`:

```ts
import { Injectable } from '@nestjs/common';
import { Product } from '../domain/product.entity';
import { ProductRepository } from './ports/product.repository';

/** Active catalog for the cashier's own branch — the POS "Savdo" grid.
 *  Offline-only items are included only when the terminal asks for them, so
 *  a cashier build that predates offline mode never shows them. */
@Injectable()
export class ListPosProductsUseCase {
  constructor(private readonly products: ProductRepository) {}

  async execute(
    branchId: string,
    options: { includeOffline?: boolean } = {},
  ): Promise<Product[]> {
    const products = await this.products.listActiveByBranch(branchId);
    return options.includeOffline
      ? products
      : products.filter((product) => !product.offlineOnly);
  }
}
```

Create `src/modules/pos/presentation/dto/pos-products-query.dto.ts`:

```ts
import { IsIn, IsOptional } from 'class-validator';

/** Omitted = online catalog only, so an older cashier build keeps fetching
 *  exactly what it always did. */
export class PosProductsQueryDto {
  @IsOptional()
  @IsIn(['true', 'false'])
  includeOffline?: 'true' | 'false';
}
```

In `pos.controller.ts`, import `PosProductsQueryDto` and change the `products` handler:

```ts
  @Get('products')
  async products(
    @CurrentCashier() current: CashierContext,
    @Query() query: PosProductsQueryDto,
  ): Promise<ProductResponse[]> {
    const products = await this.listProducts.execute(current.branch.id, {
      includeOffline: query.includeOffline === 'true',
    });
    return products.map(toProductResponse);
  }
```

- [ ] **Step 6: Let the admin set the flag, and expose it**

In both admin product DTOs, add `IsBoolean` to the `class-validator` import and this field at the end of the class:

```ts
  /** Only offered by the cashier terminal's offline mode. */
  @IsOptional()
  @IsBoolean()
  offlineOnly?: boolean;
```

(`admin-create-product.dto.ts` also needs `IsOptional` added to its import.)

In `prisma-product.repository.ts`, `create` data: add `offlineOnly: input.offlineOnly ?? false,`. `update` data: add `offlineOnly: input.offlineOnly,`.

`ProductResponse` (pos-response.types.ts) and `AdminProductResponse` (admin-pos-response.types.ts): add `offlineOnly: boolean;`.
`toProductResponse` and `toAdminProductResponse`: add `offlineOnly: product.offlineOnly,`.

- [ ] **Step 7: Run the tests**

Run: `npx jest src/modules/pos && npx tsc --noEmit -p tsconfig.json`
Expected: all suites pass, no type errors.

- [ ] **Step 8: Commit**

```bash
git add src/modules/pos src/i18n/messages
git commit -m "feat(pos): offline-only catalog items, hidden from and refused by online checkout

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Repository support for offline replay

**Files:**
- Modify: `src/modules/pos/domain/sale.entity.ts` (add `CreateOfflineSaleInput`)
- Modify: `src/modules/pos/application/ports/sale.repository.ts`, `shift.repository.ts`
- Modify: `src/modules/pos/infrastructure/prisma-sale.repository.ts`, `prisma-shift.repository.ts`
- Test: `src/modules/pos/infrastructure/prisma-sale.repository.spec.ts` (new `describe`), `prisma-shift.repository.spec.ts` (new `describe`)

**Interfaces:**
- Consumes: the Task 1 schema and entities
- Produces:
  - `ShiftRepository.findByOfflineRequestId(offlineRequestId: string): Promise<Shift | null>`
  - `ShiftRepository.open(input: OpenShiftInput)` now honours `offlineRequestId` and `openedAt`
  - `SaleRepository.findByOfflineRequestId(offlineRequestId: string): Promise<Sale | null>`
  - `SaleRepository.createOffline(input: CreateOfflineSaleInput): Promise<{ sale: Sale; created: boolean }>`
  - `CreateOfflineSaleInput` (shape below)

- [ ] **Step 1: Write the failing tests**

Append to `prisma-shift.repository.spec.ts` (after the existing `describe` block):

```ts
describe('PrismaShiftRepository offline shifts', () => {
  const AT = new Date('2026-09-23T08:00:00.000Z');
  const OFFLINE_ID = '11111111-1111-4111-8111-111111111111';
  const row = {
    id: 'shift-9',
    cashierId: 'cashier-1',
    branchId: 'branch-1',
    openedAt: AT,
    closedAt: null,
    status: 'open',
    openingCashUzs: 50_000n,
    closingNote: null,
    createdAt: AT,
    offlineRequestId: OFFLINE_ID,
  };
  let shift: { create: jest.Mock; findUnique: jest.Mock };
  let repository: PrismaShiftRepository;

  beforeEach(() => {
    shift = {
      create: jest.fn().mockResolvedValue(row),
      findUnique: jest.fn().mockResolvedValue(row),
    };
    repository = new PrismaShiftRepository({ shift } as unknown as PrismaService);
  });

  it('opens a shift with the terminal offline id and opening time', async () => {
    const opened = await repository.open({
      cashierId: 'cashier-1',
      branchId: 'branch-1',
      openingCashUzs: 50_000,
      offlineRequestId: OFFLINE_ID,
      openedAt: AT,
    });

    expect(shift.create).toHaveBeenCalledWith({
      data: {
        cashierId: 'cashier-1',
        branchId: 'branch-1',
        openingCashUzs: 50_000n,
        offlineRequestId: OFFLINE_ID,
        openedAt: AT,
      },
    });
    expect(opened.offlineRequestId).toBe(OFFLINE_ID);
  });

  it('leaves openedAt to the database default for an online shift', async () => {
    await repository.open({ cashierId: 'cashier-1', branchId: 'branch-1' });

    expect(shift.create.mock.calls[0][0].data).not.toHaveProperty('openedAt');
    expect(shift.create.mock.calls[0][0].data.offlineRequestId).toBeNull();
  });

  it('finds a shift by its offline id', async () => {
    await expect(repository.findByOfflineRequestId(OFFLINE_ID)).resolves.toMatchObject({ id: 'shift-9' });
    expect(shift.findUnique).toHaveBeenCalledWith({ where: { offlineRequestId: OFFLINE_ID } });
  });
});
```

Append a new `describe` to `prisma-sale.repository.spec.ts`. It reuses the file's top-level `emptySaleRow` helper. Add `import { Prisma } from '@prisma/client';` at the top:

```ts
describe('PrismaSaleRepository offline replay', () => {
  const OFFLINE_ID = '33333333-3333-4333-8333-333333333333';
  const RUNG_AT = new Date('2026-09-23T10:15:00.000Z');
  const SYNCED_AT = new Date('2026-09-23T12:00:00.000Z');
  let sale: { create: jest.Mock; findUnique: jest.Mock };
  let product: { findMany: jest.Mock };
  let repository: PrismaSaleRepository;

  const input = {
    offlineRequestId: OFFLINE_ID,
    cashierId: 'cashier-1',
    shiftId: 'shift-1',
    branchId: 'branch-1',
    createdAt: RUNG_AT,
    syncedAt: SYNCED_AT,
    lines: [
      { productId: 'vip', nameSnapshot: 'VIP', priceSnapshotUzs: 75_000, qty: 2 },
    ],
    discount: { id: 'disc-1', name: 'Flayer', kind: 'percent' as const, value: 10 },
    grossUzs: 150_000,
    discountUzs: 15_000,
    subtotalUzs: 135_000,
    cashUzs: 135_000,
    cardUzs: 0,
  };

  beforeEach(() => {
    sale = {
      create: jest.fn().mockResolvedValue(
        emptySaleRow({ id: 'sale-offline', offlineRequestId: OFFLINE_ID, offlineSyncedAt: SYNCED_AT }),
      ),
      findUnique: jest.fn(),
    };
    product = { findMany: jest.fn() };
    repository = new PrismaSaleRepository({ sale, product } as unknown as PrismaService);
  });

  it('writes the receipt exactly as printed, without re-pricing from the catalog', async () => {
    const result = await repository.createOffline(input);

    expect(product.findMany).not.toHaveBeenCalled();
    const data = sale.create.mock.calls[0][0].data;
    expect(data).toMatchObject({
      type: 'GOODS_CHECKOUT',
      cashierId: 'cashier-1',
      shiftId: 'shift-1',
      branchId: 'branch-1',
      grossUzs: 150_000n,
      discountUzs: 15_000n,
      subtotalUzs: 135_000n,
      cashUzs: 135_000n,
      cardUzs: 0n,
      createdAt: RUNG_AT,
      offlineRequestId: OFFLINE_ID,
      offlineSyncedAt: SYNCED_AT,
      discountId: 'disc-1',
      discountNameSnapshot: 'Flayer',
      discountKindSnapshot: 'percent',
      discountValueSnapshot: 10n,
    });
    expect(data.items.create).toEqual([
      {
        productId: 'vip',
        nameSnapshot: 'VIP',
        priceSnapshotUzs: 75_000n,
        qty: 2,
        lineTotalUzs: 150_000n,
      },
    ]);
    expect(result).toMatchObject({ created: true, sale: { id: 'sale-offline' } });
  });

  it('treats a concurrent duplicate as already recorded', async () => {
    sale.create.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
        code: 'P2002',
        clientVersion: 'test',
      }),
    );
    sale.findUnique.mockResolvedValue(emptySaleRow({ id: 'sale-first' }));

    const result = await repository.createOffline(input);

    expect(sale.findUnique).toHaveBeenCalledWith(
      expect.objectContaining({ where: { offlineRequestId: OFFLINE_ID } }),
    );
    expect(result).toMatchObject({ created: false, sale: { id: 'sale-first' } });
  });

  it('rethrows any other database error', async () => {
    sale.create.mockRejectedValue(new Error('connection lost'));

    await expect(repository.createOffline(input)).rejects.toThrow('connection lost');
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest src/modules/pos/infrastructure/prisma-sale.repository.spec.ts src/modules/pos/infrastructure/prisma-shift.repository.spec.ts`
Expected: FAIL, because `createOffline` / `findByOfflineRequestId` aren't functions and `open` doesn't pass `offlineRequestId`.

- [ ] **Step 3: Add the input type and the ports**

In `sale.entity.ts`, change the discount import to `import { DiscountKind, DiscountSnapshot } from './discount.entity';` and add after `CreateSaleInput`:

```ts
/** One offline-rung receipt, already validated and priced by
 *  `SyncOfflineSalesUseCase` — written exactly as the terminal printed it. */
export interface CreateOfflineSaleInput {
  offlineRequestId: string;
  cashierId: string;
  shiftId: string;
  branchId: string;
  /** When the cashier rang it up, already clamped into the shift window. */
  createdAt: Date;
  syncedAt: Date;
  lines: Array<{
    productId: string;
    nameSnapshot: string;
    priceSnapshotUzs: number;
    qty: number;
  }>;
  discount: { id: string; name: string; kind: DiscountKind; value: number } | null;
  grossUzs: number;
  discountUzs: number;
  subtotalUzs: number;
  cashUzs: number;
  cardUzs: number;
}
```

In `ports/sale.repository.ts`, import `CreateOfflineSaleInput` and add to `SaleRepository`:

```ts
  abstract findByOfflineRequestId(offlineRequestId: string): Promise<Sale | null>;
  /** Idempotent: a concurrent write of the same `offlineRequestId` returns the
   *  already-recorded sale with `created: false` instead of failing. */
  abstract createOffline(
    input: CreateOfflineSaleInput,
  ): Promise<{ sale: Sale; created: boolean }>;
```

In `ports/shift.repository.ts`, add:

```ts
  abstract findByOfflineRequestId(offlineRequestId: string): Promise<Shift | null>;
```

- [ ] **Step 4: Implement the adapters**

`prisma-shift.repository.ts`: add the method and replace `open`:

```ts
  async findByOfflineRequestId(offlineRequestId: string): Promise<Shift | null> {
    const row = await this.prisma.shift.findUnique({ where: { offlineRequestId } });
    return row ? toDomainShift(row) : null;
  }

  async open(input: OpenShiftInput): Promise<Shift> {
    const row = await this.prisma.shift.create({
      data: {
        cashierId: input.cashierId,
        branchId: input.branchId,
        openingCashUzs:
          input.openingCashUzs != null ? BigInt(input.openingCashUzs) : null,
        offlineRequestId: input.offlineRequestId ?? null,
        ...(input.openedAt && { openedAt: input.openedAt }),
      },
    });
    return toDomainShift(row);
  }
```

`prisma-sale.repository.ts`: add `import { Prisma } from '@prisma/client';` if it's missing, add `CreateOfflineSaleInput` to the domain import, and add after `create`:

```ts
  async findByOfflineRequestId(offlineRequestId: string): Promise<Sale | null> {
    const row = await this.prisma.sale.findUnique({
      where: { offlineRequestId },
      include: SALE_INCLUDE,
    });
    return row ? toDomainSale(row) : null;
  }

  /** Unlike `create`, prices are NOT re-read from the catalog: an offline
   *  receipt is already on paper in the customer's hand, so the database must
   *  match it. `SyncOfflineSalesUseCase` has validated the arithmetic. */
  async createOffline(
    input: CreateOfflineSaleInput,
  ): Promise<{ sale: Sale; created: boolean }> {
    try {
      const row = await this.prisma.sale.create({
        data: {
          type: 'GOODS_CHECKOUT',
          cashierId: input.cashierId,
          shiftId: input.shiftId,
          branchId: input.branchId,
          customerId: null,
          subtotalUzs: BigInt(input.subtotalUzs),
          grossUzs: BigInt(input.grossUzs),
          discountUzs: BigInt(input.discountUzs),
          cashUzs: BigInt(input.cashUzs),
          cardUzs: BigInt(input.cardUzs),
          createdAt: input.createdAt,
          offlineRequestId: input.offlineRequestId,
          offlineSyncedAt: input.syncedAt,
          items: {
            create: input.lines.map((line) => ({
              productId: line.productId,
              nameSnapshot: line.nameSnapshot,
              priceSnapshotUzs: BigInt(line.priceSnapshotUzs),
              qty: line.qty,
              lineTotalUzs: BigInt(line.priceSnapshotUzs) * BigInt(line.qty),
            })),
          },
          ...(input.discount && {
            discountId: input.discount.id,
            discountNameSnapshot: input.discount.name,
            discountKindSnapshot: input.discount.kind,
            discountValueSnapshot: BigInt(input.discount.value),
          }),
        },
        include: SALE_INCLUDE,
      });
      return { sale: toDomainSale(row), created: true };
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        const existing = await this.findByOfflineRequestId(input.offlineRequestId);
        if (existing) return { sale: existing, created: false };
      }
      throw error;
    }
  }
```

- [ ] **Step 5: Run the tests**

Run: `npx jest src/modules/pos && npx tsc --noEmit -p tsconfig.json`
Expected: all suites pass, no type errors.

- [ ] **Step 6: Commit**

```bash
git add src/modules/pos
git commit -m "feat(pos): idempotent repository writes for offline sales and shifts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `SyncOfflineSalesUseCase`

**Files:**
- Modify: `src/modules/pos/domain/pos.exceptions.ts`, `src/i18n/messages/{en,uz,ru}.ts`
- Create: `src/modules/pos/application/sync-offline-sales.use-case.ts`
- Test: `src/modules/pos/application/sync-offline-sales.use-case.spec.ts`

**Interfaces:**
- Consumes: `ShiftRepository.{findById,findOpenForCashier,findByOfflineRequestId,open}`, `SaleRepository.{findByOfflineRequestId,createOffline}`, `ProductRepository.findManyByIds`, `DiscountRepository.findById`, `applyDiscount`, `isValidDiscountValue`
- Produces (exported from the use-case file):
  - `OfflineShiftInput { offlineRequestId: string; openedAt: Date; openingCashUzs: number | null }`
  - `OfflineSaleInput { offlineRequestId; shiftId?: string | null; shiftOfflineRequestId?: string | null; createdAt: Date; lines: { productId; qty; priceSnapshotUzs }[]; discount: { id; kind: DiscountKind; value } | null; cashUzs; cardUzs }`
  - `SyncOfflineSalesCommand { cashierId; branchId; now: Date; shifts: OfflineShiftInput[]; sales: OfflineSaleInput[] }`
  - `OfflineSyncStatus = 'created' | 'duplicate' | 'rejected'`
  - `OfflineShiftResult { offlineRequestId; status; shiftId: string | null; error: DomainException | null }`
  - `OfflineSaleResult { offlineRequestId; status; saleId: string | null; error: DomainException | null }`
  - `SyncOfflineSalesResult { shifts: OfflineShiftResult[]; sales: OfflineSaleResult[] }`
  - `OfflineShiftNotFoundException` (code `OFFLINE_SHIFT_NOT_FOUND`)

- [ ] **Step 1: Write the failing test**

Create `src/modules/pos/application/sync-offline-sales.use-case.spec.ts`:

```ts
import { Discount } from '../domain/discount.entity';
import {
  DiscountNotAvailableException,
  OfflineShiftNotFoundException,
  ProductNotFoundException,
  SalePaymentMismatchException,
} from '../domain/pos.exceptions';
import { Product } from '../domain/product.entity';
import { Shift } from '../domain/shift.entity';
import { DiscountRepository } from './ports/discount.repository';
import { ProductRepository } from './ports/product.repository';
import { SaleRepository } from './ports/sale.repository';
import { ShiftRepository } from './ports/shift.repository';
import {
  OfflineSaleInput,
  SyncOfflineSalesCommand,
  SyncOfflineSalesUseCase,
} from './sync-offline-sales.use-case';

const OFFLINE_SHIFT = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const SALE_A = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const SALE_B = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const OPENED = new Date('2026-09-23T08:00:00.000Z');
const RUNG = new Date('2026-09-23T10:00:00.000Z');
const NOW = new Date('2026-09-23T12:00:00.000Z');

const shift = (overrides: Partial<Shift> = {}): Shift => ({
  id: 'shift-1',
  cashierId: 'cashier-1',
  branchId: 'branch-1',
  openedAt: OPENED,
  closedAt: null,
  status: 'open',
  openingCashUzs: 0,
  closingNote: null,
  createdAt: OPENED,
  offlineRequestId: null,
  ...overrides,
});

const vip = (overrides: Partial<Product> = {}): Product =>
  ({
    id: 'vip',
    branchId: 'branch-1',
    name: 'VIP',
    priceUzs: 80_000, // price changed during the outage — receipt said 75 000
    offlineOnly: true,
    active: false, // switched off during the outage
    ...overrides,
  }) as Product;

const discount = (overrides: Partial<Discount> = {}): Discount => ({
  id: 'disc-1',
  name: 'Flayer',
  kind: 'percent',
  value: 50, // edited during the outage — receipt used 10%
  scope: 'goods',
  active: false, // disabled during the outage
  sortOrder: 0,
  createdByAdminId: null,
  createdAt: OPENED,
  updatedAt: OPENED,
  ...overrides,
});

const sale = (overrides: Partial<OfflineSaleInput> = {}): OfflineSaleInput => ({
  offlineRequestId: SALE_A,
  shiftId: 'shift-1',
  createdAt: RUNG,
  lines: [{ productId: 'vip', qty: 2, priceSnapshotUzs: 75_000 }],
  discount: null,
  cashUzs: 150_000,
  cardUzs: 0,
  ...overrides,
});

describe('SyncOfflineSalesUseCase', () => {
  let shifts: jest.Mocked<ShiftRepository>;
  let sales: jest.Mocked<SaleRepository>;
  let products: jest.Mocked<ProductRepository>;
  let discounts: jest.Mocked<DiscountRepository>;
  let useCase: SyncOfflineSalesUseCase;

  const command = (
    overrides: Partial<SyncOfflineSalesCommand> = {},
  ): SyncOfflineSalesCommand => ({
    cashierId: 'cashier-1',
    branchId: 'branch-1',
    now: NOW,
    shifts: [],
    sales: [sale()],
    ...overrides,
  });

  beforeEach(() => {
    shifts = {
      findById: jest.fn().mockResolvedValue(shift()),
      findOpenForCashier: jest.fn().mockResolvedValue(null),
      findByOfflineRequestId: jest.fn().mockResolvedValue(null),
      open: jest.fn().mockResolvedValue(
        shift({ id: 'shift-new', offlineRequestId: OFFLINE_SHIFT }),
      ),
    } as unknown as jest.Mocked<ShiftRepository>;
    sales = {
      findByOfflineRequestId: jest.fn().mockResolvedValue(null),
      createOffline: jest
        .fn()
        .mockImplementation(async (input) => ({
          sale: { id: `sale-for-${input.offlineRequestId}` },
          created: true,
        })),
    } as unknown as jest.Mocked<SaleRepository>;
    products = {
      findManyByIds: jest.fn().mockResolvedValue([vip()]),
    } as unknown as jest.Mocked<ProductRepository>;
    discounts = {
      findById: jest.fn().mockResolvedValue(discount()),
    } as unknown as jest.Mocked<DiscountRepository>;
    useCase = new SyncOfflineSalesUseCase(shifts, sales, products, discounts);
  });

  it('records the sale at the printed price even if the product changed since', async () => {
    const result = await useCase.execute(command());

    expect(result.sales).toEqual([
      { offlineRequestId: SALE_A, status: 'created', saleId: `sale-for-${SALE_A}`, error: null },
    ]);
    expect(sales.createOffline).toHaveBeenCalledWith({
      offlineRequestId: SALE_A,
      cashierId: 'cashier-1',
      shiftId: 'shift-1',
      branchId: 'branch-1',
      createdAt: RUNG,
      syncedAt: NOW,
      lines: [{ productId: 'vip', nameSnapshot: 'VIP', priceSnapshotUzs: 75_000, qty: 2 }],
      discount: null,
      grossUzs: 150_000,
      discountUzs: 0,
      subtotalUzs: 150_000,
      cashUzs: 150_000,
      cardUzs: 0,
    });
  });

  it('honours a discount disabled during the outage, at the value the terminal used', async () => {
    await useCase.execute(
      command({
        sales: [sale({ discount: { id: 'disc-1', kind: 'percent', value: 10 }, cashUzs: 135_000 })],
      }),
    );

    expect(sales.createOffline).toHaveBeenCalledWith(
      expect.objectContaining({
        discount: { id: 'disc-1', name: 'Flayer', kind: 'percent', value: 10 },
        discountUzs: 15_000,
        subtotalUzs: 135_000,
      }),
    );
  });

  it('refuses an entry-scope discount on a goods sale', async () => {
    discounts.findById.mockResolvedValue(discount({ scope: 'entry' }));

    const result = await useCase.execute(
      command({ sales: [sale({ discount: { id: 'disc-1', kind: 'percent', value: 10 } })] }),
    );

    expect(result.sales[0].status).toBe('rejected');
    expect(result.sales[0].error).toBeInstanceOf(DiscountNotAvailableException);
  });

  it('returns duplicate without writing when the sale was already synced', async () => {
    sales.findByOfflineRequestId.mockResolvedValue({ id: 'sale-old' } as never);

    const result = await useCase.execute(command());

    expect(result.sales[0]).toEqual({
      offlineRequestId: SALE_A,
      status: 'duplicate',
      saleId: 'sale-old',
      error: null,
    });
    expect(sales.createOffline).not.toHaveBeenCalled();
  });

  it('reports duplicate when a concurrent request won the race', async () => {
    sales.createOffline.mockResolvedValue({ sale: { id: 'sale-race' }, created: false } as never);

    const result = await useCase.execute(command());

    expect(result.sales[0]).toMatchObject({ status: 'duplicate', saleId: 'sale-race' });
  });

  it('rejects one bad sale without blocking the rest of the batch', async () => {
    products.findManyByIds.mockImplementation(async (ids: string[]) =>
      ids.includes('foreign') ? [vip({ id: 'foreign', branchId: 'branch-2' })] : [vip()],
    );

    const result = await useCase.execute(
      command({
        sales: [
          sale({ lines: [{ productId: 'foreign', qty: 1, priceSnapshotUzs: 75_000 }] }),
          sale({ offlineRequestId: SALE_B }),
        ],
      }),
    );

    expect(result.sales[0].status).toBe('rejected');
    expect(result.sales[0].error).toBeInstanceOf(ProductNotFoundException);
    expect(result.sales[1]).toMatchObject({ offlineRequestId: SALE_B, status: 'created' });
  });

  it('rejects an underpaid receipt', async () => {
    const result = await useCase.execute(command({ sales: [sale({ cashUzs: 100_000 })] }));

    expect(result.sales[0].error).toBeInstanceOf(SalePaymentMismatchException);
    expect(sales.createOffline).not.toHaveBeenCalled();
  });

  it('opens an offline shift first and attaches its sales to it', async () => {
    const result = await useCase.execute(
      command({
        shifts: [{ offlineRequestId: OFFLINE_SHIFT, openedAt: OPENED, openingCashUzs: 20_000 }],
        sales: [sale({ shiftId: null, shiftOfflineRequestId: OFFLINE_SHIFT })],
      }),
    );

    expect(shifts.open).toHaveBeenCalledWith({
      cashierId: 'cashier-1',
      branchId: 'branch-1',
      openingCashUzs: 20_000,
      offlineRequestId: OFFLINE_SHIFT,
      openedAt: OPENED,
    });
    expect(result.shifts).toEqual([
      { offlineRequestId: OFFLINE_SHIFT, status: 'created', shiftId: 'shift-new', error: null },
    ]);
    expect(sales.createOffline).toHaveBeenCalledWith(
      expect.objectContaining({ shiftId: 'shift-new' }),
    );
  });

  it('never dates an offline shift in the future', async () => {
    const future = new Date('2026-09-24T00:00:00.000Z');

    await useCase.execute(
      command({
        shifts: [{ offlineRequestId: OFFLINE_SHIFT, openedAt: future, openingCashUzs: null }],
        sales: [],
      }),
    );

    expect(shifts.open).toHaveBeenCalledWith(expect.objectContaining({ openedAt: NOW }));
  });

  it('reuses the cashier open shift instead of opening a second one', async () => {
    shifts.findOpenForCashier.mockResolvedValue(shift({ id: 'shift-online' }));

    const result = await useCase.execute(
      command({
        shifts: [{ offlineRequestId: OFFLINE_SHIFT, openedAt: OPENED, openingCashUzs: 0 }],
        sales: [sale({ shiftId: null, shiftOfflineRequestId: OFFLINE_SHIFT })],
      }),
    );

    expect(shifts.open).not.toHaveBeenCalled();
    expect(result.shifts[0]).toMatchObject({ status: 'duplicate', shiftId: 'shift-online' });
    expect(sales.createOffline).toHaveBeenCalledWith(
      expect.objectContaining({ shiftId: 'shift-online' }),
    );
  });

  it('treats an already-synced offline shift as a duplicate', async () => {
    shifts.findByOfflineRequestId.mockResolvedValue(shift({ id: 'shift-prev' }));

    const result = await useCase.execute(
      command({
        shifts: [{ offlineRequestId: OFFLINE_SHIFT, openedAt: OPENED, openingCashUzs: 0 }],
        sales: [],
      }),
    );

    expect(result.shifts[0]).toMatchObject({ status: 'duplicate', shiftId: 'shift-prev' });
    expect(shifts.open).not.toHaveBeenCalled();
  });

  it('finds an offline shift synced by an earlier request when a sale is retried alone', async () => {
    shifts.findByOfflineRequestId.mockResolvedValue(shift({ id: 'shift-prev' }));

    await useCase.execute(
      command({ sales: [sale({ shiftId: null, shiftOfflineRequestId: OFFLINE_SHIFT })] }),
    );

    expect(sales.createOffline).toHaveBeenCalledWith(
      expect.objectContaining({ shiftId: 'shift-prev' }),
    );
  });

  it("rejects a sale pointing at another cashier's shift", async () => {
    shifts.findById.mockResolvedValue(shift({ cashierId: 'cashier-2' }));

    const result = await useCase.execute(command());

    expect(result.sales[0].error).toBeInstanceOf(OfflineShiftNotFoundException);
  });

  it('clamps the sale time into the shift window', async () => {
    shifts.findById.mockResolvedValue(
      shift({ closedAt: new Date('2026-09-23T11:00:00.000Z'), status: 'closed' }),
    );

    await useCase.execute(
      command({
        sales: [
          sale({ offlineRequestId: SALE_A, createdAt: new Date('2026-09-23T05:00:00.000Z') }),
          sale({ offlineRequestId: SALE_B, createdAt: new Date('2026-09-23T23:00:00.000Z') }),
        ],
      }),
    );

    expect(sales.createOffline.mock.calls[0][0].createdAt).toEqual(OPENED);
    expect(sales.createOffline.mock.calls[1][0].createdAt).toEqual(
      new Date('2026-09-23T11:00:00.000Z'),
    );
  });

  it('lets an unexpected infrastructure error fail the whole request', async () => {
    sales.createOffline.mockRejectedValue(new Error('db down'));

    await expect(useCase.execute(command())).rejects.toThrow('db down');
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npx jest src/modules/pos/application/sync-offline-sales.use-case.spec.ts`
Expected: FAIL: `Cannot find module './sync-offline-sales.use-case'`.

- [ ] **Step 3: Add the exception and i18n**

Append to `pos.exceptions.ts`:

```ts
/** An offline sale names a shift that doesn't exist or isn't this cashier's. */
export class OfflineShiftNotFoundException extends DomainException {
  readonly code = 'OFFLINE_SHIFT_NOT_FOUND';
  readonly status = NOT_FOUND;
  constructor() {
    super('The shift this offline sale belongs to was not found');
  }
}
```

Add next to `PRODUCT_OFFLINE_ONLY`:
- `en.ts`: `OFFLINE_SHIFT_NOT_FOUND: 'The shift this offline sale belongs to was not found',`
- `uz.ts`: `OFFLINE_SHIFT_NOT_FOUND: 'Bu offline savdoning smenasi topilmadi',`
- `ru.ts`: `OFFLINE_SHIFT_NOT_FOUND: 'Смена этой офлайн-продажи не найдена',`

- [ ] **Step 4: Implement the use case**

Create `src/modules/pos/application/sync-offline-sales.use-case.ts`:

```ts
import { Injectable } from '@nestjs/common';
import { DomainException } from '../../../common/exceptions/domain.exception';
import {
  applyDiscount,
  DiscountKind,
  isValidDiscountValue,
} from '../domain/discount.entity';
import {
  DiscountInvalidValueException,
  DiscountNotAvailableException,
  DiscountNotFoundException,
  EmptySaleException,
  OfflineShiftNotFoundException,
  ProductNotFoundException,
  SalePaymentMismatchException,
} from '../domain/pos.exceptions';
import { CreateOfflineSaleInput } from '../domain/sale.entity';
import { Shift } from '../domain/shift.entity';
import { DiscountRepository } from './ports/discount.repository';
import { ProductRepository } from './ports/product.repository';
import { SaleRepository } from './ports/sale.repository';
import { ShiftRepository } from './ports/shift.repository';

export interface OfflineShiftInput {
  offlineRequestId: string;
  openedAt: Date;
  openingCashUzs: number | null;
}

export interface OfflineSaleLineInput {
  productId: string;
  qty: number;
  priceSnapshotUzs: number;
}

export interface OfflineSaleInput {
  offlineRequestId: string;
  /** The server shift the terminal had cached when it rang this up… */
  shiftId?: string | null;
  /** …or a shift the terminal itself opened while offline. */
  shiftOfflineRequestId?: string | null;
  createdAt: Date;
  lines: OfflineSaleLineInput[];
  discount: { id: string; kind: DiscountKind; value: number } | null;
  cashUzs: number;
  cardUzs: number;
}

export interface SyncOfflineSalesCommand {
  cashierId: string;
  branchId: string;
  now: Date;
  shifts: OfflineShiftInput[];
  sales: OfflineSaleInput[];
}

export type OfflineSyncStatus = 'created' | 'duplicate' | 'rejected';

export interface OfflineShiftResult {
  offlineRequestId: string;
  status: OfflineSyncStatus;
  shiftId: string | null;
  error: DomainException | null;
}

export interface OfflineSaleResult {
  offlineRequestId: string;
  status: OfflineSyncStatus;
  saleId: string | null;
  error: DomainException | null;
}

export interface SyncOfflineSalesResult {
  shifts: OfflineShiftResult[];
  sales: OfflineSaleResult[];
}

/** Replays what a cashier terminal rang up while it had no internet.
 *
 *  - Shifts first, so sales can attach to a shift opened offline.
 *  - Per-sale isolation: a business-rule violation rejects only that sale;
 *    an infrastructure error fails the whole request (the terminal keeps
 *    everything queued and retries — idempotency makes that safe).
 *  - Trust the paper, verify the arithmetic: lines are recorded at the
 *    terminal's price snapshots and the discount at the kind/value it used,
 *    so the database matches the receipt the customer holds — even if an
 *    admin changed a price or disabled the discount during the outage. The
 *    cashier, branch, product ownership and totals are still checked. */
@Injectable()
export class SyncOfflineSalesUseCase {
  constructor(
    private readonly shifts: ShiftRepository,
    private readonly sales: SaleRepository,
    private readonly products: ProductRepository,
    private readonly discounts: DiscountRepository,
  ) {}

  async execute(command: SyncOfflineSalesCommand): Promise<SyncOfflineSalesResult> {
    const shiftResults: OfflineShiftResult[] = [];
    const offlineShifts = new Map<string, Shift>();
    for (const input of command.shifts) {
      const { result, shift } = await this.resolveShift(command, input);
      shiftResults.push(result);
      if (shift) offlineShifts.set(input.offlineRequestId, shift);
    }

    const saleResults: OfflineSaleResult[] = [];
    for (const input of command.sales) {
      saleResults.push(await this.syncSale(command, input, offlineShifts));
    }
    return { shifts: shiftResults, sales: saleResults };
  }

  private async resolveShift(
    command: SyncOfflineSalesCommand,
    input: OfflineShiftInput,
  ): Promise<{ result: OfflineShiftResult; shift: Shift | null }> {
    const { offlineRequestId } = input;
    const existing = await this.shifts.findByOfflineRequestId(offlineRequestId);
    if (existing) {
      if (existing.cashierId !== command.cashierId) {
        return {
          result: {
            offlineRequestId,
            status: 'rejected',
            shiftId: null,
            error: new OfflineShiftNotFoundException(),
          },
          shift: null,
        };
      }
      return {
        result: { offlineRequestId, status: 'duplicate', shiftId: existing.id, error: null },
        shift: existing,
      };
    }

    // The cashier opened a shift online elsewhere meanwhile — never give
    // them a second concurrent open shift.
    const open = await this.shifts.findOpenForCashier(command.cashierId);
    if (open) {
      return {
        result: { offlineRequestId, status: 'duplicate', shiftId: open.id, error: null },
        shift: open,
      };
    }

    const created = await this.shifts.open({
      cashierId: command.cashierId,
      branchId: command.branchId,
      openingCashUzs: input.openingCashUzs,
      offlineRequestId,
      openedAt: earliest(input.openedAt, command.now),
    });
    return {
      result: { offlineRequestId, status: 'created', shiftId: created.id, error: null },
      shift: created,
    };
  }

  private async syncSale(
    command: SyncOfflineSalesCommand,
    input: OfflineSaleInput,
    offlineShifts: Map<string, Shift>,
  ): Promise<OfflineSaleResult> {
    const { offlineRequestId } = input;
    const existing = await this.sales.findByOfflineRequestId(offlineRequestId);
    if (existing) {
      return { offlineRequestId, status: 'duplicate', saleId: existing.id, error: null };
    }

    try {
      const shift = await this.shiftFor(command, input, offlineShifts);
      const priced = await this.price(command, input);
      const { sale, created } = await this.sales.createOffline({
        offlineRequestId,
        cashierId: command.cashierId,
        shiftId: shift.id,
        branchId: command.branchId,
        createdAt: clamp(input.createdAt, shift.openedAt, shift.closedAt ?? command.now),
        syncedAt: command.now,
        cashUzs: input.cashUzs,
        cardUzs: input.cardUzs,
        ...priced,
      });
      return {
        offlineRequestId,
        status: created ? 'created' : 'duplicate',
        saleId: sale.id,
        error: null,
      };
    } catch (error) {
      if (error instanceof DomainException) {
        return { offlineRequestId, status: 'rejected', saleId: null, error };
      }
      throw error;
    }
  }

  private async shiftFor(
    command: SyncOfflineSalesCommand,
    input: OfflineSaleInput,
    offlineShifts: Map<string, Shift>,
  ): Promise<Shift> {
    let shift: Shift | null = null;
    if (input.shiftOfflineRequestId) {
      shift =
        offlineShifts.get(input.shiftOfflineRequestId) ??
        (await this.shifts.findByOfflineRequestId(input.shiftOfflineRequestId));
    } else if (input.shiftId) {
      shift = await this.shifts.findById(input.shiftId);
    }
    if (!shift || shift.cashierId !== command.cashierId) {
      throw new OfflineShiftNotFoundException();
    }
    return shift;
  }

  private async price(
    command: SyncOfflineSalesCommand,
    input: OfflineSaleInput,
  ): Promise<
    Pick<
      CreateOfflineSaleInput,
      'lines' | 'discount' | 'grossUzs' | 'discountUzs' | 'subtotalUzs'
    >
  > {
    if (input.lines.length === 0) throw new EmptySaleException();

    const products = await this.products.findManyByIds(
      input.lines.map((line) => line.productId),
    );
    const byId = new Map(products.map((p) => [p.id, p]));

    let grossUzs = 0;
    const lines = input.lines.map((line) => {
      const product = byId.get(line.productId);
      // `active` is deliberately not required: it may have been switched
      // off during the outage, after the customer already paid for it.
      if (!product || product.branchId !== command.branchId) {
        throw new ProductNotFoundException();
      }
      grossUzs += line.priceSnapshotUzs * line.qty;
      return {
        productId: product.id,
        nameSnapshot: product.name,
        priceSnapshotUzs: line.priceSnapshotUzs,
        qty: line.qty,
      };
    });

    let discount: CreateOfflineSaleInput['discount'] = null;
    let discountUzs = 0;
    if (input.discount) {
      const row = await this.discounts.findById(input.discount.id);
      if (!row) throw new DiscountNotFoundException();
      if (row.scope !== 'goods') throw new DiscountNotAvailableException();
      if (!isValidDiscountValue(input.discount.kind, input.discount.value)) {
        throw new DiscountInvalidValueException();
      }
      discountUzs = applyDiscount(grossUzs, input.discount).discountUzs;
      discount = {
        id: row.id,
        name: row.name,
        kind: input.discount.kind,
        value: input.discount.value,
      };
    }

    const subtotalUzs = grossUzs - discountUzs;
    if (input.cashUzs + input.cardUzs < subtotalUzs) {
      throw new SalePaymentMismatchException();
    }
    return { lines, discount, grossUzs, discountUzs, subtotalUzs };
  }
}

function earliest(a: Date, b: Date): Date {
  return a.getTime() <= b.getTime() ? a : b;
}

function clamp(at: Date, from: Date, to: Date): Date {
  return new Date(Math.min(Math.max(at.getTime(), from.getTime()), to.getTime()));
}
```

- [ ] **Step 5: Run the tests**

Run: `npx jest src/modules/pos/application/sync-offline-sales.use-case.spec.ts`
Expected: PASS (15 tests).

Run: `npx jest src/modules/pos && npx tsc --noEmit -p tsconfig.json`
Expected: everything passes.

- [ ] **Step 6: Commit**

```bash
git add src/modules/pos src/i18n/messages
git commit -m "feat(pos): replay offline sales with per-sale isolation and printed prices

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `POST /v1/pos/offline/sync` endpoint

**Files:**
- Create: `src/modules/pos/presentation/dto/offline-sync.dto.ts`
- Modify: `src/modules/pos/presentation/responses/pos-response.types.ts`
- Modify: `src/modules/pos/presentation/mappers/pos-response.mapper.ts`
- Modify: `src/modules/pos/presentation/pos.controller.ts`
- Modify: `src/modules/pos/pos.module.ts` (providers list, next to `CheckoutSaleUseCase` ~L173)
- Test: `src/modules/pos/presentation/dto/offline-sync.dto.spec.ts`, `src/modules/pos/presentation/mappers/offline-sync-response.mapper.spec.ts`

**Interfaces:**
- Consumes: `SyncOfflineSalesUseCase.execute(command)`, `SyncOfflineSalesResult` (Task 4), `Translator.translateAll(code, params, fallback): LocalizedText`
- Produces: the HTTP contract the cashier app (Plan 3) codes against:

```jsonc
// POST /api/v1/pos/offline/sync  → 200
// request
{ "shifts": [{ "offlineRequestId": "uuid", "openedAt": "iso", "openingCashUzs": 0 }],
  "sales":  [{ "offlineRequestId": "uuid", "shiftId": "uuid?", "shiftOfflineRequestId": "uuid?",
               "createdAt": "iso", "lines": [{ "productId": "uuid", "qty": 1, "priceSnapshotUzs": 75000 }],
               "discount": { "id": "uuid", "kind": "percent|fixed", "value": 10 },   // optional
               "cashUzs": 75000, "cardUzs": 0 }] }
// response
{ "shifts": [{ "offlineRequestId": "uuid", "status": "created|duplicate|rejected", "shiftId": "uuid|null",
               "code": "string|null", "message": { "uz": "…", "ru": "…", "en": "…" } | null }],
  "sales":  [{ "offlineRequestId": "uuid", "status": "created|duplicate|rejected", "saleId": "uuid|null",
               "code": "string|null", "message": { … } | null }] }
```

- [ ] **Step 1: Write the failing tests**

Create `src/modules/pos/presentation/dto/offline-sync.dto.spec.ts`:

```ts
import 'reflect-metadata';

import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import { OfflineSyncDto } from './offline-sync.dto';

const UUID = (n: number) => `${String(n).repeat(8)}-${String(n).repeat(4)}-4${String(n).repeat(3)}-8${String(n).repeat(3)}-${String(n).repeat(12)}`;

const body = (overrides: Record<string, unknown> = {}) =>
  plainToInstance(OfflineSyncDto, {
    shifts: [{ offlineRequestId: UUID(1), openedAt: '2026-09-23T08:00:00.000Z', openingCashUzs: 0 }],
    sales: [
      {
        offlineRequestId: UUID(2),
        shiftOfflineRequestId: UUID(1),
        createdAt: '2026-09-23T10:00:00.000Z',
        lines: [{ productId: UUID(3), qty: 2, priceSnapshotUzs: 75_000 }],
        discount: { id: UUID(4), kind: 'percent', value: 10 },
        cashUzs: 135_000,
        cardUzs: 0,
      },
    ],
    ...overrides,
  });

describe('OfflineSyncDto', () => {
  it('accepts a well-formed payload and turns ISO strings into Dates', async () => {
    const dto = body();

    await expect(validate(dto)).resolves.toHaveLength(0);
    expect(dto.sales[0].createdAt).toBeInstanceOf(Date);
    expect(dto.shifts[0].openedAt).toBeInstanceOf(Date);
  });

  it('rejects a zero quantity', async () => {
    const dto = body();
    dto.sales[0].lines[0].qty = 0;

    await expect(validate(dto)).resolves.not.toHaveLength(0);
  });

  it('rejects an unknown discount kind', async () => {
    const dto = body();
    (dto.sales[0].discount as { kind: string }).kind = 'bogo';

    await expect(validate(dto)).resolves.not.toHaveLength(0);
  });

  it('caps one request at 200 sales', async () => {
    const one = body().sales[0];
    const dto = body({ sales: Array.from({ length: 201 }, () => ({ ...one })) });

    await expect(validate(dto)).resolves.not.toHaveLength(0);
  });
});
```

Create `src/modules/pos/presentation/mappers/offline-sync-response.mapper.spec.ts`:

```ts
import { Translator } from '../../../../i18n/translator';
import { SalePaymentMismatchException } from '../../domain/pos.exceptions';
import { toOfflineSyncResponse } from './pos-response.mapper';

describe('toOfflineSyncResponse', () => {
  it('renders rejected items with their code and message in every language', () => {
    const response = toOfflineSyncResponse(
      {
        shifts: [{ offlineRequestId: 'shift-a', status: 'created', shiftId: 'shift-1', error: null }],
        sales: [
          { offlineRequestId: 'sale-a', status: 'created', saleId: 'sale-1', error: null },
          {
            offlineRequestId: 'sale-b',
            status: 'rejected',
            saleId: null,
            error: new SalePaymentMismatchException(),
          },
        ],
      },
      new Translator(),
    );

    expect(response.shifts).toEqual([
      { offlineRequestId: 'shift-a', status: 'created', shiftId: 'shift-1', code: null, message: null },
    ]);
    expect(response.sales[0]).toEqual({
      offlineRequestId: 'sale-a',
      status: 'created',
      saleId: 'sale-1',
      code: null,
      message: null,
    });
    expect(response.sales[1].code).toBe('SALE_PAYMENT_MISMATCH');
    expect(Object.keys(response.sales[1].message!).sort()).toEqual(['en', 'ru', 'uz']);
  });
});
```

(Before running: check the real `code` string of `SalePaymentMismatchException` in `pos.exceptions.ts` and use it in the assertion.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest src/modules/pos/presentation/dto/offline-sync.dto.spec.ts src/modules/pos/presentation/mappers/offline-sync-response.mapper.spec.ts`
Expected: FAIL: cannot find `./offline-sync.dto` / `toOfflineSyncResponse` isn't exported.

- [ ] **Step 3: DTO**

Create `src/modules/pos/presentation/dto/offline-sync.dto.ts`:

```ts
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDate,
  IsIn,
  IsInt,
  IsOptional,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';
import { DISCOUNT_KINDS } from '../../domain/discount.entity';
import type { DiscountKind } from '../../domain/discount.entity';

export class OfflineShiftDto {
  @IsUUID()
  offlineRequestId: string;

  @Type(() => Date)
  @IsDate()
  openedAt: Date;

  @IsOptional()
  @IsInt()
  @Min(0)
  openingCashUzs?: number;
}

export class OfflineSaleLineDto {
  @IsUUID()
  productId: string;

  @IsInt()
  @Min(1)
  qty: number;

  /** The unit price printed on the offline receipt. */
  @IsInt()
  @Min(0)
  priceSnapshotUzs: number;
}

export class OfflineDiscountDto {
  @IsUUID()
  id: string;

  @IsIn(DISCOUNT_KINDS)
  kind: DiscountKind;

  @IsInt()
  @Min(1)
  value: number;
}

export class OfflineSaleDto {
  @IsUUID()
  offlineRequestId: string;

  @IsOptional()
  @IsUUID()
  shiftId?: string;

  @IsOptional()
  @IsUUID()
  shiftOfflineRequestId?: string;

  @Type(() => Date)
  @IsDate()
  createdAt: Date;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => OfflineSaleLineDto)
  lines: OfflineSaleLineDto[];

  @IsOptional()
  @ValidateNested()
  @Type(() => OfflineDiscountDto)
  discount?: OfflineDiscountDto;

  @IsInt()
  @Min(0)
  cashUzs: number;

  @IsInt()
  @Min(0)
  cardUzs: number;
}

/** Offline replay batch. The terminal splits a longer queue into several
 *  requests of at most 200 sales. */
export class OfflineSyncDto {
  @IsArray()
  @ArrayMaxSize(5)
  @ValidateNested({ each: true })
  @Type(() => OfflineShiftDto)
  shifts: OfflineShiftDto[];

  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => OfflineSaleDto)
  sales: OfflineSaleDto[];
}
```

- [ ] **Step 4: Response types and mapper**

Append to `pos-response.types.ts` (import `LocalizedText` from `'../../../../i18n/locale'`):

```ts
export type OfflineSyncItemStatus = 'created' | 'duplicate' | 'rejected';

export interface OfflineSyncShiftResponse {
  offlineRequestId: string;
  status: OfflineSyncItemStatus;
  shiftId: string | null;
  code: string | null;
  message: LocalizedText | null;
}

export interface OfflineSyncSaleResponse {
  offlineRequestId: string;
  status: OfflineSyncItemStatus;
  saleId: string | null;
  code: string | null;
  message: LocalizedText | null;
}

export interface OfflineSyncResponse {
  shifts: OfflineSyncShiftResponse[];
  sales: OfflineSyncSaleResponse[];
}
```

Append to `pos-response.mapper.ts` (add imports: `Translator` from `'../../../../i18n/translator'`, `DomainException` from `'../../../../common/exceptions/domain.exception'`, `SyncOfflineSalesResult` from `'../../application/sync-offline-sales.use-case'`, plus the three response types):

```ts
export function toOfflineSyncResponse(
  result: SyncOfflineSalesResult,
  translator: Translator,
): OfflineSyncResponse {
  const errorFields = (error: DomainException | null) =>
    error
      ? {
          code: error.code,
          message: translator.translateAll(error.code, error.params, error.message),
        }
      : { code: null, message: null };

  return {
    shifts: result.shifts.map((item) => ({
      offlineRequestId: item.offlineRequestId,
      status: item.status,
      shiftId: item.shiftId,
      ...errorFields(item.error),
    })),
    sales: result.sales.map((item) => ({
      offlineRequestId: item.offlineRequestId,
      status: item.status,
      saleId: item.saleId,
      ...errorFields(item.error),
    })),
  };
}
```

- [ ] **Step 5: Controller route and module wiring**

In `pos.controller.ts`:
- Add `HttpCode` to the `@nestjs/common` import.
- Import `OfflineSyncDto`, `SyncOfflineSalesUseCase`, `Translator` (from `'../../../i18n/translator'`), `toOfflineSyncResponse`, and `OfflineSyncResponse`.
- Add these at the end of the constructor parameter list:

```ts
    private readonly syncOfflineSales: SyncOfflineSalesUseCase,
    private readonly translator: Translator,
```

- Add the route after `checkout`:

```ts
  /** Replays sales the terminal rang up while it had no internet — see
   *  `SyncOfflineSalesUseCase`. Always 200: each shift/sale carries its own
   *  created | duplicate | rejected status. */
  @Post('offline/sync')
  @HttpCode(200)
  async syncOffline(
    @CurrentCashier() current: CashierContext,
    @Body() dto: OfflineSyncDto,
  ): Promise<OfflineSyncResponse> {
    const result = await this.syncOfflineSales.execute({
      cashierId: current.cashier.id,
      branchId: current.branch.id,
      now: new Date(),
      shifts: dto.shifts.map((shift) => ({
        offlineRequestId: shift.offlineRequestId,
        openedAt: shift.openedAt,
        openingCashUzs: shift.openingCashUzs ?? null,
      })),
      sales: dto.sales.map((sale) => ({
        offlineRequestId: sale.offlineRequestId,
        shiftId: sale.shiftId ?? null,
        shiftOfflineRequestId: sale.shiftOfflineRequestId ?? null,
        createdAt: sale.createdAt,
        lines: sale.lines,
        discount: sale.discount ?? null,
        cashUzs: sale.cashUzs,
        cardUzs: sale.cardUzs,
      })),
    });
    return toOfflineSyncResponse(result, this.translator);
  }
```

In `pos.module.ts`: import `SyncOfflineSalesUseCase` and add it to `providers` directly after `CheckoutSaleUseCase,`.

- [ ] **Step 6: Run the tests and boot check**

Run: `npx jest src/modules/pos && npx tsc --noEmit -p tsconfig.json && npm run build`
Expected: all pass; `nest build` succeeds.

- [ ] **Step 7: Commit**

```bash
git add src/modules/pos
git commit -m "feat(pos): POST /pos/offline/sync endpoint for the cashier terminal

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Make offline-synced sales visible in history, admin list and export

**Files:**
- Modify: `src/modules/pos/presentation/responses/pos-response.types.ts` (`SaleResponse`), `admin-pos-response.types.ts` (`AdminSaleResponse`)
- Modify: `src/modules/pos/presentation/mappers/pos-response.mapper.ts` (`toSaleResponse`), `admin-pos-response.mapper.ts` (`toAdminSaleResponse`)
- Modify: `src/modules/pos/presentation/export/sales-workbook.builder.ts`
- Test: `src/modules/pos/presentation/export/sales-workbook.builder.spec.ts` (add a case), `src/modules/pos/presentation/mappers/offline-sync-response.mapper.spec.ts` (add a case)

**Interfaces:**
- Consumes: `Sale.offlineSyncedAt` (Task 1)
- Produces: `SaleResponse.offlineSyncedAt: Date | null` and `AdminSaleResponse.offlineSyncedAt: Date | null`, consumed by the Dashboard (Plan 2) and the cashier history (Plan 3)

- [ ] **Step 1: Write the failing tests**

Add to `sales-workbook.builder.spec.ts` inside `describe('buildSalesWorkbook')`:

```ts
  it('flags a receipt that was rung up offline', async () => {
    const rows: SalesExportRow[] = [
      {
        sale: saleRow({
          type: 'GOODS_CHECKOUT',
          cashierId: 'cashier-1',
          offlineSyncedAt: new Date('2026-09-23T12:00:00.000Z'),
        }),
        branchName: 'Chilonzor',
        cashierName: 'Dilnoza',
        customerName: null,
      },
      {
        sale: saleRow({ id: 'sale-2', type: 'GOODS_CHECKOUT', cashierId: 'cashier-1' }),
        branchName: 'Chilonzor',
        cashierName: 'Dilnoza',
        customerName: null,
      },
    ];

    const [header, offlineRow, onlineRow] = await readSheetRows(
      await buildSalesWorkbook(rows),
    );

    expect(header).toContain('Offline');
    expect(offlineRow).toContain('Ha');
    expect(onlineRow).not.toContain('Ha');
  });
```

Add to `offline-sync-response.mapper.spec.ts`. Import `toSaleResponse` alongside `toOfflineSyncResponse`, and `Sale` from `'../../domain/sale.entity'`:

```ts
describe('toSaleResponse offline flag', () => {
  const base = {
    id: 'sale-1',
    type: 'GOODS_CHECKOUT',
    cashierId: 'cashier-1',
    shiftId: 'shift-1',
    branchId: 'branch-1',
    customerId: null,
    subtotalUzs: 75_000,
    grossUzs: 75_000,
    discountUzs: 0,
    cashUzs: 75_000,
    cardUzs: 0,
    balanceUzs: 0,
    paymentProvider: null,
    status: 'paid',
    discount: null,
    createdAt: new Date('2026-09-23T10:00:00.000Z'),
    items: [],
  } as unknown as Sale;

  it('exposes offlineSyncedAt, null for online sales', () => {
    const syncedAt = new Date('2026-09-23T12:00:00.000Z');

    expect(toSaleResponse(base).offlineSyncedAt).toBeNull();
    expect(toSaleResponse({ ...base, offlineSyncedAt: syncedAt }).offlineSyncedAt).toEqual(syncedAt);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx jest src/modules/pos/presentation`
Expected: FAIL, because `offlineSyncedAt` is `undefined` and there's no `Offline` header.

- [ ] **Step 3: Implement**

`SaleResponse` and `AdminSaleResponse`: add

```ts
  /** Set when this receipt was rung up on an offline terminal and synced later. */
  offlineSyncedAt: Date | null;
```

`toSaleResponse` and `toAdminSaleResponse`: add `offlineSyncedAt: sale.offlineSyncedAt ?? null,` next to `createdAt`.

`sales-workbook.builder.ts`: add to the columns array after `customer`:

```ts
    { header: 'Offline', key: 'offline', width: 10 },
```

and to `sheet.addRow({...})`:

```ts
      offline: sale.offlineSyncedAt ? 'Ha' : '',
```

- [ ] **Step 4: Run the tests**

Run: `npx jest src/modules/pos && npx tsc --noEmit -p tsconfig.json`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add src/modules/pos
git commit -m "feat(pos): mark offline-synced receipts in history, admin list and export

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Full verification

- [ ] **Step 1:** `npx jest` (whole repo). Expected: every suite passes; report the counts.
- [ ] **Step 2:** `npx eslint "src/modules/pos/**/*.ts" "src/i18n/**/*.ts"`. Expected: no errors. Fix only what this branch introduced.
- [ ] **Step 3:** `npm run build`. Expected: success.
- [ ] **Step 4:** `git log --oneline origin/development..HEAD`. Expected: the 6 commits above.
- [ ] **Step 5:** Stop and report to the user. Don't push; pushing to GitLab and opening the MR to `development` need their go-ahead.
