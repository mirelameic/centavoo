# Centavoo

Personal PWA to record and analyze travel expenses per trip.

Each trip stores its transactions split by **period** (before / during), **category**, and **city**, with charts and other analysis.

- **Stack:** Vite + React + TypeScript · Mantine (UI + charts) · Dexie (IndexedDB) · PWA.
- **Local-first:** data lives on your device (the browser). Works offline.

## Develop

```bash
npm install
npm run dev          # opens http://localhost:5173 — Ctrl+C to stop
```

The dev server runs only while that terminal is open (your data lives in the
browser's IndexedDB, so stopping the server never loses anything).

Kill a server left running in the background (e.g. a stray one on :5173):

```bash
lsof -ti:5173 | xargs kill
```

## Production build / install on your phone

A PWA needs HTTPS to install (localhost is the exception). For a faster,
production-like local run (with the PWA service worker active):

```bash
npm run build && npm run preview   # serves the build at http://localhost:4173
```

## Regenerate the Europa seed

The Europa data is generated from the spreadsheet by a Python script. It reads the
**font color** of each cell to infer the category (full fidelity to the sheet):

```bash
python3 -m venv scripts/.venv
scripts/.venv/bin/pip install openpyxl
scripts/.venv/bin/python scripts/seed_europa.py   # writes public/europa.json
```

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

