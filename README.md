<p align="center">
  <img src=".github/logo.png" alt="Centavoo" width="360" />
</p>

Personal PWA to record and analyze travel expenses per trip. Each trip stores its transactions split by **period** (before / during), **category**, and **city**, with charts and other analysis.

- **Stack:** Vite + React + TypeScript · Mantine (UI + charts) · Dexie (IndexedDB) · react-i18next · PWA.
- **Local-first:** data lives on your device (the browser). Works offline.

## Develop

```bash
npm install
npm run dev   # http://localhost:5173
```

## Scripts

| Command              | Purpose                              |
| --------------------- | ------------------------------------- |
| `npm run dev`          | Dev server                            |
| `npm run build`        | Type-check + production build         |
| `npm run preview`      | Serve the production build            |
| `npm run lint`         | ESLint                                |
| `npm run test`         | Unit tests (Vitest)                   |
| `npm run test:e2e`     | End-to-end tests (Playwright)         |

## Installing on your phone

A PWA needs HTTPS to install (localhost is the exception). To try the installable build locally, with the service worker active:

```bash
npm run build && npm run preview   # http://localhost:4173
```

## Regenerating the Europa seed

`public/europa.json` is generated from a spreadsheet, reading each cell's **font color** to infer its category:

```bash
python3 -m venv scripts/.venv
scripts/.venv/bin/pip install openpyxl
scripts/.venv/bin/python scripts/seed_europa.py
```

## Structure

- `src/db/` — schema, Dexie database, CRUD (`repo.ts`), analytics (`stats.ts`), seed, and backup.
- `src/lib/` — formatting/date helpers, auto-categorization, statement parsing, shared constants.
- `src/components/` — `Logo`, shared forms, the transaction importer, and the trip dashboard pieces (`trip/`).
- `src/i18n/` — translations (`locales/pt.ts`, `locales/en.ts`); add a language by adding a locale file and an entry in `config.ts`.
- `src/pages/` — screens: Trips, Trip, Categories.
- `scripts/` — `seed_europa.py` (generates `public/europa.json`), `render-icon.mjs` (SVG → PNG icon preview).
