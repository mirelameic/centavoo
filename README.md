# Centavoo

Personal PWA to record and analyze travel expenses per trip. Each trip stores its
transactions split by **period** (before / during), **category**, and **city**,
with charts and — soon — import from a bill screenshot.

- **Stack:** Vite + React + TypeScript · Mantine (UI + charts) · Dexie (IndexedDB) · PWA.
- **Local-first:** data lives on your device (the browser). Works offline.
- **Languages:** UI in Portuguese or English (toggle in the header). Default: Portuguese.
- The **Europa 2025** trip is preloaded, imported from `gastos-europa.xlsx`.

## Develop

```bash
npm install
npm run dev          # opens http://localhost:5173
```

## Production build / install on your phone

A PWA needs HTTPS to install (localhost is the exception). Local build:

```bash
npm run build && npm run preview   # serves the build at http://localhost:4173
```

To install on **Android** (becomes a real app, with an icon):
1. Deploy for free (Vercel/Netlify) — `vercel.json` already sets the SPA fallback.
2. Open the HTTPS URL in Chrome on the phone → menu → **Install app**.

## Regenerate the Europa seed

The Europa data is generated from the spreadsheet by a Python script. It reads the
**font color** of each cell to infer the category (full fidelity to the sheet):

```bash
python3 -m venv scripts/.venv
scripts/.venv/bin/pip install openpyxl
scripts/.venv/bin/python scripts/seed_europa.py   # writes public/europa.json
```

The script validates totals against the sheet (during 10,754.85 / −311.29; before 14,874.43).

## Smoke test (headless)

```bash
npm run dev &                 # server on :5173
node scripts/smoke.mjs        # loads the app, checks KPIs, saves screenshots to /tmp
```

## Structure

- `src/db/` — model (`schema.ts`), Dexie database (`db.ts`), aggregations (`repo.ts`), seed.
- `src/lib/` — formatting, auto-categorization, and (future) import parsers.
- `src/i18n.tsx` — translations (pt/en) and locale-aware formatting.
- `src/pages/` — screens (Trips, Trip, …).
- `scripts/seed_europa.py` — generates `public/europa.json` from the xlsx.

## Roadmap

- [x] **M1** — foundation + Europa imported + dashboards (summary, by day, by city, before×during).
- [ ] **M2** — add/edit transactions and categories; JSON backup export/import.
- [ ] **M3** — import by pasting the bill text (parser + review + auto-category).
- [ ] **M4** — compare trips.
- [ ] **M5** — bill photo with in-browser OCR (Tesseract.js).
