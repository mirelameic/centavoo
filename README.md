<p align="center">
  <img src=".github/logo.png" alt="Centavoo" width="360" />
</p>

Personal app to record and analyze travel expenses per trip. Each trip stores its transactions split by **period** (before / during), **category**, and **city**, with charts and other analysis.

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
| `dart run build_runner build --delete-conflicting-outputs` | Regenerate Drift code after a schema change |
| `dart run tool/draft_translations.dart` | Sync/draft `.arb` translation files |

## Regenerating the Europa seed

`assets/europa.json` is generated from a spreadsheet, reading each cell's **font color** to infer its category:

```bash
python3 -m venv scripts/.venv
scripts/.venv/bin/pip install openpyxl
scripts/.venv/bin/python scripts/seed_europa.py
```

## Structure

See [`CLAUDE.md`](CLAUDE.md) for the full architecture rundown. In short:

- `lib/data/` — Drift schema/tables, CRUD (`repo.dart`), seed, and JSON backup.
- `lib/stats/` — pure aggregation logic that turns a trip's transactions into everything the dashboard renders.
- `lib/screens/` — Trips, Trip (dashboard, split into tabs under `trip/`), Categories.
- `lib/widgets/` — shared forms, the transaction importer, and trip-dashboard pieces.
- `lib/l10n/` — generated localizations from the `.arb` files; add a language by adding one there and an entry in `l10n.yaml`.
- `scripts/` — `seed_europa.py`, generates `assets/europa.json` from the source spreadsheet.
