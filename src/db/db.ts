import Dexie, { type Table } from 'dexie';
import type { Trip, Category, Transaction, CategoryRule } from './schema';

export class TravelDB extends Dexie {
  trips!: Table<Trip, string>;
  categories!: Table<Category, string>;
  transactions!: Table<Transaction, string>;
  rules!: Table<CategoryRule, number>;

  constructor() {
    super('travel-expense');
    this.version(1).stores({
      trips: 'id, name, createdAt',
      categories: 'id, sortOrder',
      transactions: 'id, tripId, period, categoryId, date, city, [tripId+period]',
      rules: '++id, keyword, categoryId',
    });
    this.version(2).stores({
      categories: 'id, tripId, sortOrder, [tripId+sortOrder]',
    });
  }
}

export const db = new TravelDB();
