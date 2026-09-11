# Testing Suite (Unit + E2E) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Centavoo real automated coverage for the logic that's still untested (`categorize.ts`, `repo.ts`) and, for the first time, real browser UI coverage on both a desktop and a mobile viewport — replacing the one ad hoc `scripts/smoke.mjs` script with a proper Playwright Test suite.

**Architecture:** Two independent layers, both already foreshadowed by the project's existing tools. Unit tests stay in Vitest (`src/**/*.test.ts`, Node environment) — `repo.ts`'s tests get a real Dexie instance backed by `fake-indexeddb` instead of a browser. UI tests move from the raw `playwright` library (already installed, used only by the ad hoc `smoke.mjs`) to `@playwright/test`, the real test runner built on top of it, configured with two projects — `desktop` and `mobile` (Pixel 7 viewport + touch) — so every spec file runs both ways for free.

**Tech Stack:** Vitest (existing), `fake-indexeddb` (new), `@playwright/test` (new, replaces raw `playwright` usage in tests), React 19 / Mantine 9 / Dexie 4 (existing, untouched).

**Spec:** `docs/superpowers/specs/2026-09-11-testing-suite-design.md`

## Global Constraints

- Unit tests: Vitest, Node environment, `src/**/*.test.ts` (per `vitest.config.ts` — unchanged).
- `fake-indexeddb` must be imported via `import 'fake-indexeddb/auto'` as the **first** import in `src/db/repo.test.ts`, before `../db/db` is imported — it polyfills `globalThis.indexedDB` as a side effect, and Dexie needs that polyfill in place before it opens the database.
- `@playwright/test` must be installed at the exact same version as the already-installed `playwright` package (`1.63.0`) — Playwright requires both packages to match.
- Mobile E2E coverage uses Chromium's `Pixel 7` device preset (touch + narrow viewport), not WebKit/iPhone — matches how this app is actually used (Chrome on Android) and avoids downloading an extra browser engine.
- Every E2E spec file runs on **both** Playwright projects (`desktop` and `mobile`) — there is no separate "mobile-only" test file; the same test runs twice via the config's `projects` array.
- `npm test` (unit tests) and `npm run test:e2e` (Playwright) stay separate commands — E2E tests open a real browser and are much slower.

---

### Task 1: Testability + accessibility hooks on `ToggleLegend` and the city pill's remove button

The chart legend and the city-pill remove button need stable, non-visual hooks so the later E2E tasks can target them reliably. The city pill's remove button currently has `aria-hidden="true"` baked in by Mantine's `Pill` component (see `node_modules/@mantine/core/esm/components/Pill/Pill.mjs`), which is also a real accessibility gap — keyboard and screen-reader users can't currently remove a city tag at all. This task fixes both problems at once.

**Files:**
- Modify: `src/components/trip/primitives.tsx` (`ToggleLegend`)
- Modify: `src/components/trip/CityEditor.tsx` (city pill)
- Modify: `src/i18n/locales/pt.ts`, `src/i18n/locales/en.ts` (one new key)

**Interfaces:**
- Produces: `ToggleLegend`'s rendered button gets `aria-label="toggle-<series.name>"` and, when that series is hidden, a `data-hidden="true"` attribute (absent otherwise). Later E2E tasks (Task 5) rely on exactly these two attributes.
- Produces: each city pill's remove control gets an accessible name of `"<t('city.removeCity')> <city name>"` (e.g. `"Remover Madrid"` in PT, `"Remove Madrid"` in EN) and is no longer `aria-hidden`. Task 6 relies on this exact label format.

- [ ] **Step 1: Add the i18n key**

In `src/i18n/locales/pt.ts`, add this line right after `'city.addCity': 'Adicionar cidade',`:

```ts
  'city.removeCity': 'Remover',
```

In `src/i18n/locales/en.ts`, add this line right after `'city.addCity': 'Add city',`:

```ts
  'city.removeCity': 'Remove',
```

- [ ] **Step 2: Update `ToggleLegend` in `src/components/trip/primitives.tsx`**

Find:

```tsx
          <UnstyledButton
            key={s.name}
            onClick={() => onToggle(s.name)}
            style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '4px 2px' }}
          >
```

Replace with:

```tsx
          <UnstyledButton
            key={s.name}
            aria-label={`toggle-${s.name}`}
            data-hidden={isHidden || undefined}
            onClick={() => onToggle(s.name)}
            style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '4px 2px' }}
          >
```

- [ ] **Step 3: Update the city pill in `src/components/trip/CityEditor.tsx`**

Find:

```tsx
            <Pill key={city} size="md" withRemoveButton onRemove={() => removeCity(city)}>
```

Replace with:

```tsx
            <Pill
              key={city}
              size="md"
              withRemoveButton
              onRemove={() => removeCity(city)}
              removeButtonProps={{ 'aria-label': `${t('city.removeCity')} ${city}`, 'aria-hidden': false }}
            >
```

- [ ] **Step 4: Verify nothing broke**

Run:
```bash
npx eslint src/components/trip/primitives.tsx src/components/trip/CityEditor.tsx src/i18n/locales/pt.ts src/i18n/locales/en.ts
npx tsc -b --noEmit
npx vitest run
```
Expected: no lint/type errors, all 74 existing tests still pass (this task changes no logic, only markup attributes).

- [ ] **Step 5: Manually confirm in the browser**

With the dev server running (`npm run dev`), open a trip, go to the "Tempo" tab, and confirm tapping a legend item still visually dims it (unchanged behavior — only the underlying attributes are new). Go to "Cidades" and confirm the "×" on a city pill still removes it.

- [ ] **Step 6: Commit**

```bash
git add src/components/trip/primitives.tsx src/components/trip/CityEditor.tsx src/i18n/locales/pt.ts src/i18n/locales/en.ts
git commit -m "Add test/accessibility hooks to ToggleLegend and city pill remove button"
```

---

### Task 2: Unit tests for `suggestCategory` (`src/lib/categorize.ts`)

**Files:**
- Create: `src/lib/categorize.test.ts`
- Test: same file (Vitest picks up `src/**/*.test.ts` automatically per `vitest.config.ts`)

**Interfaces:**
- Consumes: `suggestCategory(description: string, rules: CategoryRule[]): string | null` from `src/lib/categorize.ts` (unchanged, already implemented). `CategoryRule` from `src/db/schema.ts`: `{ id?: number; keyword: string; categoryId: string; priority: number }`.

- [ ] **Step 1: Write the test file**

```ts
import { describe, it, expect } from 'vitest';
import { suggestCategory } from './categorize';
import type { CategoryRule } from '../db/schema';

function rule(p: Partial<CategoryRule> & { keyword: string; categoryId: string }): CategoryRule {
  return { priority: 0, ...p };
}

describe('suggestCategory', () => {
  it('returns null when no rule matches', () => {
    expect(suggestCategory('Uber para o hotel', [])).toBeNull();
  });

  it('matches a keyword as a case-insensitive substring', () => {
    const rules = [rule({ keyword: 'uber', categoryId: 'cat-transport' })];
    expect(suggestCategory('UBER *TRIP', rules)).toBe('cat-transport');
  });

  it('picks the highest-priority match when two rules match', () => {
    const rules = [
      rule({ keyword: 'uber', categoryId: 'cat-transport', priority: 1 }),
      rule({ keyword: 'eats', categoryId: 'cat-food', priority: 5 }),
    ];
    expect(suggestCategory('UBER EATS *ORDER', rules)).toBe('cat-food');
  });

  it('breaks a priority tie with the longer (more specific) keyword', () => {
    const rules = [
      rule({ keyword: 'uber', categoryId: 'cat-transport', priority: 1 }),
      rule({ keyword: 'uber eats', categoryId: 'cat-food', priority: 1 }),
    ];
    expect(suggestCategory('UBER EATS *ORDER', rules)).toBe('cat-food');
  });

  it('matches a keyword appearing anywhere in the description, not just at word boundaries', () => {
    const rules = [rule({ keyword: 'ber', categoryId: 'cat-transport' })];
    expect(suggestCategory('Uber Trip', rules)).toBe('cat-transport');
  });

  it('ignores rules that do not match at all, even with higher priority', () => {
    const rules = [
      rule({ keyword: 'padaria', categoryId: 'cat-food', priority: 100 }),
      rule({ keyword: 'uber', categoryId: 'cat-transport', priority: 1 }),
    ];
    expect(suggestCategory('UBER *TRIP', rules)).toBe('cat-transport');
  });
});
```

- [ ] **Step 2: Run it**

```bash
npx vitest run src/lib/categorize.test.ts
```
Expected: `PASS`, 6 tests — `suggestCategory` already exists and is correct, so this step verifies the tests describe its real behavior rather than driving new code.

- [ ] **Step 3: Commit**

```bash
git add src/lib/categorize.test.ts
git commit -m "Add unit tests for suggestCategory"
```

---

### Task 3: `fake-indexeddb` + unit tests for `src/db/repo.ts`

**Files:**
- Modify: `package.json` (new devDependency)
- Create: `src/db/repo.test.ts`

**Interfaces:**
- Consumes: everything exported from `src/db/repo.ts` (unchanged) — `DEFAULT_CATEGORIES`, `createTrip`, `updateTrip`, `deleteTrip`, `setTripCityRange`, `addTransaction`, `updateTransaction`, `deleteTransaction`, `deleteTransactions`, `bulkAddTransactions`, `addCategory`, `updateCategory`, `deleteCategory`. And `db` from `src/db/db.ts` (the Dexie singleton).

- [ ] **Step 1: Install `fake-indexeddb`**

```bash
npm install --save-dev fake-indexeddb
```

- [ ] **Step 2: Write the test file**

```ts
import 'fake-indexeddb/auto';
import { describe, it, expect, beforeEach } from 'vitest';
import { db } from './db';
import {
  DEFAULT_CATEGORIES,
  createTrip,
  deleteTrip,
  setTripCityRange,
  addTransaction,
  bulkAddTransactions,
  deleteTransaction,
  deleteTransactions,
  addCategory,
  deleteCategory,
} from './repo';

beforeEach(async () => {
  await db.transactions.clear();
  await db.trips.clear();
  await db.categories.clear();
  await db.rules.clear();
});

describe('createTrip', () => {
  it('creates the trip and seeds it with the default categories', async () => {
    const id = await createTrip({ name: 'Japan' });
    const trip = await db.trips.get(id);
    expect(trip).toMatchObject({ name: 'Japan', currency: 'BRL', cities: {} });

    const cats = await db.categories.where('tripId').equals(id).toArray();
    expect(cats).toHaveLength(DEFAULT_CATEGORIES.length);
    // Sort by sortOrder before comparing — Dexie/IndexedDB does not guarantee
    // retrieval order for a non-unique index query (ties break by primary
    // key, which is a random UUID here, not insertion order).
    const byOrder = [...cats].sort((a, b) => a.sortOrder - b.sortOrder);
    expect(byOrder.map((c) => c.name)).toEqual(DEFAULT_CATEGORIES.map((c) => c.name));
  });

  it('scopes seeded categories to this trip only', async () => {
    const id1 = await createTrip({ name: 'Trip 1' });
    const id2 = await createTrip({ name: 'Trip 2' });
    const cats1 = await db.categories.where('tripId').equals(id1).toArray();
    const cats2 = await db.categories.where('tripId').equals(id2).toArray();
    expect(cats1.every((c) => c.tripId === id1)).toBe(true);
    expect(cats2.every((c) => c.tripId === id2)).toBe(true);
  });
});

describe('deleteTrip', () => {
  it('cascades: removes the trip, its categories, its transactions, and rules pointing at them', async () => {
    const id = await createTrip({ name: 'Japan' });
    const cats = await db.categories.where('tripId').equals(id).toArray();
    const catId = cats[0].id;
    await addTransaction({
      tripId: id,
      period: 'DURING',
      date: '2026-01-01',
      description: 'Sushi',
      amount: 50,
      categoryId: catId,
      kind: 'EXPENSE',
      isIof: false,
      splitCount: 1,
      city: null,
    });
    await db.rules.add({ keyword: 'sushi', categoryId: catId, priority: 1 });

    await deleteTrip(id);

    expect(await db.trips.get(id)).toBeUndefined();
    expect(await db.categories.where('tripId').equals(id).count()).toBe(0);
    expect(await db.transactions.where('tripId').equals(id).count()).toBe(0);
    expect(await db.rules.where('categoryId').equals(catId).count()).toBe(0);
  });

  it('leaves a different trip untouched', async () => {
    const keepId = await createTrip({ name: 'Keep me' });
    const deleteId = await createTrip({ name: 'Delete me' });
    await deleteTrip(deleteId);
    expect(await db.trips.get(keepId)).toBeDefined();
    expect(await db.categories.where('tripId').equals(keepId).count()).toBe(DEFAULT_CATEGORIES.length);
  });
});

describe('setTripCityRange', () => {
  it('sets the city for every day in the range at once', async () => {
    const id = await createTrip({ name: 'Japan' });
    await setTripCityRange(id, ['2026-01-01', '2026-01-02', '2026-01-03'], 'Tokyo');
    const trip = await db.trips.get(id);
    expect(trip?.cities).toEqual({
      '2026-01-01': 'Tokyo',
      '2026-01-02': 'Tokyo',
      '2026-01-03': 'Tokyo',
    });
  });

  it('clears days when the city is an empty string', async () => {
    const id = await createTrip({ name: 'Japan' });
    await setTripCityRange(id, ['2026-01-01', '2026-01-02'], 'Tokyo');
    await setTripCityRange(id, ['2026-01-01'], '');
    const trip = await db.trips.get(id);
    expect(trip?.cities).toEqual({ '2026-01-02': 'Tokyo' });
  });

  it('does nothing when the trip does not exist', async () => {
    await expect(setTripCityRange('missing', ['2026-01-01'], 'Tokyo')).resolves.toBeUndefined();
  });
});

describe('transactions', () => {
  it('addTransaction assigns an id and createdAt', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const id = await addTransaction({
      tripId,
      period: 'DURING',
      date: '2026-01-01',
      description: 'Ramen',
      amount: 20,
      categoryId: null,
      kind: 'EXPENSE',
      isIof: false,
      splitCount: 1,
      city: null,
    });
    const tx = await db.transactions.get(id);
    expect(tx).toMatchObject({ id, description: 'Ramen' });
    expect(tx?.createdAt).toBeTruthy();
  });

  it('bulkAddTransactions inserts every row and returns ids in the same order', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const ids = await bulkAddTransactions([
      {
        tripId, period: 'DURING', date: '2026-01-01', description: 'A',
        amount: 10, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
      },
      {
        tripId, period: 'DURING', date: '2026-01-02', description: 'B',
        amount: 20, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
      },
    ]);
    expect(ids).toHaveLength(2);
    const stored = await db.transactions.bulkGet(ids);
    expect(stored.map((t) => t?.description)).toEqual(['A', 'B']);
  });

  it('deleteTransaction removes a single row', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const id = await addTransaction({
      tripId, period: 'DURING', date: '2026-01-01', description: 'A',
      amount: 10, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
    });
    await deleteTransaction(id);
    expect(await db.transactions.get(id)).toBeUndefined();
  });

  it('deleteTransactions removes every listed row', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const ids = await bulkAddTransactions([
      {
        tripId, period: 'DURING', date: '2026-01-01', description: 'A',
        amount: 10, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
      },
      {
        tripId, period: 'DURING', date: '2026-01-02', description: 'B',
        amount: 20, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
      },
    ]);
    await deleteTransactions(ids);
    expect(await db.transactions.count()).toBe(0);
  });
});

describe('addCategory', () => {
  it('assigns the next sortOrder scoped to the trip, not globally', async () => {
    const tripA = await createTrip({ name: 'A' });
    const tripB = await createTrip({ name: 'B' });
    const idA = await addCategory({ tripId: tripA, name: 'Extra A', color: '#fff' });
    const idB = await addCategory({ tripId: tripB, name: 'Extra B', color: '#fff' });
    const catA = await db.categories.get(idA);
    const catB = await db.categories.get(idB);
    expect(catA?.sortOrder).toBe(DEFAULT_CATEGORIES.length);
    expect(catB?.sortOrder).toBe(DEFAULT_CATEGORIES.length);
  });
});

describe('deleteCategory', () => {
  it('clears the reference on any transaction that used it, without deleting the transaction', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const cats = await db.categories.where('tripId').equals(tripId).toArray();
    const catId = cats[0].id;
    const txId = await addTransaction({
      tripId, period: 'DURING', date: '2026-01-01', description: 'A',
      amount: 10, categoryId: catId, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
    });

    await deleteCategory(catId);

    expect(await db.categories.get(catId)).toBeUndefined();
    const tx = await db.transactions.get(txId);
    expect(tx).toBeDefined();
    expect(tx?.categoryId).toBeNull();
  });

  it('removes any keyword rule pointing at the deleted category', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const cats = await db.categories.where('tripId').equals(tripId).toArray();
    const catId = cats[0].id;
    await db.rules.add({ keyword: 'ramen', categoryId: catId, priority: 1 });

    await deleteCategory(catId);

    expect(await db.rules.where('categoryId').equals(catId).count()).toBe(0);
  });
});
```

- [ ] **Step 3: Run it**

```bash
npx vitest run src/db/repo.test.ts
```
Expected: `PASS`, 12 tests. If it fails with something like `ReferenceError: indexedDB is not defined`, double check the `import 'fake-indexeddb/auto'` line is the very first line of the file (must run before `./db` is imported, since `db.ts` opens the Dexie database at module load time).

- [ ] **Step 4: Run the full unit suite**

```bash
npm test
```
Expected: all tests pass (74 existing + 6 from Task 2 + 12 from this task = 92).

- [ ] **Step 5: Commit**

```bash
git add package.json package-lock.json src/db/repo.test.ts
git commit -m "Add fake-indexeddb and unit tests for db/repo.ts"
```

---

### Task 4: Install and configure Playwright Test

**Files:**
- Modify: `package.json` (new devDependency, new `test:e2e` script)
- Create: `playwright.config.ts`
- Modify: `.gitignore` (Playwright's output directories)

**Interfaces:**
- Produces: `playwright.config.ts` exporting a config with `testDir: './e2e'`, a `webServer` that starts `npm run dev` and waits for `http://localhost:5173`, and two `projects`: `desktop` and `mobile`. Every task from here on writes files under `e2e/` that this config picks up automatically.

- [ ] **Step 1: Install `@playwright/test` at the version matching the installed `playwright` package**

```bash
npm install --save-dev @playwright/test@1.63.0
```

- [ ] **Step 2: Install the Chromium browser binary**

```bash
npx playwright install chromium
```
This is a one-time download (the `playwright` npm package alone does not include the browser binary).

- [ ] **Step 3: Create `playwright.config.ts`**

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  // Capped from Playwright's default (~half the logical CPUs) — on a
  // memory-constrained dev machine, higher parallelism caused a real,
  // reproducible timeout in the longest test (transactions.spec.ts's
  // edit-transaction round trip) from resource contention, not a test bug.
  workers: 4,
  reporter: 'list',
  use: {
    baseURL: 'http://localhost:5173',
    trace: 'retain-on-failure',
  },
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
  },
  projects: [
    {
      name: 'desktop',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'mobile',
      use: { ...devices['Pixel 7'] },
    },
  ],
});
```

- [ ] **Step 4: Add the `test:e2e` script to `package.json`**

In the `"scripts"` block, add a line after `"test:watch": "vitest"`:

```json
    "test:e2e": "playwright test"
```

- [ ] **Step 5: Ignore Playwright's output directories**

Append to `.gitignore`:

```
# Playwright
test-results/
playwright-report/
blob-report/
```

- [ ] **Step 6: Write and run one trivial spec to prove the setup works**

Create `e2e/setup-check.spec.ts` temporarily:

```ts
import { test, expect } from '@playwright/test';

test('home page loads', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByText('CENTAVOO')).toBeVisible();
});
```

Run:
```bash
npm run test:e2e
```
Expected: `2 passed` (once for each project, `desktop` and `mobile`) — this proves the dev server auto-start, both device projects, and the base config all work before any real spec is written.

Delete `e2e/setup-check.spec.ts` — it was only there to prove the harness works; Task 5 replaces it with the real dashboard spec.

- [ ] **Step 7: Commit**

```bash
git add package.json package-lock.json playwright.config.ts .gitignore
git commit -m "Add Playwright Test (desktop + mobile projects)"
```

---

### Task 5: `e2e/support/overflow.ts` + `e2e/trip-dashboard.spec.ts`

**Files:**
- Create: `e2e/support/overflow.ts`
- Create: `e2e/trip-dashboard.spec.ts`

**Interfaces:**
- Produces: `expectNoHorizontalOverflow(page: Page): Promise<void>` — asserts the page never scrolls sideways. Every later spec file (Tasks 6-9) imports this from `./support/overflow`.

- [ ] **Step 1: Write the shared overflow helper**

```ts
import { expect, type Page } from '@playwright/test';

// Fails the test if the page is wider than the viewport — the exact bug
// class found and fixed in this app (tables/tabs pushing the whole page
// sideways on narrow screens). Cheap to call after every navigation.
export async function expectNoHorizontalOverflow(page: Page) {
  const overflowing = await page.evaluate(
    () => document.documentElement.scrollWidth > window.innerWidth + 1,
  );
  expect(overflowing, 'page should not scroll horizontally').toBe(false);
}
```

- [ ] **Step 2: Write the dashboard spec**

```ts
import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.getByText('Europa 2026').first().click();
  await page.getByRole('heading', { name: 'Europa 2026' }).waitFor();
});

test('shows the trip KPIs', async ({ page }) => {
  await expect(page.getByText('14.874', { exact: false })).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('resumo tab shows the split savings card', async ({ page }) => {
  await expect(page.getByText('Você economizou')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('maiores gastos tab shows the before/during sections', async ({ page }) => {
  await page.getByRole('tab', { name: 'Maiores Gastos' }).click();
  await expect(page.getByText('Maiores gastos · antes')).toBeVisible();
  await expect(page.getByText('Maiores gastos · durante')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('tempo tab shows the weekday chart', async ({ page }) => {
  await page.getByRole('tab', { name: 'Tempo' }).click();
  await expect(page.getByText('Por dia da semana')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('tempo tab: tapping a "Por dia" legend item toggles it off and back on', async ({ page }) => {
  await page.getByRole('tab', { name: 'Tempo' }).click();
  const item = page.getByRole('button', { name: 'toggle-Alimentação' });
  await item.waitFor();
  await expect(item).not.toHaveAttribute('data-hidden');
  await item.click();
  await expect(item).toHaveAttribute('data-hidden', 'true');
  await item.click();
  await expect(item).not.toHaveAttribute('data-hidden');
});

test('cidades tab is reachable and shows the city table', async ({ page }) => {
  await page.getByRole('tab', { name: 'Cidades' }).click();
  await expect(page.getByText('Resumo por cidade')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('categorias tab shows the category table and the before/during legend toggle', async ({ page }) => {
  await page.getByRole('tab', { name: 'Categorias' }).click();
  await expect(page.getByText('Ticket médio')).toBeVisible();
  const item = page.getByRole('button', { name: 'toggle-during' });
  await item.waitFor();
  await item.click();
  await expect(item).toHaveAttribute('data-hidden', 'true');
  await expectNoHorizontalOverflow(page);
});

test('transações tab is reachable', async ({ page }) => {
  await page.getByRole('tab', { name: 'Transações' }).click();
  await expect(page.getByRole('columnheader', { name: 'Descrição' })).toBeVisible();
  await expectNoHorizontalOverflow(page);
});
```

- [ ] **Step 3: Run it**

```bash
npx playwright test e2e/trip-dashboard.spec.ts
```
Expected: `16 passed` (8 tests × 2 projects). If the "toggle-Alimentação" test fails to find the button, confirm Task 1 was applied (the `aria-label` on `ToggleLegend`'s button) and that "Alimentação" has spending recorded in the seeded Europa trip's `dayData` (it does, per the category table shown in this session's earlier screenshots — 49 transactions).

- [ ] **Step 4: Commit**

```bash
git add e2e/support/overflow.ts e2e/trip-dashboard.spec.ts
git commit -m "Add trip dashboard E2E spec (desktop + mobile)"
```

---

### Task 6: `e2e/cities.spec.ts`

Grounded in the Europa seed's actual `cities` map (`public/europa.json`, trip `2026-05-17`→`2026-06-03`, 18 days): grouped into 7 contiguous city blocks — `SP` (17th, 1 day), `Barcelona` (18th–19th, 2 days), `Atenas` (20th–22nd, 3 days), `Santorini` (23rd–27th, 5 days), `Amsterdam` (28th–30th, 3 days), `Barcelona` (31st–2nd, 3 days), `SP` (3rd, 1 day) — 5 distinct cities (`Amsterdam`, `Atenas`, `Barcelona`, `Santorini`, `SP`), 0 days unassigned.

**Files:**
- Create: `e2e/cities.spec.ts`

**Interfaces:**
- Consumes: `expectNoHorizontalOverflow` from `./support/overflow` (Task 5). The `aria-label="toggle-…"`/`data-hidden` and `"Remover <city>"` hooks from Task 1.

- [ ] **Step 1: Write the spec**

```ts
import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.getByText('Europa 2026').first().click();
  await page.getByRole('heading', { name: 'Europa 2026' }).waitFor();
  await page.getByRole('tab', { name: 'Cidades' }).click();
});

test('lists the seeded cities and every day covered by a block', async ({ page }) => {
  for (const city of ['Amsterdam', 'Atenas', 'Barcelona', 'Santorini', 'SP']) {
    await expect(page.getByText(city, { exact: true }).first()).toBeVisible();
  }
  // 7 contiguous date-range blocks cover all 18 trip days — none left over.
  await expect(page.getByText(/dia\(s\) sem cidade/)).toHaveCount(0);
  await expectNoHorizontalOverflow(page);
});

test('adds a city, then removes it with no confirmation since it has no days assigned', async ({ page }) => {
  await page.getByRole('button', { name: 'Adicionar cidade' }).click();
  await page.getByPlaceholder('cidade').last().fill('Madrid');
  await page.getByLabel('confirm-add-city').click();
  await expect(page.getByText('Madrid', { exact: true })).toBeVisible();

  page.once('dialog', (d) => {
    throw new Error(`unexpected confirm dialog: ${d.message()}`);
  });
  await page.getByLabel('Remover Madrid').click();
  await expect(page.getByText('Madrid', { exact: true })).toHaveCount(0);
});

test('removing a city that is still assigned to days asks for confirmation, then clears them', async ({ page }) => {
  page.once('dialog', (d) => d.accept());
  await page.getByLabel('Remover SP').click();
  await expect(page.getByText('SP', { exact: true })).toHaveCount(0);
  // SP covered 2 separate single days (17th and 3rd) — both become unassigned.
  await expect(page.getByText(/2 dia\(s\) sem cidade/)).toBeVisible();
});

test('editing a block switches the form into edit mode', async ({ page }) => {
  await page.getByLabel('edit-city-block').first().click();
  await expect(page.getByRole('button', { name: 'Salvar' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Cancelar' })).toBeVisible();
});

test('removing a block clears just those days', async ({ page }) => {
  page.once('dialog', (d) => d.accept());
  await page.getByLabel('delete-city-block').first().click();
  // The first block in date order is SP's single day (May 17th).
  await expect(page.getByText(/1 dia\(s\) sem cidade/)).toBeVisible();
  await expectNoHorizontalOverflow(page);
});
```

- [ ] **Step 2: Run it**

```bash
npx playwright test e2e/cities.spec.ts
```
Expected: `10 passed` (5 tests × 2 projects).

- [ ] **Step 3: Commit**

```bash
git add e2e/cities.spec.ts
git commit -m "Add cities (CityEditor) E2E spec"
```

---

### Task 7: `e2e/transactions.spec.ts`

**Files:**
- Create: `e2e/transactions.spec.ts`

**Interfaces:**
- Consumes: `expectNoHorizontalOverflow` from `./support/overflow` (Task 5).

- [ ] **Step 1: Write the spec**

```ts
import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.getByText('Europa 2026').first().click();
  await page.getByRole('heading', { name: 'Europa 2026' }).waitFor();
  await page.getByRole('tab', { name: 'Transações' }).click();
});

test('adds, then deletes a single transaction', async ({ page }) => {
  await page.getByRole('button', { name: 'Nova transação' }).click();
  await page.getByLabel('Descrição').fill('Playwright Café');
  await page.getByLabel('Valor').fill('42');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Playwright Café')).toBeVisible();

  page.once('dialog', (d) => d.accept());
  await page.locator('tr', { hasText: 'Playwright Café' }).getByLabel('delete').click();
  await expect(page.getByText('Playwright Café')).toHaveCount(0);
});

test('edits an existing transaction description', async ({ page }) => {
  await page.getByRole('button', { name: 'Nova transação' }).click();
  await page.getByLabel('Descrição').fill('Playwright Original');
  await page.getByLabel('Valor').fill('10');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Playwright Original')).toBeVisible();

  await page.locator('tr', { hasText: 'Playwright Original' }).getByLabel('edit').click();
  await page.getByLabel('Descrição').fill('Playwright Edited');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Playwright Edited')).toBeVisible();
  await expect(page.getByText('Playwright Original')).toHaveCount(0);
});

test('selects two rows and bulk-deletes them', async ({ page }) => {
  const before = await page.getByLabel('select-row').count();
  await page.getByLabel('select-row').nth(0).check();
  await page.getByLabel('select-row').nth(1).check();
  page.once('dialog', (d) => d.accept());
  await page.getByRole('button', { name: 'Excluir selecionadas' }).click();
  await expect(page.getByLabel('select-row')).toHaveCount(before - 2);
});

test('filters the list by category', async ({ page }) => {
  await page.getByPlaceholder('todas as categorias').click();
  await page.getByRole('option', { name: 'Alimentação' }).click();
  await expect(page.getByText('Limpar filtros')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});
```

- [ ] **Step 2: Run it**

```bash
npx playwright test e2e/transactions.spec.ts
```
Expected: `8 passed` (4 tests × 2 projects).

- [ ] **Step 3: Commit**

```bash
git add e2e/transactions.spec.ts
git commit -m "Add transactions E2E spec"
```

---

### Task 8: `e2e/categories.spec.ts`

**Files:**
- Create: `e2e/categories.spec.ts`

**Interfaces:**
- Consumes: `expectNoHorizontalOverflow` from `./support/overflow` (Task 5).

- [ ] **Step 1: Write the spec**

```ts
import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.getByText('Europa 2026').first().click();
  await page.getByRole('heading', { name: 'Europa 2026' }).waitFor();
  await page.getByRole('link', { name: 'Categorias' }).click();
  await page.waitForURL('**/categories');
});

test('lists the default categories', async ({ page }) => {
  await expect(page.getByText('Hospedagem')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test('creates a category with a name, color and icon', async ({ page }) => {
  await page.getByRole('button', { name: 'Nova categoria' }).click();
  await page.getByLabel('Nome').fill('Playwright Cat');
  await page.getByText('🗺️').click();
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Playwright Cat')).toBeVisible();
});

test('edits an existing category name', async ({ page }) => {
  await page.locator('div', { hasText: 'Hospedagem' }).getByLabel('edit').first().click();
  await page.getByLabel('Nome').fill('Hospedagem 2');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Hospedagem 2')).toBeVisible();
});

test('deletes a category after confirming', async ({ page }) => {
  await page.getByRole('button', { name: 'Nova categoria' }).click();
  await page.getByLabel('Nome').fill('Delete Me');
  await page.getByRole('button', { name: 'Salvar' }).click();
  await expect(page.getByText('Delete Me')).toBeVisible();

  page.once('dialog', (d) => d.accept());
  await page.locator('div', { hasText: 'Delete Me' }).getByLabel('delete').first().click();
  await expect(page.getByText('Delete Me')).toHaveCount(0);
});
```

- [ ] **Step 2: Run it**

```bash
npx playwright test e2e/categories.spec.ts
```
Expected: `8 passed` (4 tests × 2 projects).

- [ ] **Step 3: Commit**

```bash
git add e2e/categories.spec.ts
git commit -m "Add categories page E2E spec"
```

---

### Task 9: `e2e/backup.spec.ts` and `e2e/trip-lifecycle.spec.ts`

**Files:**
- Create: `e2e/backup.spec.ts`
- Create: `e2e/trip-lifecycle.spec.ts`

**Interfaces:**
- Consumes: `expectNoHorizontalOverflow` from `./support/overflow` (Task 5), used in `trip-lifecycle.spec.ts`.

- [ ] **Step 1: Write the backup spec**

```ts
import { test, expect } from '@playwright/test';

test('exports a backup file, then imports it back in', async ({ page }) => {
  await page.goto('/');
  await page.getByText('Europa 2026').first().click();
  await page.getByRole('heading', { name: 'Europa 2026' }).waitFor();

  await page.getByLabel('menu').click();
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.getByRole('menuitem', { name: 'Exportar dados' }).click(),
  ]);
  expect(download.suggestedFilename()).toMatch(/^centavoo-backup-.*\.json$/);
  const filePath = await download.path();
  expect(filePath).toBeTruthy();

  await page.getByLabel('menu').click();
  await page.locator('input[type="file"]').setInputFiles(filePath!);
  await expect(page.getByText('Backup importado com sucesso.')).toBeVisible();
});
```

- [ ] **Step 2: Write the trip-lifecycle spec**

```ts
import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';

test('creates a trip, opens it, then deletes it end-to-end', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Nova viagem' }).click();
  await page.getByLabel('Nome').fill('Playwright Trip');
  await page.getByRole('button', { name: 'Criar' }).click();

  await page.getByText('Playwright Trip').first().click();
  await page.getByRole('heading', { name: 'Playwright Trip' }).waitFor();
  await expectNoHorizontalOverflow(page);

  await page.getByLabel('edit-trip').click();
  page.once('dialog', (d) => d.accept());
  await page.getByRole('button', { name: 'Excluir viagem' }).click();

  await page.waitForURL('/');
  await expect(page.getByText('Playwright Trip')).toHaveCount(0);
  await expectNoHorizontalOverflow(page);
});
```

- [ ] **Step 3: Run both**

```bash
npx playwright test e2e/backup.spec.ts e2e/trip-lifecycle.spec.ts
```
Expected: `4 passed` (2 tests × 2 projects).

- [ ] **Step 4: Commit**

```bash
git add e2e/backup.spec.ts e2e/trip-lifecycle.spec.ts
git commit -m "Add backup export/import and trip-lifecycle E2E specs"
```

---

### Task 10: `e2e/i18n.spec.ts`

**Files:**
- Create: `e2e/i18n.spec.ts`

**Interfaces:**
- Consumes: `expectNoHorizontalOverflow` from `./support/overflow` (Task 5).

- [ ] **Step 1: Write the spec**

```ts
import { test, expect } from '@playwright/test';
import { expectNoHorizontalOverflow } from './support/overflow';

test('the PT/EN toggle switches the visible language', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByText('Minhas viagens')).toBeVisible();
  await page.getByText('EN', { exact: true }).click();
  await expect(page.getByText('My trips')).toBeVisible();
  await expectNoHorizontalOverflow(page);
});
```

- [ ] **Step 2: Run it**

```bash
npx playwright test e2e/i18n.spec.ts
```
Expected: `2 passed`.

- [ ] **Step 3: Run the entire E2E suite together**

```bash
npm run test:e2e
```
Expected: every spec file from Tasks 5-10 passes on both projects.

- [ ] **Step 4: Commit**

```bash
git add e2e/i18n.spec.ts
git commit -m "Add language toggle E2E spec"
```

---

### Task 11: Retire `scripts/smoke.mjs`

**Files:**
- Delete: `scripts/smoke.mjs`
- Modify: `README.md` (remove the now-inaccurate "Smoke test (headless)" section only — the rest of the README is out of scope for this plan, it's a separate follow-up task already agreed with the user)

**Interfaces:** none — this task only removes dead material now fully superseded by Tasks 5-10.

- [ ] **Step 1: Delete the script**

```bash
git rm scripts/smoke.mjs
```

- [ ] **Step 2: Remove its section from the README**

In `README.md`, delete this whole block (including the heading):

```md
## Smoke test (headless)

```bash
npm run dev &                 # server on :5173
node scripts/smoke.mjs        # loads the app, checks KPIs, saves screenshots to /tmp
```

```

(A follow-up task will rewrite the rest of the README, including adding proper `npm test` / `npm run test:e2e` instructions — this step only removes the now-false instructions so the README isn't left inconsistent in the meantime.)

- [ ] **Step 3: Verify the full suite still passes without the old script**

```bash
npm test
npm run test:e2e
```
Expected: unit tests pass (92), E2E suite passes on both projects.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Retire scripts/smoke.mjs — superseded by the Playwright Test suite"
```

---

## Final check (after all tasks)

- [ ] `npm test` — all unit tests pass.
- [ ] `npm run test:e2e` — all E2E specs pass on both `desktop` and `mobile` projects.
- [ ] `npx eslint .` and `npx tsc -b --noEmit` — clean.
- [ ] `git log --oneline -15` — one commit per task, nothing left uncommitted (`git status` clean aside from anything the user already had in progress before this plan started).
