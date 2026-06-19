import Dexie, { type Table } from 'dexie';
import type { Trip, Category, Transaction, CategoryRule } from './schema';

// Local on-device database (IndexedDB). Fully client-side, works offline.
export class TravelDB extends Dexie {
  trips!: Table<Trip, string>;
  categories!: Table<Category, string>;
  transactions!: Table<Transaction, string>;
  rules!: Table<CategoryRule, number>;

  constructor() {
    super('travel-expense');
    this.version(1).stores({
      // 'id' = primary key; other fields = indexes for lookups/sorting
      trips: 'id, name, createdAt',
      categories: 'id, sortOrder',
      transactions: 'id, tripId, period, categoryId, date, city, [tripId+period]',
      rules: '++id, keyword, categoryId',
    });
    // v2: categories became per-trip.
    this.version(2).stores({
      categories: 'id, tripId, sortOrder, [tripId+sortOrder]',
    });
  }
}

export const db = new TravelDB();
