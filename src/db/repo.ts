import { db } from './db';
import type { Category, Transaction, Trip } from './schema';

// Effective cost of a transaction: applies the split (e.g. a shared Airbnb).
// `amount` always holds the full (integral) value; this divides it by splitCount.
export const cost = (t: Transaction) => t.amount / (t.splitCount || 1);

// Palette used to color cities in the "by city" chart.
const CITY_PALETTE = [
  '#4263EB', '#0CA678', '#F08C00', '#E64980', '#7048E8',
  '#1098AD', '#F03E3E', '#66A80F', '#AE3EC9', '#1864AB',
];

// ---- basic CRUD --------------------------------------------------------------
export async function createTrip(
  data: Omit<Trip, 'id' | 'createdAt' | 'currency'> & { currency?: string },
): Promise<string> {
  const id = `trip_${crypto.randomUUID()}`;
  await db.trips.add({
    ...data,
    id,
    currency: data.currency ?? 'BRL',
    createdAt: new Date().toISOString(),
  });
  return id;
}

export async function addTransaction(
  t: Omit<Transaction, 'id' | 'createdAt'>,
): Promise<string> {
  const id = `tx_${crypto.randomUUID()}`;
  await db.transactions.add({ ...t, id, createdAt: new Date().toISOString() });
  return id;
}

export const tripTransactions = (tripId: string) =>
  db.transactions.where('tripId').equals(tripId).toArray();

// Set the city for every transaction on a given date (a day = a city).
export async function setCityForDate(tripId: string, date: string, city: string) {
  await db.transactions
    .where('tripId')
    .equals(tripId)
    .and((t) => t.date === date)
    .modify({ city: city.trim() || null });
}

// ---- aggregations (analytics) ------------------------------------------------
export interface CatAgg {
  id: string | null;
  name: string;
  color: string;
  amount: number;
}

export interface TripStats {
  gross: number; // sum of expenses (positive)
  refunds: number; // sum of refunds (negative)
  net: number; // net
  before: number; // net for the "before" period
  during: number; // net for the "during" period
  iofRefund: number; // sum of IOF refunds
  days: number; // number of days with spending during the trip
  avgPerDay: number; // during net / days
  byCategory: CatAgg[]; // expenses by category (whole trip), desc
  usedCategories: { name: string; color: string }[]; // categories present
  dayData: Record<string, number | string>[]; // [{ date:'17/05', Alimentação: 10, ... }]
  beforeDuringData: { category: string; antes: number; durante: number }[];
  byCity: { city: string; amount: number; color: string }[]; // expenses by city
  daysByCity: { date: string; city: string }[]; // current city for each dated day
}

const NO_CAT = { name: 'No category', color: '#adb5bd' };
const IOF_CAT = { name: 'IOF refund', color: '#868e96' };

export function computeStats(txs: Transaction[], cats: Category[]): TripStats {
  const catById = new Map(cats.map((c) => [c.id, c]));
  const catOf = (t: Transaction) => {
    if (t.kind === 'IOF_REFUND') return IOF_CAT;
    if (!t.categoryId) return NO_CAT;
    return catById.get(t.categoryId) ?? NO_CAT;
  };

  let gross = 0,
    refunds = 0,
    before = 0,
    during = 0,
    iofRefund = 0;
  const days = new Set<string>();

  const byCat = new Map<string, CatAgg>();
  const dayMap = new Map<string, Record<string, number>>(); // date -> {catName: amount}
  const usedCat = new Map<string, string>(); // catName -> color
  const bdMap = new Map<string, { antes: number; durante: number }>();
  const cityMap = new Map<string, number>(); // city -> amount
  const dayCity = new Map<string, string>(); // date -> city

  for (const t of txs) {
    const c = cost(t);
    const cat = catOf(t);
    if (c >= 0) gross += c;
    else refunds += c;
    if (t.period === 'BEFORE') before += c;
    else during += c;
    if (t.kind === 'IOF_REFUND') iofRefund += c;
    if (t.period === 'DURING' && t.date) {
      days.add(t.date);
      if (t.city) dayCity.set(t.date, t.city);
    }

    // Only expenses (positive) feed the category/city breakdowns.
    if (c > 0) {
      const key = t.categoryId ?? cat.name;
      const agg = byCat.get(key) ?? {
        id: t.categoryId ?? null,
        name: cat.name,
        color: cat.color,
        amount: 0,
      };
      agg.amount += c;
      byCat.set(key, agg);
      usedCat.set(cat.name, cat.color);

      if (t.period === 'DURING' && t.date) {
        const dm = dayMap.get(t.date) ?? {};
        dm[cat.name] = (dm[cat.name] ?? 0) + c;
        dayMap.set(t.date, dm);
      }

      const bd = bdMap.get(cat.name) ?? { antes: 0, durante: 0 };
      if (t.period === 'BEFORE') bd.antes += c;
      else bd.durante += c;
      bdMap.set(cat.name, bd);

      if (t.city) cityMap.set(t.city, (cityMap.get(t.city) ?? 0) + c);
    }
  }

  const byCategory = [...byCat.values()].sort((a, b) => b.amount - a.amount);
  const usedCategories = byCategory.map((c) => ({ name: c.name, color: c.color }));

  const dayData = [...dayMap.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([date, perCat]) => {
      const [, m, d] = date.split('-');
      return { date: `${d}/${m}`, ...round2(perCat) };
    });

  const beforeDuringData = [...bdMap.entries()]
    .map(([category, v]) => ({
      category,
      antes: round(v.antes),
      durante: round(v.durante),
    }))
    .filter((r) => r.antes || r.durante)
    .sort((a, b) => b.antes + b.durante - (a.antes + a.durante));

  const byCity = [...cityMap.entries()]
    .sort(([, a], [, b]) => b - a)
    .map(([city, amount], i) => ({
      city,
      amount: round(amount),
      color: CITY_PALETTE[i % CITY_PALETTE.length],
    }));

  const daysByCity = [...dayCity.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([date, city]) => ({ date, city }));

  const nDays = days.size;
  return {
    gross: round(gross),
    refunds: round(refunds),
    net: round(gross + refunds),
    before: round(before),
    during: round(during),
    iofRefund: round(iofRefund),
    days: nDays,
    avgPerDay: nDays ? round(during / nDays) : 0,
    byCategory: byCategory.map((c) => ({ ...c, amount: round(c.amount) })),
    usedCategories,
    dayData,
    beforeDuringData,
    byCity,
    daysByCity,
  };
}

const round = (n: number) => Math.round(n * 100) / 100;
function round2(o: Record<string, number>): Record<string, number> {
  const out: Record<string, number> = {};
  for (const k in o) out[k] = round(o[k]);
  return out;
}
