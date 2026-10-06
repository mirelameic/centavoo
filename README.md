<p align="center">
  <img src=".github/logo.png" alt="Centavoo" width="360" />
</p>

App to record and analyze travel expenses per trip. Each trip stores its transactions split by **period** (before / during), **category**, and **city**, with charts and other analysis.

- **Stack:** Flutter · Drift (SQLite) · flutter_localizations (pt / en).
- **Local-first:** all data lives on the device in one SQLite database. Works offline.

## Develop

```bash
flutter pub get
flutter run              # run on a connected device/emulator
flutter run -d <device>  # target a specific device (see `flutter devices`)
```

## Commands

| Command | Purpose |
| --- | --- |
| `flutter run` | Run the app on a device/emulator |
| `flutter build apk` / `flutter build ios` | Production build |
| `flutter analyze` | Static analysis |
| `flutter test` | Unit + widget tests |
| `dart format lib test tool` | Format code (120 columns, configured in `analysis_options.yaml`) |
| `dart run build_runner build --delete-conflicting-outputs` | Regenerate Drift code after a schema change |
| `dart run drift_dev schema dump lib/data/database.dart drift_schemas/app_database/` | Pre-release only: refresh the v1 schema snapshot after editing tables (see `CLAUDE.md`) |
| `dart run drift_dev make-migrations` | After publishing: snapshot a new schema version and generate migration steps/tests (see `CLAUDE.md`) |
| `dart run tool/draft_translations.dart` | Sync/draft `.arb` translation files |

## Regenerating the Europa seed

`assets/europa.json` is generated from a spreadsheet, reading each cell's **font color** to infer its category:

```bash
python3 -m venv scripts/.venv
scripts/.venv/bin/pip install openpyxl
scripts/.venv/bin/python scripts/seed_europa.py
```

## Europa backup file

`scripts/europa-backup.json` holds the same Europa trip as the seed, in the app's backup format, so it can be loaded through the header menu → Import once the seed is removed. Regenerate it after changing the seed or the schema:

```bash
flutter test tool/export_seed_backup.dart
```

## Android release signing

Release builds are signed with the key described in `android/key.properties` (gitignored, like the keystore itself). Without that file they fall back to the debug key, which the Play Store rejects. To set it up once:

```bash
keytool -genkey -v -keystore ~/centavoo-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties`:

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=/Users/<you>/centavoo-upload.jks
```

## Regenerating the app icon and splash screen

`assets/icon/*.png` are rendered directly from the app's own `Logo` widget (`lib/widgets/logo.dart`), so the launcher icon and splash screen always match the in-app logo exactly — no separate design file to keep in sync. Whenever the logo changes, regenerate everything with:

```bash
flutter test tool/render_brand_assets.dart --plain-name "app icon foreground"
flutter test tool/render_brand_assets.dart --plain-name "flat/legacy/iOS icon"
flutter test tool/render_brand_assets.dart --plain-name "Android 12"
flutter test tool/render_brand_assets.dart --plain-name "splash screen branding"
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

(Each render command is run separately and will print a `Bad state: Cannot close sink while adding stream` failure at shutdown — that's a `flutter test` teardown quirk when rendering images this way, not a real failure; the PNG under `assets/icon/` is written correctly before it happens.) Both tools are configured under `flutter_launcher_icons:`/`flutter_native_splash:` in `pubspec.yaml`, including the Android adaptive icon split (foreground/background) and the Android 12+ splash icon.

## Structure

See [`CLAUDE.md`](CLAUDE.md) for the full architecture rundown. In short:

- `lib/core/` — router, theme, and the theme/language controllers.
- `lib/logic/` — pure logic: stats for the dashboard, formatting, CSV parsing, category suggestions.
- `lib/data/` — Drift schema/tables, CRUD (`repo.dart`), seed, and JSON backup.
- `lib/models/` — plain Dart types used by the UI.
- `lib/screens/` — Trips, Trip (dashboard, split into tabs under `trip/`), Categories.
- `lib/widgets/` — shared widgets; `widgets/trip/` holds the trip-dashboard pieces (header, KPIs, tab bar, forms, importer).
- `lib/l10n/` — generated localizations from the `.arb` files; add a language by adding one there and an entry in the header's language menu.
- `scripts/` — `seed_europa.py`, generates `assets/europa.json` from the source spreadsheet.
