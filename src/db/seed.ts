import { db } from './db';
import type { Category, CategoryRule, Transaction, Trip } from './schema';

interface SeedFile {
  version: number;
  categories: Category[];
  rules: CategoryRule[];
  trips: Trip[];
  transactions: Transaction[];
}

const SEED_VERSION_KEY = 'seedVersion';

async function fetchSeed(): Promise<SeedFile> {
  const res = await fetch(`${import.meta.env.BASE_URL}europa.json`);
  if (!res.ok) throw new Error('Could not load europa.json');
  return res.json();
}

// Writes the seed into the local database. Idempotent: bulkPut upserts by id,
// so re-applying only touches the Europa trip + global categories/rules; trips
// the user created have different ids and are left untouched.
async function applySeed(data: SeedFile): Promise<void> {
  await db.transaction('rw', [db.trips, db.categories, db.transactions, db.rules], async () => {
    await db.categories.bulkPut(data.categories);
    await db.trips.bulkPut(data.trips);
    await db.transactions.bulkPut(data.transactions);
    await db.rules.clear();
    await db.rules.bulkAdd(data.rules.map(({ id: _id, ...r }) => r));
  });
  localStorage.setItem(SEED_VERSION_KEY, String(data.version));
}

// Manual re-import of the Europa data.
export async function importEuropa(): Promise<void> {
  await applySeed(await fetchSeed());
}

// Seeds on first run (empty DB) and re-applies when the seed file version bumps,
// so fixes to the Europa data reach an already-seeded browser on next load.
// Dedupes concurrent calls (e.g. React StrictMode in dev) with a singleton.
let seeding: Promise<boolean> | null = null;
export function ensureSeeded(): Promise<boolean> {
  if (!seeding) {
    seeding = (async () => {
      const data = await fetchSeed();
      const installed = Number(localStorage.getItem(SEED_VERSION_KEY) || '0');
      const empty = (await db.trips.count()) === 0;
      if (empty || data.version > installed) {
        await applySeed(data);
        return true;
      }
      return false;
    })();
  }
  return seeding;
}
