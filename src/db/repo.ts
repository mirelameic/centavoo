import { db } from './db';
import type { Category, CityMap, Transaction, Trip } from './schema';

// Default categories created for every new trip (categories are per-trip).
export const DEFAULT_CATEGORIES: Omit<Category, 'id' | 'tripId'>[] = [
  { name: 'Hospedagem', color: '#0E8C6B', icon: 'bed', sortOrder: 0 },
  { name: 'Passagem', color: '#B8860B', icon: 'plane', sortOrder: 1 },
  { name: 'Transporte', color: '#C2540D', icon: 'car', sortOrder: 2 },
  { name: 'Alimentação', color: '#C1352E', icon: 'food', sortOrder: 3 },
  { name: 'Compras', color: '#B23368', icon: 'shopping', sortOrder: 4 },
  { name: 'Brindes', color: '#7D1F44', icon: 'gift', sortOrder: 5 },
  { name: 'Turismo', color: '#8A7220', icon: 'ticket', sortOrder: 6 },
  { name: 'Genéricos de viagem', color: '#7A4A2A', icon: 'luggage', sortOrder: 7 },
  { name: 'Cannabis', color: '#3D8B4C', icon: 'leaf', sortOrder: 8 },
  { name: 'Outros', color: '#5C5650', icon: 'bookmark', sortOrder: 9 },
];

// ---- trips -------------------------------------------------------------------
export async function createTrip(
  data: Omit<Trip, 'id' | 'createdAt' | 'currency'> & { currency?: string },
): Promise<string> {
  const id = `trip_${crypto.randomUUID()}`;
  await db.trips.add({
    ...data,
    id,
    currency: data.currency ?? 'BRL',
    cities: data.cities ?? {},
    createdAt: new Date().toISOString(),
  });
  // seed this trip with its own default categories
  await db.categories.bulkAdd(
    DEFAULT_CATEGORIES.map((c) => ({ ...c, id: `cat_${crypto.randomUUID()}`, tripId: id })),
  );
  return id;
}

export const updateTrip = (id: string, patch: Partial<Trip>) => db.trips.update(id, patch);

// Permanently delete a trip and everything that belongs to it.
export async function deleteTrip(id: string) {
  await db.transaction('rw', [db.trips, db.transactions, db.categories, db.rules], async () => {
    const catIds = (await db.categories.where('tripId').equals(id).primaryKeys()) as string[];
    if (catIds.length) await db.rules.where('categoryId').anyOf(catIds).delete();
    await db.transactions.where('tripId').equals(id).delete();
    await db.categories.where('tripId').equals(id).delete();
    await db.trips.delete(id);
  });
}

// Set the city of a day. Stored on the trip (a day = a city), so it persists
// even for days without transactions and even when cleared to empty.
export async function setTripCity(tripId: string, date: string, city: string) {
  const trip = await db.trips.get(tripId);
  if (!trip) return;
  const cities: CityMap = { ...(trip.cities ?? {}) };
  const v = city.trim();
  if (v) cities[date] = v;
  else delete cities[date];
  await db.trips.update(tripId, { cities });
}

// ---- transactions ------------------------------------------------------------
export async function addTransaction(
  t: Omit<Transaction, 'id' | 'createdAt'>,
): Promise<string> {
  const id = `tx_${crypto.randomUUID()}`;
  await db.transactions.add({ ...t, id, createdAt: new Date().toISOString() });
  return id;
}

export const updateTransaction = (id: string, patch: Partial<Transaction>) =>
  db.transactions.update(id, patch);

export const deleteTransaction = (id: string) => db.transactions.delete(id);

export const deleteTransactions = (ids: string[]) => db.transactions.bulkDelete(ids);

// Inserts many transactions at once (statement import) — same shape as
// addTransaction, batched into a single Dexie call.
export async function bulkAddTransactions(
  rows: Omit<Transaction, 'id' | 'createdAt'>[],
): Promise<string[]> {
  const createdAt = new Date().toISOString();
  const withIds = rows.map((r) => ({ ...r, id: `tx_${crypto.randomUUID()}`, createdAt }));
  await db.transactions.bulkAdd(withIds);
  return withIds.map((r) => r.id);
}

// ---- categories --------------------------------------------------------------
export async function addCategory(
  data: Omit<Category, 'id' | 'sortOrder'> & { sortOrder?: number },
): Promise<string> {
  const id = `cat_${crypto.randomUUID()}`;
  const existing = await db.categories.where('tripId').equals(data.tripId).toArray();
  const maxOrder = existing.reduce((m, c) => Math.max(m, c.sortOrder), -1);
  await db.categories.add({ ...data, id, sortOrder: data.sortOrder ?? maxOrder + 1 });
  return id;
}

export const updateCategory = (id: string, patch: Partial<Category>) =>
  db.categories.update(id, patch);

// Deleting a category clears it from any transaction that used it.
export async function deleteCategory(id: string) {
  await db.transaction('rw', [db.categories, db.transactions, db.rules], async () => {
    await db.transactions.where('categoryId').equals(id).modify({ categoryId: null });
    await db.rules.where('categoryId').equals(id).delete();
    await db.categories.delete(id);
  });
}
