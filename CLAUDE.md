# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get                  # install dependencies
flutter run                      # run on a connected device/emulator (see `flutter devices`)
flutter run -d <device-id>       # target a specific device (e.g. a physical phone over USB)
flutter build apk / ios          # production build
flutter analyze                  # static analysis, must be clean
flutter test                     # unit + widget tests, run once
dart run build_runner build --delete-conflicting-outputs   # regenerate Drift code after a schema change
dart run tool/draft_translations.dart                       # sync/draft .arb translation files
```

Single test file / single test:

```bash
flutter test test/stats_test.dart
flutter test --plain-name "test name substring"
```

All tests run under `flutter test` (no separate DOM/non-DOM split like a JS test runner). Pure-logic files (`lib/stats/stats.dart`, `lib/parse_table.dart`, `lib/format.dart`, `lib/categorize.dart`) get plain unit tests; everything else gets widget tests that pump a full widget tree. `test/stats_golden_test.dart` is a frozen regression fixture (`test/fixtures/stats-golden-europa.json`) that locks `computeStats`/`cityBreakdown`'s output on the real Europa dataset — treat any change to that output as a red flag, not something to casually update. Several widget tests simulate a real phone viewport (`tester.view.physicalSize = const Size(360, 800)`) to catch `RenderFlex` overflows that the default 800×600 test surface hides — use that pattern for any new dialog/layout work, especially inside `AlertDialog`s where a hardcoded content width has caused real bugs before.

## Architecture

**Local-first app, no backend.** All data lives in one SQLite database (Drift ORM) on the device. `lib/data/tables.dart` defines the Drift table schema; `lib/data/database.dart` wires up the `AppDatabase` class and its `MigrationStrategy` (schema version bumps go here — remember to run `build_runner` after). `lib/models/*.dart` has the plain Dart types (`Trip`, `Category`, `Transaction`, `CategoryRule`); `lib/data/mappers.dart` converts between Drift row types and these models.

Data model, in one sentence each:
- **Trip** — a trip with a date range, currency, a `cities` map (ISO date → city name, one entry per day), and a `sortOrder` (drives manual reordering on the Trips screen).
- **Category** — scoped to a trip (`tripId`), with color + icon, used to tag transactions.
- **Transaction** — scoped to a trip; split by `period` (`BEFORE`/`DURING` the trip), has a `kind` (`EXPENSE`/`REFUND`), an `isIof` flag (IOF refunds are tracked separately from normal refunds in stats), and `splitCount` (when an expense was shared — `cost()` in `stats/stats.dart` divides `amount` by it to get the actual share).
- **CategoryRule** — a keyword → category mapping used to auto-suggest a category while importing/typing a transaction (`lib/categorize.dart`). Rules are seed-only data (from `assets/europa.json`) — there's no UI to create/edit them.

Layers under `lib/data/`:
- `repo.dart` — all writes (CRUD). Multi-table operations (e.g. `deleteTrip`, `deleteCategory`) run inside `db.transaction(...)` to keep cascading deletes atomic. Creating a trip also seeds it with 9 default categories.
- `seed.dart` — on first load (or when `assets/europa.json`'s `version` field increases), seeds the DB from that JSON file, tracked via a `seedVersion` key in `SharedPreferences`.
- `backup.dart` — export/import the entire DB as one JSON file, used by the header's export/import menu in `widgets/app_shell.dart`.

`lib/stats/stats.dart` — pure aggregation functions (`computeStats`, `cityBreakdown`) that turn a trip's transactions into everything the dashboard renders (totals, per-category/per-city/per-weekday breakdowns, tables). No side effects, no Drift — this is what most of the unit tests exercise, and what the golden test locks against real data.

`assets/europa.json` is generated from a spreadsheet by `scripts/seed_europa.py`, which infers each transaction's category from the **font color** of its cell (see root README for the regen command).

**Routing** (`lib/router.dart`, go_router): a `ShellRoute` wraps every page in `AppShell` (header), with three routes inside — `/` (Trips list), `/trip/:id` (the Trip dashboard — the biggest page, charts + transaction table + import, split into per-tab files), `/trip/:id/categories` (per-trip category management).

**Components are organized by page, not by feature.** `lib/screens/trip/` holds the Trip dashboard's tabs (`summary_tab`, `ranking_tab`, `time_tab`, `cities_tab`, `categories_tab`, `transactions_tab`), each fed pre-computed `TripStats`/lists from `screens/trip_screen.dart`. `lib/widgets/trip/` holds everything else specific to the Trip dashboard (`TransactionForm`, `TripEditForm`, `ImportTransactions`, `CityEditor`, `TxRow`, `primitives.dart` for small shared bits like KPI cards / legends / category chips). Category-related logic (`lib/categorize.dart`, `category_icons.dart`, `widgets/category_form.dart`) lives in shared locations rather than a `categories/` folder of its own, because it's consumed both by the Trip page (transaction forms/import) and by the Categories admin page — it's cross-cutting, not an isolated feature. Don't move it into a feature silo; that would just split call sites from usage without a real boundary.

**i18n** (`lib/l10n/`): generated from `.arb` files via `flutter gen-l10n` (config in `l10n.yaml`) — `app_pt_BR.arb` and `app_en.arb` are the real source files; `app_pt.arb` is a near-stub but is a **mandatory** fallback file (`flutter gen-l10n` hard-errors without it whenever a country-specific locale like `pt_BR` exists) and is kept in sync from `app_pt_BR.arb` by `tool/draft_translations.dart`, which also drafts missing `app_en.arb` keys as `[TODO en] ...` placeholders. `LocaleController` (`lib/locale_controller.dart`) stores the chosen language in `SharedPreferences` and sets a global `appLocale` string in `lib/format.dart`, which `money()`/`fmtDate()` fall back to when no explicit locale is passed — this lets pure formatting functions stay locale-aware without threading `BuildContext`/`Locale` through every call site. `format.dart` is deliberately fussy about currency-symbol placement and weekday/month capitalization per each language's own convention (pt lowercase, en uppercase) — see its test file before changing it. To add a language: add its `.arb` file (it joins `AppLocalizations.supportedLocales` automatically after `flutter gen-l10n`), then add a menu entry in `widgets/app_shell.dart`'s language switcher.

**Theming** (`lib/theme.dart`): `buildDarkTheme()`/`buildLightTheme()`, dark palette built from the warm-neutral `darkSurfaces` scale with an orange primary. The light theme mirrors that same warm-neutral intent (white background, `lightHint`/`lightDivider`/`lightSubtleFill` instead of Flutter's default cool grays, explicit `chipTheme`/`segmentedButtonTheme`/`outlinedButtonTheme` overrides so filter chips and the period selector don't fall back to muddy auto-generated `ColorScheme.fromSeed` tones) — don't reintroduce default M3 chip/segmented-button colors on light mode. `highlightCard()` wraps a `Card` with a light-orange tint/border (`lightHighlightTint`/`lightHighlightBorder`) for the KPI cards and trip cards specifically, only in light mode; use it for any new "stat highlight" style card rather than a bare `Card()`. The header wordmark and floating tab bars use a frosted-glass `_glassBar`/`barTint` pattern (`BackdropFilter` blur) — light mode adds a subtle shadow/hairline border so it stays visible against the white background; dark mode does not, don't add one there. The logo (`lib/widgets/logo.dart`) is a procedural `CustomPainter`, not an image asset.

## Code style

- No comments in code. None — not "why" comments, not explanatory ones, not in app code, not in tests/scripts/config. If something needs explaining, that belongs in the PR description or commit message, never inline. This has been asked for repeatedly — don't reintroduce comments while fixing or writing anything in this repo.
- Don't introduce new abstractions or folders speculatively — this is a small, single-maintainer app; prefer the flat/by-type structure already in place (see the components note above for why category logic isn't split out).

## Testing discipline

Always check tests around any change, in both directions:
- **After writing/changing behavior**: add or update tests that cover it (`test/*_test.dart` for pure logic, widget tests for user-facing flows) — don't ship new behavior with no test covering it.
- **After any change**: run `flutter analyze` and `flutter test` and confirm they pass before considering the work done. Don't assume something still works — verify it.
- For UI/layout changes, prefer verifying on a real device via hot reload when one is available, in addition to widget tests — several real overflow/layout bugs in this app were only visible on an actual phone-width screen, not the default test surface.

## Git

Read-only git commands (`status`, `diff`, `log`, `show`, `branch`, etc.) are fine to run freely. Never run any git command that changes state — `add`, `commit`, `push`, `checkout`, `reset`, `stash`, `restore`, `merge`, `rebase`, `branch -d`/`-D`, etc. The user runs all of those themselves; leave changes staged/unstaged as they are and let them decide when and how to commit.
