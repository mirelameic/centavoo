# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm run dev              # dev server at http://localhost:5173
npm run dev -- --host    # also listens on the network (for testing on a phone, same Wi-Fi)
npm run build            # tsc -b + vite build (type-checks the whole project)
npm run lint             # ESLint
npm run test             # unit tests (Vitest, run once)
npm run test:watch       # unit tests, watch mode
npm run test:e2e         # e2e tests (Playwright; auto-starts the dev server)
npm run preview          # serve the production build (needed to exercise the PWA service worker)
```

Single test file / single test:

```bash
npx vitest run src/lib/format.test.ts
npx vitest run -t "test name substring"
npx playwright test e2e/cities.spec.ts
npx playwright test --project=mobile e2e/trip-dashboard.spec.ts
```

Unit tests (`src/**/*.test.ts`) run in a plain Node environment (see `vitest.config.ts`) — they only cover pure TypeScript with no DOM dependency (`src/db/stats.ts`, `src/lib/*`). Playwright has `desktop` and `mobile` (Pixel 7) projects; `workers` is capped at 4 in `playwright.config.ts` because higher parallelism caused real timeouts from resource contention on a memory-constrained dev machine.

## Architecture

**Local-first PWA, no backend.** All data lives in one IndexedDB database (`travel-expense`, Dexie) on the device. `src/db/db.ts` defines the Dexie schema/versions; `src/db/schema.ts` has the plain TS types (`Trip`, `Category`, `Transaction`, `CategoryRule`).

Data model, in one sentence each:
- **Trip** — a trip with a date range, currency, and a `cities: CityMap` (ISO date → city name, one entry per day).
- **Category** — scoped to a trip (`tripId`), with color + icon, used to tag transactions.
- **Transaction** — scoped to a trip; split by `period` (`BEFORE`/`DURING` the trip), has a `kind` (`EXPENSE`/`REFUND`), an `isIof` flag (IOF refunds are tracked separately from normal refunds in stats), and `splitCount` (when an expense was shared — `cost()` in `stats.ts` divides `amount` by it to get the actual share).
- **CategoryRule** — a keyword → category mapping used to auto-suggest a category while importing/typing a transaction (`src/lib/categorize.ts`).

Layers under `src/db/`:
- `repo.ts` — all writes (CRUD). Multi-table operations (e.g. `deleteTrip`, `deleteCategory`) run inside `db.transaction('rw', ...)` to keep cascading deletes atomic.
- `stats.ts` — pure aggregation functions (`computeStats`, `cityBreakdown`) that turn a trip's transactions into everything the dashboard renders (totals, per-category/per-city/per-weekday breakdowns, tables). No side effects, no Dexie — this is what the unit tests exercise.
- `seed.ts` — on first load (or when `public/europa.json`'s `version` field increases), seeds the DB from that JSON file. `ensureSeeded()` memoizes the in-flight promise so concurrent callers don't double-seed.
- `backup.ts` — export/import the entire DB as one JSON file (`BackupFile`), used by the header's export/import menu in `App.tsx`.

`public/europa.json` is generated from a spreadsheet by `scripts/seed_europa.py`, which infers each transaction's category from the **font color** of its cell (see README for the regen command).

**Routing** (`src/routes.tsx`): three routes nested under the `App` shell — `/` (Trips list), `/trip/:id` (the Trip dashboard — the biggest page, charts + transaction table + import), `/trip/:id/categories` (per-trip category management).

**Components are organized by page, not by feature.** `src/components/trip/` holds everything specific to the Trip dashboard (`TransactionForm`, `TripForm`, `ImportTransactions`, `CityEditor`, `TopTable`, `CategoryOption`, `TripFields`, `primitives.tsx` for small shared bits like `Kpi`/`Section`/`CategoryChip`). Category-related logic (`src/lib/categorize.ts`, `categoryIcons.tsx`, `categories.ts`, `CategoryOption.tsx`) lives in shared locations (`lib/`, `components/trip/`) rather than a `categories/` folder of its own, because it's consumed both by the Trip page (transaction forms/import) and by the Categories admin page — it's cross-cutting, not an isolated feature. Don't move it into a feature silo; that would just split call sites from usage without a real boundary.

**i18n** (`src/i18n/`): `config.ts` initializes i18next with the two locales (`locales/pt.ts`, `locales/en.ts`) and stores the chosen language in `localStorage`. The `useI18n()` hook (`useI18n.ts`) wraps `t()` and also exposes locale-aware `money()`/`date()` formatting (backed by `src/lib/format.ts`, which is deliberately fussy about currency-symbol placement across locales — see its test file before changing it). To add a language: add a locale file and one entry in `LANGUAGES` in `config.ts`.

**Theming**: Mantine theme in `src/theme.ts` (dark palette, orange primary). The header wordmark (`App.tsx`) uses the Google Font "Unbounded" (loaded in `index.html`), matching `.github/logo.png`.

## Code style

- No comments in code. None — not "why" comments, not explanatory ones, not in app code, not in tests/scripts/config. If something needs explaining, that belongs in the PR description or commit message, never inline. This has been asked for repeatedly — don't reintroduce comments while fixing or writing anything in this repo.
- Don't introduce new abstractions or folders speculatively — this is a small, single-maintainer app; prefer the flat/by-type structure already in place (see the components note above for why category logic isn't split out).

## Testing discipline

Always check tests around any change, in both directions:
- **After writing/changing behavior**: add or update tests that cover it (unit tests in `src/**/*.test.ts` for pure logic, e2e specs in `e2e/` for user-facing flows) — don't ship new behavior with no test covering it.
- **After any change**: run the relevant test command(s) (`npm run lint`, `npx tsc -b`, `npm run test`, and `npm run test:e2e` when UI/flow behavior changed) and confirm they pass before considering the work done. Don't assume something still works — verify it.

## Git

Read-only git commands (`status`, `diff`, `log`, `show`, `branch`, etc.) are fine to run freely. Never run any git command that changes state — `add`, `commit`, `push`, `checkout`, `reset`, `stash`, `restore`, `merge`, `rebase`, `branch -d`/`-D`, etc. The user runs all of those themselves; leave changes staged/unstaged as they are and let them decide when and how to commit.
