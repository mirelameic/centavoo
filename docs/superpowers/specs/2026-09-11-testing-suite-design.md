# Testing suite: unit + E2E (desktop & mobile)

## Goal

Centavoo currently has 74 passing unit tests, all covering pure logic in
`src/db/stats.ts`, `src/lib/parseTable.ts` and `src/lib/format.ts`. Nothing
tests the UI, and nothing runs on a mobile viewport — which is exactly the
class of bug found and fixed manually this session (horizontal overflow on
narrow screens, a chart legend that only responded to mouse hover). The goal
is to close both gaps: add unit tests for the logic that's still untested,
and stand up a real browser-based UI test suite that runs every scenario on
both a desktop and a mobile viewport.

## Non-goals

- No visual/screenshot regression testing (pixel-diffing) — out of scope,
  can be added later if it becomes valuable.
- No CI pipeline setup (e.g. GitHub Actions) — this spec only covers the
  test suite itself and how to run it locally.
- No component-level (jsdom/@testing-library/react) tests — real-browser
  E2E was the approach chosen (see the earlier chat decision): it catches
  real layout/CSS/touch bugs that a jsdom render never would.

## Part 1 — Unit tests (Vitest, unchanged setup)

Two new test files, same pattern as the existing ones (`vitest.config.ts`
already runs `src/**/*.test.ts` in a plain Node environment — no changes
needed there for `categorize.test.ts`; `repo.test.ts` needs one addition,
below).

### `src/lib/categorize.test.ts`

Covers `suggestCategory(description, rules)`:
- No rules / no match → `null`.
- Case-insensitive substring match.
- Two matching rules, different priority → higher priority wins.
- Two matching rules, same priority, different keyword length → longer
  (more specific) keyword wins.
- Keyword substring appears mid-word (current behavior: any substring
  match counts, not just whole-word) — document this as intentional via a
  test, since it's a real behavior a future change could accidentally
  break.

### `src/db/repo.test.ts`

Exercises the Dexie-backed CRUD functions against a **real Dexie instance
running on a fake IndexedDB**, so the test is exercising actual Dexie
query/transaction behavior, not a hand-rolled mock.

- Add `fake-indexeddb` as a devDependency.
- At the top of `repo.test.ts`, `import 'fake-indexeddb/auto'` **before**
  importing `../db/db` — this polyfills `indexedDB`/`IDBKeyRange` on
  `globalThis` so Dexie opens against the in-memory fake instead of
  throwing (there is no real IndexedDB in Node).
- `db.ts` exports a ready-made singleton (`export const db = new
  TravelDB()`), not a factory, so isolation between tests comes from a
  `beforeEach` that clears every table (`db.trips.clear()`,
  `db.transactions.clear()`, `db.categories.clear()`, `db.rules.clear()`),
  not from creating a new database per test.

Coverage:
- `createTrip` — creates the trip row and seeds it with all 10
  `DEFAULT_CATEGORIES`, scoped to that trip's id.
- `deleteTrip` — cascades: removes the trip, its categories, its
  transactions, and any `rules` pointing at those categories; a second
  trip's data is untouched.
- `setTripCityRange` — sets multiple days at once; passing `''` as the
  city clears those days instead of writing an empty string (mirrors the
  `setTripCity`/`setTripCityRange` behavior already unit-tested at the
  pure-function level for `groupCityBlocks`, but here through the actual
  read-modify-write against Dexie).
- `addTransaction` / `bulkAddTransactions` — rows get generated ids and a
  `createdAt`; bulk insert returns ids in the same order as the input.
- `deleteTransaction` / `deleteTransactions` — single and bulk removal.
- `addCategory` — auto-assigns the next `sortOrder` per trip (not global)
  when none is given.
- `deleteCategory` — cascades: any transaction referencing it gets
  `categoryId: null` (not deleted), and any `rules` row referencing it is
  removed.

## Part 2 — E2E tests (new: Playwright Test, desktop + mobile)

### Why a new subsystem

`scripts/smoke.mjs` already drives the real app with `playwright` (the
automation library), but as one long, unbroken script using raw
`page.*` calls and `process.exit` — no test runner, no per-scenario
isolation, no reporting, no mobile viewport. Adopting `@playwright/test`
(the actual test framework built on top of the same `playwright` library
already installed) gets us: independent test files that can run/fail/report
individually, built-in device emulation for mobile, automatic dev-server
startup, and retries/traces on failure.

### Setup

- Add `@playwright/test` as a devDependency (matching the installed
  `playwright` version).
- `playwright.config.ts` at the project root:
  - `testDir: 'e2e'`
  - `webServer`: runs `npm run dev`, reused if already running, so `npm
    run test:e2e` is a single command (no more "start the dev server in
    one terminal, run the script in another").
  - `projects`: two entries —
    - `desktop` — Chromium at a standard desktop viewport
      (`devices['Desktop Chrome']`).
    - `mobile` — Chromium emulating a real Android phone
      (`devices['Pixel 7']`) — chosen over an iPhone/WebKit preset
      because that's what's actually being used to test this app (Chrome
      on Android, per this session's screenshots), and it avoids an extra
      WebKit browser download.
  - Every test in the `mobile` project therefore automatically gets a
    touch-capable context (`hasTouch: true` from the device preset), so
    `.click()` on the new `ToggleLegend` exercises a real tap, not a mouse
    click simulated as one.

### Test isolation

Playwright Test gives every test its own fresh browser context by
default — no cookies/storage carried over between tests. Since IndexedDB
is scoped to that storage, **every test starts from a genuinely empty
database**, and the app's own `ensureSeeded()` re-seeds the Europa demo
trip on load. That means read-only assertions can rely on the seeded
Europa data being present and correct, and any test that mutates data
(creating/deleting trips, transactions, categories) does so in complete
isolation from every other test — no manual cleanup or shared fixtures
needed.

### Coverage — one spec file per area

Mirrors (and supersedes) everything `smoke.mjs` covered, reorganized so a
failure points at the specific feature, not "the one big script":

- `e2e/trip-dashboard.spec.ts` — open the Europa trip, KPI values are
  correct, all 6 tabs are reachable and show their expected section
  headers/tables, the "Por dia" and "Antes × Durante" chart legends
  respond to a tap by removing/restoring that series from the chart
  (`ToggleLegend`).
- `e2e/cities.spec.ts` — `CityEditor`: add a city via the "+ Adicionar
  cidade" control, add a date-range block, edit a block, remove a block,
  and the confirm-and-clear flow when removing a city tag that's still
  assigned to days.
- `e2e/transactions.spec.ts` — add, edit, delete a single transaction,
  select + bulk-delete, filter by category/city/period/date.
- `e2e/categories.spec.ts` — open Categories from a trip, create a
  category (name + color + icon), edit one, delete one (with confirm).
- `e2e/backup.spec.ts` — export triggers a download with the expected
  filename pattern; import round-trips it back in.
- `e2e/trip-lifecycle.spec.ts` — create a new trip end-to-end, then
  delete it from the edit-trip modal, back on the trips list.
- `e2e/i18n.spec.ts` — the PT/EN toggle actually changes visible text.

### Mobile-specific regression guard

Every spec above runs on **both** projects (that's the point — same test
file, two `projects` in the config), but the `mobile` project additionally
gets one extra assertion woven into each test after navigating to a new
tab/screen:

```ts
const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
);
expect(overflow).toBe(false);
```

This directly targets today's bug class (tables/tabs pushing the whole
page wider than the viewport) and turns it into a permanent regression
check across every screen, not just the ones manually re-tested today.

### Retiring `scripts/smoke.mjs`

Deleted once the new suite covers its scenarios — keeping both would mean
maintaining the same coverage twice.

## Part 3 — Wiring

`package.json` scripts:
- `test` — unchanged (`vitest run`, unit tests only, fast).
- `test:e2e` — new: `playwright test`.

`README.md`'s testing section gets rewritten to describe both commands
(handled as a separate, already-agreed-on follow-up task, not part of this
spec).

## Risks / things that could surprise us

- **Browser binary**: `@playwright/test` needs Chromium downloaded once
  via `npx playwright install chromium` — the plan should call this out
  explicitly as a one-time setup step, since `playwright` being an
  existing dependency doesn't guarantee the browser binary is already on
  this machine.
- **Timing flakiness**: the existing `smoke.mjs` leans on fixed
  `page.waitForTimeout(...)` calls. The new suite should prefer
  Playwright's built-in auto-waiting (`getByText(...).click()` already
  waits for the element) and explicit `waitFor`/`waitForURL` over sleeping
  a fixed duration, to keep tests fast and non-flaky.
- **fake-indexeddb + Dexie version compatibility**: needs a quick sanity
  check during implementation that the installed `fake-indexeddb` version
  supports the IndexedDB features Dexie 4.x relies on (compound indexes,
  used by `transactions: 'id, tripId, period, categoryId, date, city,
  [tripId+period]'` in `db.ts`).
