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
dart run drift_dev schema dump lib/data/database.dart drift_schemas/app_database/   # PRE-RELEASE ONLY: refresh the v1 schema snapshot after editing tables
dart run drift_dev make-migrations                          # AFTER PUBLISHING: snapshot the new version + generate migration steps/tests after bumping schemaVersion
dart run tool/draft_translations.dart                       # sync/draft .arb translation files
dart format lib test tool                                   # format (120 columns, set in analysis_options.yaml); generated files are excluded by their own headers
```

Single test file / single test:

```bash
flutter test test/stats_test.dart
flutter test --plain-name "test name substring"
```

All tests run under `flutter test` (no separate DOM/non-DOM split like a JS test runner). Pure-logic files (everything in `lib/logic/`) get plain unit tests; everything else gets widget tests that pump a full widget tree. Widget tests build the app with `ptApp(home: ...)` / `ptRouterApp(routerConfig: ...)` from `test/helpers.dart` (pt-BR locale + localization delegates) instead of repeating the `MaterialApp` setup. `test/stats_golden_test.dart` is a frozen regression fixture (`test/fixtures/stats-golden-europa.json`) that locks `computeStats`/`cityBreakdown`'s output on the real Europa dataset — treat any change to that output as a red flag, not something to casually update. Several widget tests simulate a real phone viewport (`tester.view.physicalSize = const Size(360, 800)`) to catch `RenderFlex` overflows that the default 800×600 test surface hides — use that pattern for any new dialog/layout work, especially inside `AlertDialog`s where a hardcoded content width has caused real bugs before.

## Architecture

Folder layout (by type, mirroring the common Flutter layered layout without a ViewModel layer, which would be overkill here):
- `lib/main.dart`, `lib/app.dart` — entry point and the root widget (bootstrap, providers, `MaterialApp.router`).
- `lib/core/` — app-wide setup: `router.dart`, `theme.dart`, `theme_controller.dart`, `locale_controller.dart`.
- `lib/logic/` — pure Dart, no Flutter widgets/Drift: `stats.dart`, `format.dart`, `categorize.dart`, `parse_table.dart`.
- `lib/data/` — Drift database, tables, repository (writes), seed, backup, row ↔ model mappers.
- `lib/models/` — plain Dart types used by the UI.
- `lib/screens/` — one file per route; `screens/trip/` holds the Trip dashboard's tabs.
- `lib/widgets/` — widgets shared across screens (`app_shell`, `logo`, `confirm`, `category_form`, `category_icons`, `currency_dropdown`, `date_pickers`); `widgets/trip/` holds pieces used only by the Trip dashboard.
- `lib/l10n/` — `.arb` sources plus the generated localization classes.

**Local-first app, no backend.** All data lives in one SQLite database (Drift ORM) on the device. `lib/data/tables.dart` defines the Drift table schema; `lib/data/database.dart` wires up the `AppDatabase` class and its `schemaVersion` (see "Schema versioning" below — pre-release it stays at 1 with no migrations). `lib/models/*.dart` has the plain Dart types (`Trip`, `Category`, `Transaction`, `CategoryRule`); `lib/data/mappers.dart` converts between Drift row types and these models.

Data model, in one sentence each:
- **Trip** — a trip with a date range, a currency (picked from `supportedCurrencies` in `format.dart`; it only changes the symbol shown, amounts are never converted), a `cities` map (ISO date → city name, one entry per day), and a `sortOrder` (drives manual reordering on the Trips screen).
- **Category** — scoped to a trip (`tripId`), with color + icon, used to tag transactions.
- **Transaction** — scoped to a trip; split by `period` (`BEFORE`/`DURING` the trip), has a `kind` (`EXPENSE`/`REFUND`), an `isIof` flag (IOF refunds are tracked separately from normal refunds in stats), and `splitCount` (when an expense was shared — `cost()` in `stats/stats.dart` divides `amount` by it to get the actual share).
- **CategoryRule** — a global keyword → category mapping used to auto-suggest a category while importing/typing a transaction (`lib/categorize.dart`). Each rule stores both a `categoryId` and a `categoryName`; `suggestCategory` resolves it against the current trip's categories by id first and then by name (case-insensitive), so rules seeded for one trip also work for the default categories of any other trip. Rules are global, not trip-scoped: deleting a trip or a category keeps them, and renaming a category updates `categoryName` on the rules pointing at it. Rules are seed-only data (from `assets/europa.json`) — there's no UI to create/edit them.

Layers under `lib/data/`:
- `repo.dart` — all writes (CRUD). Multi-table operations (e.g. `deleteTrip`, `deleteCategory`) run inside `db.transaction(...)` to keep cascading deletes atomic. Creating a trip also seeds it with 9 default categories.
- `seed.dart` — on first load (or when `assets/europa.json`'s `version` field increases), seeds the DB from that JSON file, tracked via a `seedVersion` key in `SharedPreferences`. The Europa seed is temporary test data that will be removed before publishing.
- `backup.dart` — export/import the entire DB as one JSON file, used by the header's export/import menu in `widgets/app_shell.dart`. Import merges (`insertOrReplace` by id), never wipes, and backfills `categoryName` on rules from older backups.

`scripts/europa-backup.json` is the Europa seed as an importable backup file (so the trip can be loaded through the import menu once the seed is gone). It's generated by `flutter test tool/export_seed_backup.dart` from `assets/europa.json`, and `test/backup_test.dart` asserts that importing it yields exactly the same rows as seeding — regenerate it whenever the seed or the schema changes.

**Schema versioning — the app is NOT published yet, so `schemaVersion` stays at 1 and there are no migrations.** Nobody but the maintainer has a database on their device, so schema changes are made in place instead of as versioned upgrades. This changes completely on the day the app is published; read both modes below before touching `lib/data/tables.dart`.

*Pre-release (now):*
1. Edit `lib/data/tables.dart`, keep `schemaVersion => 1`, and don't add a `MigrationStrategy`/`onUpgrade`.
2. Run `dart run build_runner build --delete-conflicting-outputs`, then refresh the snapshot with `dart run drift_dev schema dump lib/data/database.dart drift_schemas/app_database/` (it overwrites `drift_schema_v1.json`). `test/drift/schema_snapshot_test.dart` fails if you forget.
3. Regenerate `scripts/europa-backup.json` (`flutter test tool/export_seed_backup.dart`).
4. On the maintainer's phone the existing database no longer matches: export a backup from the installed app first, then uninstall/reinstall (or clear the app's data) and import the backup. Backup import tolerates missing/extra fields, so this survives most schema edits.

*From the moment we decide to publish — mandatory, no exceptions:* the v1 snapshot as it exists at launch is frozen forever, and every schema change after that is a versioned migration, because real users' databases must be upgraded in place without losing data. Uses Drift's `make-migrations` workflow (configured in `build.yaml`):
1. Edit `lib/data/tables.dart` and bump `schemaVersion` (1 → 2, 2 → 3, …).
2. Run `dart run build_runner build --delete-conflicting-outputs`, then `dart run drift_dev make-migrations`. It saves `drift_schema_vN.json`, generates `lib/data/database.steps.dart` (a frozen, typed `SchemaN` per version plus the `stepByStep` helper) and `test/drift/app_database/` (generated helpers + a `migration_test.dart` template). It refuses to run if the schema changed without a version bump.
3. Add `migration: MigrationStrategy(onUpgrade: stepByStep(from1To2: (m, schema) async { ... }))` in `database.dart`. Each `fromXToY` step must only use the `schema` it receives plus raw SQL — never the live `tripsTable`/etc. getters or repo functions — so old steps keep working no matter how the tables change later.
4. Turn the generated `migration_test.dart` template into real tests (strip its comments/TODOs per the code style): keep the "every version → every later version" loop and add a `testWithDataIntegrity` case per step that inserts real rows in the old version and checks them after the upgrade.
5. Never edit an existing snapshot or an old step, and never use `schema dump` to overwrite a released version's snapshot.

`lib/logic/stats.dart` — pure aggregation functions (`computeStats`, `cityBreakdown`) that turn a trip's transactions into everything the dashboard renders (totals, per-category/per-city/per-weekday breakdowns, tables). No side effects, no Drift — this is what most of the unit tests exercise, and what the golden test locks against real data. Labels for uncategorized/IOF buckets are parameters (the screen passes the translated strings), and `avgPerDay` divides "during" spend by the trip length when `tripDays` is given (never by fewer days than had spending). Category totals only count expenses: refunds can't carry a category, so they show up in the net/refund KPIs, not in per-category numbers. The dashboard's KPI grid (`widgets/trip/kpi_grid.dart`) shows two rows: amounts (net, gross, refunds, IOF refunds — IOF is already included in refunds) and time (before, during, avg/day).

`assets/europa.json` is generated from a spreadsheet by `scripts/seed_europa.py`, which infers each transaction's category from the **font color** of its cell (see root README for the regen command).

**Routing** (`lib/core/router.dart`, go_router): a `ShellRoute` wraps every page in `AppShell` (header), with three routes inside — `/` (Trips list), `/trip/:id` (the Trip dashboard — the biggest page, charts + transaction table + import, split into per-tab files), `/trip/:id/categories` (per-trip category management).

**Components are organized by page, not by feature.** `lib/screens/trip/` holds the Trip dashboard's tabs (`summary_tab`, `ranking_tab`, `time_tab`, `cities_tab`, `categories_tab`, `transactions_tab`), each fed pre-computed `TripStats`/lists from `screens/trip_screen.dart`, which only wires data streams, tab state and layout. The tabs are the `TripTab` enum in `widgets/trip/trip_tab_bar.dart` (with the desktop chip row and the mobile bottom nav), so adding a tab is a compile-checked change. `lib/widgets/trip/` holds everything else specific to the Trip dashboard (`TripHeader`, `KpiGrid`, `TransactionForm`, `TripEditForm`, `ImportTransactions`, `CityEditor`, `TxRow`, `primitives.dart` for small shared bits like legends / category chips / charts). Category-related logic (`logic/categorize.dart`, `widgets/category_icons.dart`, `widgets/category_form.dart`) lives in shared locations rather than a `categories/` folder of its own, because it's consumed both by the Trip page (transaction forms/import) and by the Categories admin page — it's cross-cutting, not an isolated feature. Don't move it into a feature silo; that would just split call sites from usage without a real boundary.

**i18n** (`lib/l10n/`): generated from `.arb` files via `flutter gen-l10n` (config in `l10n.yaml`) — `app_pt_BR.arb` and `app_en.arb` are the real source files; `app_pt.arb` is a near-stub but is a **mandatory** fallback file (`flutter gen-l10n` hard-errors without it whenever a country-specific locale like `pt_BR` exists) and is kept in sync from `app_pt_BR.arb` by `tool/draft_translations.dart`, which also drafts missing `app_en.arb` keys as `[TODO en] ...` placeholders. `LocaleController` (`lib/core/locale_controller.dart`) stores the chosen language in `SharedPreferences` and sets a global `appLocale` string in `lib/logic/format.dart`, which `money()`/`fmtDate()` fall back to when no explicit locale is passed — this lets pure formatting functions stay locale-aware without threading `BuildContext`/`Locale` through every call site. `format.dart` is deliberately fussy about currency-symbol placement and weekday/month capitalization per each language's own convention (pt lowercase, en uppercase) — see its test file before changing it. To add a language: add its `.arb` file (it joins `AppLocalizations.supportedLocales` automatically after `flutter gen-l10n`), then add a menu entry in `widgets/app_shell.dart`'s language switcher.

**Theming** (`lib/core/theme.dart`): `buildDarkTheme()`/`buildLightTheme()`, dark palette built from the warm-neutral `darkSurfaces` scale with an orange primary. The light theme mirrors that same warm-neutral intent (white background, `lightHint`/`lightDivider`/`lightSubtleFill` instead of Flutter's default cool grays, explicit `chipTheme`/`segmentedButtonTheme`/`outlinedButtonTheme` overrides so filter chips and the period selector don't fall back to muddy auto-generated `ColorScheme.fromSeed` tones) — don't reintroduce default M3 chip/segmented-button colors on light mode. `highlightCard()` wraps a `Card` with a light-orange tint/border (`lightHighlightTint`/`lightHighlightBorder`) for the KPI cards and trip cards specifically, only in light mode; use it for any new "stat highlight" style card rather than a bare `Card()`. Refund amounts use `refundColor`; don't hardcode the teal again. Date pickers go through `widgets/date_pickers.dart` (`pickDate`/`pickDateRange`, years 2000–2100, initial date clamped) and ranges are shown with `fmtDateRange`/`fmtPickedRange`. The header wordmark and floating tab bars use a frosted-glass pattern (`BackdropFilter` blur over `glassTint(context)`) — light mode adds a subtle shadow/hairline border so it stays visible against the white background; dark mode does not, don't add one there. The logo (`lib/widgets/logo.dart`) is a procedural `CustomPainter`, not an image asset. The app icon and splash screen (`assets/icon/*.png`, configured via `flutter_launcher_icons:`/`flutter_native_splash:` in `pubspec.yaml`) are rendered from that same `Logo` widget by `tool/render_brand_assets.dart` (see README) — if the logo design changes, regenerate from there rather than hand-editing the PNGs.

## Code style

- No comments in code. None — not "why" comments, not explanatory ones, not in app code, not in tests/scripts/config. If something needs explaining, that belongs in the PR description or commit message, never inline. This has been asked for repeatedly — don't reintroduce comments while fixing or writing anything in this repo.
- Don't introduce new abstractions or folders speculatively — this is a small, single-maintainer app; put new files in the existing by-type folders described under Architecture (see the components note for why category logic isn't split into a feature folder). Nothing new goes loose in the root of `lib/`.
- Prefer enums over string constants for closed sets of options (see `TripTab`, the transactions tab's `_SortField`) so `switch`es stay exhaustive.
- Run `dart format` on what you touch; the page width (120) lives in `analysis_options.yaml`.

## Testing discipline

Always check tests around any change, in both directions:
- **After writing/changing behavior**: add or update tests that cover it (`test/*_test.dart` for pure logic, widget tests for user-facing flows) — don't ship new behavior with no test covering it.
- **After any change**: run `flutter analyze` and `flutter test` and confirm they pass before considering the work done. Don't assume something still works — verify it.
- For UI/layout changes, prefer verifying on a real device via hot reload when one is available, in addition to widget tests — several real overflow/layout bugs in this app were only visible on an actual phone-width screen, not the default test surface.

## Git

Read-only git commands (`status`, `diff`, `log`, `show`, `branch`, etc.) are fine to run freely. Never run any git command that changes state — `add`, `commit`, `push`, `checkout`, `reset`, `stash`, `restore`, `merge`, `rebase`, `branch -d`/`-D`, etc. The user runs all of those themselves; leave changes staged/unstaged as they are and let them decide when and how to commit.
