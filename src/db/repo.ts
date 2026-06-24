import { db } from './db';
import type { Category, CityMap, Transaction, Trip } from './schema';

// Default categories created for every new trip (categories are per-trip).
export const DEFAULT_CATEGORIES: Omit<Category, 'id' | 'tripId'>[] = [
  { name: 'Hospedagem', color: '#0CA678', icon: '🏨', sortOrder: 0 },
  { name: 'Passagem', color: '#4263EB', icon: '✈️', sortOrder: 1 },
  { name: 'Transporte', color: '#FF9900', icon: '🚕', sortOrder: 2 },
  { name: 'Alimentação', color: '#9900FF', icon: '🍽️', sortOrder: 3 },
  { name: 'Compras', color: '#4A86E8', icon: '🛍️', sortOrder: 4 },
  { name: 'Brindes', color: '#00B5C7', icon: '🎁', sortOrder: 5 },
  { name: 'Turismo', color: '#E6B800', icon: '🎟️', sortOrder: 6 },
  { name: 'Genéricos de viagem', color: '#FF0000', icon: '🧳', sortOrder: 7 },
  { name: 'Cannabis', color: '#00C000', icon: '🌿', sortOrder: 8 },
  { name: 'Outros', color: '#FF00FF', icon: '🔖', sortOrder: 9 },
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
