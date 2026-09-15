import 'fake-indexeddb/auto';
import { describe, it, expect, beforeEach } from 'vitest';
import { db } from './db';
import {
  DEFAULT_CATEGORIES,
  createTrip,
  deleteTrip,
  setTripCityRange,
  addTransaction,
  bulkAddTransactions,
  deleteTransaction,
  deleteTransactions,
  addCategory,
  deleteCategory,
  reassignTransactionPeriods,
} from './repo';

beforeEach(async () => {
  await db.transactions.clear();
  await db.trips.clear();
  await db.categories.clear();
  await db.rules.clear();
});

describe('createTrip', () => {
  it('creates the trip and seeds it with the default categories', async () => {
    const id = await createTrip({ name: 'Japan' });
    const trip = await db.trips.get(id);
    expect(trip).toMatchObject({ name: 'Japan', currency: 'BRL', cities: {} });

    const cats = await db.categories.where('tripId').equals(id).toArray();
    expect(cats).toHaveLength(DEFAULT_CATEGORIES.length);
    const byOrder = [...cats].sort((a, b) => a.sortOrder - b.sortOrder);
    expect(byOrder.map((c) => c.name)).toEqual(DEFAULT_CATEGORIES.map((c) => c.name));
  });

  it('scopes seeded categories to this trip only', async () => {
    const id1 = await createTrip({ name: 'Trip 1' });
    const id2 = await createTrip({ name: 'Trip 2' });
    const cats1 = await db.categories.where('tripId').equals(id1).toArray();
    const cats2 = await db.categories.where('tripId').equals(id2).toArray();
    expect(cats1.every((c) => c.tripId === id1)).toBe(true);
    expect(cats2.every((c) => c.tripId === id2)).toBe(true);
  });
});

describe('deleteTrip', () => {
  it('cascades: removes the trip, its categories, its transactions, and rules pointing at them', async () => {
    const id = await createTrip({ name: 'Japan' });
    const cats = await db.categories.where('tripId').equals(id).toArray();
    const catId = cats[0].id;
    await addTransaction({
      tripId: id,
      period: 'DURING',
      date: '2026-01-01',
      description: 'Sushi',
      amount: 50,
      categoryId: catId,
      kind: 'EXPENSE',
      isIof: false,
      splitCount: 1,
      city: null,
    });
    await db.rules.add({ keyword: 'sushi', categoryId: catId, priority: 1 });

    await deleteTrip(id);

    expect(await db.trips.get(id)).toBeUndefined();
    expect(await db.categories.where('tripId').equals(id).count()).toBe(0);
    expect(await db.transactions.where('tripId').equals(id).count()).toBe(0);
    expect(await db.rules.where('categoryId').equals(catId).count()).toBe(0);
  });

  it('leaves a different trip untouched', async () => {
    const keepId = await createTrip({ name: 'Keep me' });
    const deleteId = await createTrip({ name: 'Delete me' });
    await deleteTrip(deleteId);
    expect(await db.trips.get(keepId)).toBeDefined();
    expect(await db.categories.where('tripId').equals(keepId).count()).toBe(DEFAULT_CATEGORIES.length);
  });
});

describe('setTripCityRange', () => {
  it('sets the city for every day in the range at once', async () => {
    const id = await createTrip({ name: 'Japan' });
    await setTripCityRange(id, ['2026-01-01', '2026-01-02', '2026-01-03'], 'Tokyo');
    const trip = await db.trips.get(id);
    expect(trip?.cities).toEqual({
      '2026-01-01': 'Tokyo',
      '2026-01-02': 'Tokyo',
      '2026-01-03': 'Tokyo',
    });
  });

  it('clears days when the city is an empty string', async () => {
    const id = await createTrip({ name: 'Japan' });
    await setTripCityRange(id, ['2026-01-01', '2026-01-02'], 'Tokyo');
    await setTripCityRange(id, ['2026-01-01'], '');
    const trip = await db.trips.get(id);
    expect(trip?.cities).toEqual({ '2026-01-02': 'Tokyo' });
  });

  it('does nothing when the trip does not exist', async () => {
    await expect(setTripCityRange('missing', ['2026-01-01'], 'Tokyo')).resolves.toBeUndefined();
  });
});

describe('transactions', () => {
  it('addTransaction assigns an id and createdAt', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const id = await addTransaction({
      tripId,
      period: 'DURING',
      date: '2026-01-01',
      description: 'Ramen',
      amount: 20,
      categoryId: null,
      kind: 'EXPENSE',
      isIof: false,
      splitCount: 1,
      city: null,
    });
    const tx = await db.transactions.get(id);
    expect(tx).toMatchObject({ id, description: 'Ramen' });
    expect(tx?.createdAt).toBeTruthy();
  });

  it('bulkAddTransactions inserts every row and returns ids in the same order', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const ids = await bulkAddTransactions([
      {
        tripId, period: 'DURING', date: '2026-01-01', description: 'A',
        amount: 10, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
      },
      {
        tripId, period: 'DURING', date: '2026-01-02', description: 'B',
        amount: 20, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
      },
    ]);
    expect(ids).toHaveLength(2);
    const stored = await db.transactions.bulkGet(ids);
    expect(stored.map((t) => t?.description)).toEqual(['A', 'B']);
  });

  it('deleteTransaction removes a single row', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const id = await addTransaction({
      tripId, period: 'DURING', date: '2026-01-01', description: 'A',
      amount: 10, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
    });
    await deleteTransaction(id);
    expect(await db.transactions.get(id)).toBeUndefined();
  });

  it('deleteTransactions removes every listed row', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const ids = await bulkAddTransactions([
      {
        tripId, period: 'DURING', date: '2026-01-01', description: 'A',
        amount: 10, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
      },
      {
        tripId, period: 'DURING', date: '2026-01-02', description: 'B',
        amount: 20, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
      },
    ]);
    await deleteTransactions(ids);
    expect(await db.transactions.count()).toBe(0);
  });
});

describe('reassignTransactionPeriods', () => {
  it('flips a transaction from during to before when the new start date moves past it', async () => {
    const tripId = await createTrip({ name: 'Japan', startDate: '2026-05-17', endDate: '2026-06-03' });
    const duringId = await addTransaction({
      tripId, period: 'DURING', date: '2026-05-20', description: 'A',
      amount: 10, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
    });
    const beforeId = await addTransaction({
      tripId, period: 'BEFORE', date: '2026-05-10', description: 'B',
      amount: 20, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
    });
    const noDateId = await addTransaction({
      tripId, period: 'DURING', date: null, description: 'C',
      amount: 5, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
    });

    await reassignTransactionPeriods(tripId, '2026-05-25');

    expect((await db.transactions.get(duringId))?.period).toBe('BEFORE');
    expect((await db.transactions.get(beforeId))?.period).toBe('BEFORE');
    expect((await db.transactions.get(noDateId))?.period).toBe('DURING');
  });

  it('does nothing when the new start date is null', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const id = await addTransaction({
      tripId, period: 'DURING', date: '2026-05-20', description: 'A',
      amount: 10, categoryId: null, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
    });

    await reassignTransactionPeriods(tripId, null);

    expect((await db.transactions.get(id))?.period).toBe('DURING');
  });
});

describe('addCategory', () => {
  it('assigns the next sortOrder scoped to the trip, not globally', async () => {
    const tripA = await createTrip({ name: 'A' });
    const tripB = await createTrip({ name: 'B' });
    const idA = await addCategory({ tripId: tripA, name: 'Extra A', color: '#fff' });
    const idB = await addCategory({ tripId: tripB, name: 'Extra B', color: '#fff' });
    const catA = await db.categories.get(idA);
    const catB = await db.categories.get(idB);
    expect(catA?.sortOrder).toBe(DEFAULT_CATEGORIES.length);
    expect(catB?.sortOrder).toBe(DEFAULT_CATEGORIES.length);
  });
});

describe('deleteCategory', () => {
  it('clears the reference on any transaction that used it, without deleting the transaction', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const cats = await db.categories.where('tripId').equals(tripId).toArray();
    const catId = cats[0].id;
    const txId = await addTransaction({
      tripId, period: 'DURING', date: '2026-01-01', description: 'A',
      amount: 10, categoryId: catId, kind: 'EXPENSE', isIof: false, splitCount: 1, city: null,
    });

    await deleteCategory(catId);

    expect(await db.categories.get(catId)).toBeUndefined();
    const tx = await db.transactions.get(txId);
    expect(tx).toBeDefined();
    expect(tx?.categoryId).toBeNull();
  });

  it('removes any keyword rule pointing at the deleted category', async () => {
    const tripId = await createTrip({ name: 'Japan' });
    const cats = await db.categories.where('tripId').equals(tripId).toArray();
    const catId = cats[0].id;
    await db.rules.add({ keyword: 'ramen', categoryId: catId, priority: 1 });

    await deleteCategory(catId);

    expect(await db.rules.where('categoryId').equals(catId).count()).toBe(0);
  });
});
