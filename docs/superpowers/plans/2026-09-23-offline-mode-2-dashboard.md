# Offline Mode — Plan 2 of 3: Dashboard

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Admins can mark a POS product "Faqat offline rejimda" (only in offline mode) when creating or editing it. The products table shows which products are offline-only, and the sales list shows which receipts were rung up offline.

**Architecture:** The `product` entity carries `offlineOnly` end to end (DTO → model → API inputs). Form-to-API mapping moves into a pure `lib/product-form.ts`, so the page stays thin and the mapping is unit-tested. A small `OfflineOnlyField` component renders the checkbox. The `sale` entity gains `offlineSyncedAt`, and `SaleRow` shows a badge for it.

**Tech Stack:** Next.js (App Router, read `node_modules/next/dist/docs/` before touching routing APIs), next-intl (uz/ru only), TanStack Query, radix-ui `Checkbox`, Vitest 4 (`npm test`).

**Spec:** `cashier_app/docs/superpowers/specs/2026-09-23-offline-mode-design.md` (Part 2). **Depends on:** Plan 1, which adds `offlineOnly` to `/v1/admin/products` and `offlineSyncedAt` to `/v1/admin/sales`. Every new field is read with a `?? false` / `?? null` fallback, so this plan is safe to deploy even before the backend.

## Global Constraints

- Work only in the worktree `/Users/apple/Projects/Pixel_projects/Dashboard/.worktrees/pos-offline-only-products` (branch `feat/pos-offline-only-products`, cut from `origin/stage` @ `eda0369`). Don't touch the main checkout; it has someone's uncommitted work.
- Follow `AGENTS.md`: Feature-Sliced layers; types in `model/`, pure logic in `lib/` (no React), UI in `ui/`; files well under ~150 lines; import slices from their root (`@/entities/product`).
- Every UI string goes in both `src/shared/config/i18n/messages/uz/*.json` and `ru/*.json`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Pushing and opening the MR to `stage` happen only after the user approves.
- **Baseline** (`npm test` on `origin/stage`, local Node): 272 tests pass, plus 20 *pre-existing* jsdom worker errors (`ERR_REQUIRE_ESM` in `html-encoding-sniffer`, a local-Node incompatibility, not a test failure). The new tests in this plan all run in the `node` environment and aren't affected. "All pass" below means 272 + new tests pass, with the same 20 errors and no new ones.

## File map

| File | Change |
|------|--------|
| `src/entities/product/model/types.ts` | Add `offlineOnly` |
| `src/entities/product/api/product-dto.ts` | Map `offlineOnly` with a `?? false` fallback |
| `src/entities/product/api/product-api.ts` | Add `offlineOnly` to the create/update inputs |
| `src/entities/product/api/product-dto.test.ts` | New |
| `src/views/products/lib/product-form.ts` | New: form values → API inputs, and product → form values |
| `src/views/products/lib/product-form.test.ts` | New |
| `src/views/products/ui/offline-only-field.tsx` | New: the checkbox and its hint |
| `src/views/products/ui/product-form-dialog.tsx` | Use the lib and the field |
| `src/views/products/ui/products-page.tsx` | Use the lib in `handleSubmit` |
| `src/views/products/ui/product-row.tsx` | Add the "Offline" badge |
| `src/entities/sale/api/sale-dto.ts`, `model/types.ts` | Add `offlineSyncedAt` |
| `src/entities/sale/api/sale-dto.test.ts` | New |
| `src/views/sales/ui/sale-row.tsx` | Add the "Offline" badge next to the date |
| `src/shared/config/i18n/messages/{uz,ru}/products.json`, `sales.json` | New keys |

---

### Task 1: The product entity carries `offlineOnly`

**Files:**
- Modify: `src/entities/product/model/types.ts`, `src/entities/product/api/product-dto.ts`, `src/entities/product/api/product-api.ts`
- Test: `src/entities/product/api/product-dto.test.ts` (new)

**Interfaces:**
- Produces: `Product.offlineOnly: boolean`, `ProductDto.offlineOnly?: boolean`, `CreateProductInput.offlineOnly: boolean`, `UpdateProductInput.offlineOnly?: boolean`

- [ ] **Step 1: Write the failing test**

Create `src/entities/product/api/product-dto.test.ts`:

```ts
import { describe, expect, it } from "vitest";

import { type ProductDto, toProduct } from "./product-dto";

const dto = (overrides: Partial<ProductDto> = {}): ProductDto => ({
  id: "product-1",
  branchId: "branch-1",
  name: "VIP",
  priceUzs: 75000,
  category: "Tariflar",
  icon: "ph ph-crown",
  active: true,
  createdAt: "2026-09-23T00:00:00.000Z",
  updatedAt: "2026-09-23T00:00:00.000Z",
  ...overrides,
});

describe("toProduct", () => {
  it("reads the offline-only flag", () => {
    expect(toProduct(dto({ offlineOnly: true })).offlineOnly).toBe(true);
  });

  it("treats a backend that predates the flag as an ordinary product", () => {
    expect(toProduct(dto()).offlineOnly).toBe(false);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npx vitest run src/entities/product/api/product-dto.test.ts`
Expected: FAIL. `offlineOnly` is `undefined`, so the assertions fail.

- [ ] **Step 3: Implement**

`model/types.ts`, add to `Product` after `active`:

```ts
  /** Only offered by the cashier terminal's offline mode (e.g. VIP / hourly
   *  plans sold without a QR while the internet is down). */
  offlineOnly: boolean;
```

`product-dto.ts`: add `offlineOnly?: boolean;` to `ProductDto` after `active`, and to `toProduct` add `offlineOnly: dto.offlineOnly ?? false,` after `active`.

`product-api.ts`: add `offlineOnly: boolean;` to `CreateProductInput` and `offlineOnly?: boolean;` to `UpdateProductInput`.

- [ ] **Step 4: Run the test**

Run: `npx vitest run src/entities/product/api/product-dto.test.ts`
Expected: PASS (2 tests). `npm run typecheck` then reports errors in `products-page.tsx` (the `createProduct.mutate` call lacks `offlineOnly`); Task 2 fixes them, so leave them for now.

- [ ] **Step 5: Commit**

```bash
git add src/entities/product
git commit -m "feat(products): carry the offline-only flag in the product entity

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: "Faqat offline rejimda" in the product form, and a badge in the table

**Files:**
- Create: `src/views/products/lib/product-form.ts`, `src/views/products/lib/product-form.test.ts`, `src/views/products/ui/offline-only-field.tsx`
- Modify: `src/views/products/ui/product-form-dialog.tsx`, `src/views/products/ui/products-page.tsx` (`handleSubmit`, ~L113-150), `src/views/products/ui/product-row.tsx`
- Modify: `src/shared/config/i18n/messages/uz/products.json`, `ru/products.json`

**Interfaces:**
- Consumes: `Product`, `CreateProductInput`, `UpdateProductInput` (Task 1)
- Produces:
  - `ProductFormValues` (moved into `lib/product-form.ts`): `{ name; priceUzs: string; category; icon; branchId; offlineOnly: boolean }`
  - `EMPTY_PRODUCT_FORM: ProductFormValues`
  - `productToFormValues(product: Product): ProductFormValues`
  - `toCreateProductInput(values: ProductFormValues): CreateProductInput`
  - `toUpdateProductInput(values: ProductFormValues): UpdateProductInput`

- [ ] **Step 1: Write the failing test**

Create `src/views/products/lib/product-form.test.ts`:

```ts
import { describe, expect, it } from "vitest";

import type { Product } from "@/entities/product";

import {
  EMPTY_PRODUCT_FORM,
  productToFormValues,
  toCreateProductInput,
  toUpdateProductInput,
} from "./product-form";

const values = {
  name: "  VIP  ",
  priceUzs: "75000",
  category: " Tariflar ",
  icon: " ph ph-crown ",
  branchId: "branch-1",
  offlineOnly: true,
};

describe("product form mapping", () => {
  it("starts a new product as an ordinary (online) one", () => {
    expect(EMPTY_PRODUCT_FORM.offlineOnly).toBe(false);
  });

  it("builds a trimmed create payload that keeps the offline-only flag", () => {
    expect(toCreateProductInput(values)).toEqual({
      branchId: "branch-1",
      name: "VIP",
      priceUzs: 75000,
      category: "Tariflar",
      icon: "ph ph-crown",
      offlineOnly: true,
    });
  });

  it("sends the offline-only flag on edit too, but never the branch", () => {
    expect(toUpdateProductInput({ ...values, offlineOnly: false })).toEqual({
      name: "VIP",
      priceUzs: 75000,
      category: "Tariflar",
      icon: "ph ph-crown",
      offlineOnly: false,
    });
  });

  it("reseeds the edit form from an existing product", () => {
    const product: Product = {
      id: "product-1",
      branchId: "branch-1",
      name: "Soatlik",
      priceUzs: 60000,
      category: "Tariflar",
      icon: "ph ph-clock",
      active: true,
      offlineOnly: true,
      createdAt: "2026-09-23T00:00:00.000Z",
    };

    expect(productToFormValues(product)).toEqual({
      name: "Soatlik",
      priceUzs: "60000",
      category: "Tariflar",
      icon: "ph ph-clock",
      branchId: "branch-1",
      offlineOnly: true,
    });
  });
});
```

(If `Product` on stage has fields beyond the ones in Task 1, add them to the literal so it type-checks.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `npx vitest run src/views/products/lib/product-form.test.ts`
Expected: FAIL: `Failed to resolve import "./product-form"`.

- [ ] **Step 3: Implement the lib**

Create `src/views/products/lib/product-form.ts`:

```ts
import type { CreateProductInput, Product, UpdateProductInput } from "@/entities/product";

/** Raw product-dialog state — `priceUzs` stays a string while typing. */
export interface ProductFormValues {
  name: string;
  priceUzs: string;
  category: string;
  icon: string;
  branchId: string;
  /** Shown only in the cashier terminal's offline mode. */
  offlineOnly: boolean;
}

export const EMPTY_PRODUCT_FORM: ProductFormValues = {
  name: "",
  priceUzs: "",
  category: "",
  icon: "ph ph-shopping-bag",
  branchId: "",
  offlineOnly: false,
};

export function productToFormValues(product: Product): ProductFormValues {
  return {
    name: product.name,
    priceUzs: String(product.priceUzs),
    category: product.category,
    icon: product.icon,
    branchId: product.branchId,
    offlineOnly: product.offlineOnly,
  };
}

export function toCreateProductInput(values: ProductFormValues): CreateProductInput {
  return {
    branchId: values.branchId,
    ...toUpdateProductInput(values),
    offlineOnly: values.offlineOnly,
  };
}

/** The branch is fixed once a product exists, so edits never send it. */
export function toUpdateProductInput(
  values: ProductFormValues,
): UpdateProductInput & Omit<CreateProductInput, "branchId"> {
  return {
    name: values.name.trim(),
    priceUzs: Number(values.priceUzs),
    category: values.category.trim(),
    icon: values.icon.trim(),
    offlineOnly: values.offlineOnly,
  };
}
```

- [ ] **Step 4: Run the test**

Run: `npx vitest run src/views/products/lib/product-form.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Add the i18n keys**

`uz/products.json`, add before the closing brace (keep the JSON valid):

```json
  "offlineOnlyLabel": "Faqat offline rejimda",
  "offlineOnlyHint": "Kassada faqat internet yo'qligida ko'rinadi — masalan, QR chiqarib bo'lmaydigan VIP yoki soatlik tarif. Onlayn savdoda sotilmaydi.",
  "offlineBadge": "Offline"
```

`ru/products.json`:

```json
  "offlineOnlyLabel": "Только в офлайн-режиме",
  "offlineOnlyHint": "Показывается на кассе только без интернета — например, VIP или почасовой тариф, для которого нельзя выдать QR. В онлайн-продаже не продаётся.",
  "offlineBadge": "Офлайн"
```

- [ ] **Step 6: The checkbox field**

Create `src/views/products/ui/offline-only-field.tsx`:

```tsx
"use client";

import { WifiOff } from "lucide-react";
import { useTranslations } from "next-intl";

import { Checkbox } from "@/shared/ui/checkbox";

export function OfflineOnlyField({
  checked,
  onChange,
}: {
  checked: boolean;
  onChange: (checked: boolean) => void;
}) {
  const t = useTranslations("products");

  return (
    <label className="border-input flex cursor-pointer items-start gap-3 rounded-md border p-3">
      <Checkbox
        checked={checked}
        onCheckedChange={(value) => onChange(value === true)}
        className="mt-0.5"
      />
      <span className="flex flex-col gap-1">
        <span className="flex items-center gap-1.5 text-xs font-semibold">
          <WifiOff className="size-3.5" />
          {t("offlineOnlyLabel")}
        </span>
        <span className="text-muted-foreground text-[11px]">{t("offlineOnlyHint")}</span>
      </span>
    </label>
  );
}
```

- [ ] **Step 7: Wire the dialog**

In `product-form-dialog.tsx`:
- Delete the local `ProductFormValues` interface and the `EMPTY` constant.
- Add these imports:

```tsx
import {
  EMPTY_PRODUCT_FORM,
  productToFormValues,
  type ProductFormValues,
} from "../lib/product-form";
import { OfflineOnlyField } from "./offline-only-field";
```

- Re-export the type for the page's existing import: `export type { ProductFormValues } from "../lib/product-form";`
- Replace `useState<ProductFormValues>(EMPTY)` with `useState<ProductFormValues>(EMPTY_PRODUCT_FORM)`.
- Replace the reseed block's `setForm(product ? { … } : EMPTY)` with `setForm(product ? productToFormValues(product) : EMPTY_PRODUCT_FORM);`.
- In `submit()`, replace the hand-built object with `onSubmit(form);`. Trimming now happens in the lib.
- Directly after the branch `Select` block (still inside the `flex flex-col gap-3.5` div), add:

```tsx
          <OfflineOnlyField
            checked={form.offlineOnly}
            onChange={(offlineOnly) => set({ offlineOnly })}
          />
```

- [ ] **Step 8: Wire the page**

In `products-page.tsx`, import `toCreateProductInput` and `toUpdateProductInput` from `"../lib/product-form"`. In `handleSubmit`, replace the edit `input: { … }` with `input: toUpdateProductInput(data),` and the create object with `toCreateProductInput(data),`.

- [ ] **Step 9: Badge in the table**

In `product-row.tsx`, import `Badge` from `"@/shared/ui/badge"`. Replace the name line `<div className="truncate text-sm font-medium">{product.name}</div>` with:

```tsx
            <div className="flex items-center gap-2">
              <span className="truncate text-sm font-medium">{product.name}</span>
              {product.offlineOnly ? (
                <Badge variant="secondary">{t("offlineBadge")}</Badge>
              ) : null}
            </div>
```

- [ ] **Step 10: Verify**

Run: `npm test && npm run typecheck && npx eslint src/views/products src/entities/product`
Expected: all tests pass, no type errors, no lint errors.

- [ ] **Step 11: Commit**

```bash
git add src/views/products src/shared/config/i18n/messages
git commit -m "feat(products): let admins mark a product as offline-only

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Mark offline-rung receipts in the sales list

**Files:**
- Modify: `src/entities/sale/api/sale-dto.ts`, `src/entities/sale/model/types.ts`, `src/views/sales/ui/sale-row.tsx` (date cell ~L257)
- Modify: `src/shared/config/i18n/messages/uz/sales.json`, `ru/sales.json`
- Test: `src/entities/sale/api/sale-dto.test.ts` (new)

**Interfaces:**
- Consumes: `AdminSaleResponse.offlineSyncedAt` from Plan 1 Task 6
- Produces: `Sale.offlineSyncedAt: string | null`

- [ ] **Step 1: Write the failing test**

Create `src/entities/sale/api/sale-dto.test.ts`:

```ts
import { describe, expect, it } from "vitest";

import { type SaleDto, toSale } from "./sale-dto";

const dto = (overrides: Partial<SaleDto> = {}): SaleDto => ({
  id: "sale-1",
  subtotalUzs: 75000,
  cashUzs: 75000,
  cardUzs: 0,
  status: "paid",
  createdAt: "2026-09-23T10:00:00.000Z",
  items: [],
  ...overrides,
});

describe("toSale offline flag", () => {
  it("keeps when an offline receipt reached the server", () => {
    expect(toSale(dto({ offlineSyncedAt: "2026-09-23T12:00:00.000Z" })).offlineSyncedAt).toBe(
      "2026-09-23T12:00:00.000Z",
    );
  });

  it("reads a receipt rung up online, or from an older backend, as null", () => {
    expect(toSale(dto()).offlineSyncedAt).toBeNull();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npx vitest run src/entities/sale/api/sale-dto.test.ts`
Expected: FAIL (a type error on `offlineSyncedAt`, or `undefined` !== `null`).

- [ ] **Step 3: Implement**

`sale-dto.ts`: add `offlineSyncedAt?: string | null;` to `SaleDto` after `createdAt`, and to `toSale` add `offlineSyncedAt: dto.offlineSyncedAt ?? null,` after `createdAt`.
`model/types.ts`: add to `Sale` after `createdAt`:

```ts
  /** Set when the receipt was rung up on an offline cashier terminal and
   *  synced later — it was recorded at the prices printed on paper. */
  offlineSyncedAt: string | null;
```

i18n. `uz/sales.json`: `"offlineBadge": "Offline"` and `"offlineBadgeHint": "Internet yo'qligida kassada urilgan, keyin sinxronlangan"`. `ru/sales.json`: `"offlineBadge": "Офлайн"` and `"offlineBadgeHint": "Пробит на кассе без интернета и синхронизирован позже"`.

`sale-row.tsx`: import `Badge` from `"@/shared/ui/badge"`. Replace the body of the date cell (`{formatDateTime(sale.createdAt, locale)}`) with:

```tsx
        <div className="flex flex-col items-start gap-1">
          {formatDateTime(sale.createdAt, locale)}
          {sale.offlineSyncedAt ? (
            <Badge variant="outline" title={t("offlineBadgeHint")}>
              {t("offlineBadge")}
            </Badge>
          ) : null}
        </div>
```

- [ ] **Step 4: Verify**

Run: `npm test && npm run typecheck && npx eslint src/entities/sale src/views/sales`
Expected: all pass. If another file builds a `Sale` literal (fixtures, mocks), add `offlineSyncedAt: null` to it.

- [ ] **Step 5: Commit**

```bash
git add src/entities/sale src/views/sales src/shared/config/i18n/messages
git commit -m "feat(sales): badge receipts that were rung up offline

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Full verification

- [ ] **Step 1:** `npm test`. Expected: all pass; report the counts.
- [ ] **Step 2:** `npm run typecheck && npm run lint`. Expected: clean, or only warnings that already exist on `origin/stage`.
- [ ] **Step 3:** `npm run build`. Expected: success.
- [ ] **Step 4:** Visual check. `npm run dev` against the test API (the backend from Plan 1 must be on `development`). Open Products → "Yangi mahsulot": the checkbox and its hint show, and ticking it and saving shows the "Offline" badge in the row. Take a screenshot as proof.
- [ ] **Step 5:** Stop and report. No push or MR without the user's go-ahead.
