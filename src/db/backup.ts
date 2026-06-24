import { db } from './db';
import type { Category, CategoryRule, Transaction, Trip } from './schema';

// Full local database export/import as a single JSON file — how the user carries
// their data between devices/browsers (it lives in IndexedDB, not in the repo).

export interface BackupFile {
  app: 'centavoo';
  version: number;
  exportedAt: string;
  trips: Trip[];
  categories: Category[];
  transactions: Transaction[];
  rules: CategoryRule[];
}

export async function exportBackup(): Promise<void> {
  const [trips, categories, transactions, rules] = await Promise.all([
    db.trips.toArray(),
    db.categories.toArray(),
    db.transactions.toArray(),
    db.rules.toArray(),
  ]);
  const data: BackupFile = {
    app: 'centavoo',
    version: 1,
    exportedAt: new Date().toISOString(),
    trips,
    categories,
    transactions,
    rules,
  };
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `centavoo-backup-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

// Merges a backup file into the local database (upsert by id). Existing records
// with the same id are overwritten; new ones are added. Returns import counts.
export async function importBackup(
  file: File,
): Promise<{ trips: number; transactions: number; categories: number }> {
  const data = JSON.parse(await file.text()) as Partial<BackupFile>;
  if (!data || !Array.isArray(data.transactions)) {
    throw new Error('Invalid backup file');
  }
  await db.transaction('rw', [db.trips, db.categories, db.transactions, db.rules], async () => {
    if (Array.isArray(data.categories)) await db.categories.bulkPut(data.categories);
    if (Array.isArray(data.trips)) await db.trips.bulkPut(data.trips);
    if (Array.isArray(data.transactions)) await db.transactions.bulkPut(data.transactions);
    if (Array.isArray(data.rules)) await db.rules.bulkPut(data.rules);
  });
  return {
    trips: data.trips?.length ?? 0,
    transactions: data.transactions.length,
    categories: data.categories?.length ?? 0,
  };
}
