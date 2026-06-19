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

// ---- basic CRUD --------------------------------------------------------------
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

export async function addTransaction(
  t: Omit<Transaction, 'id' | 'createdAt'>,
): Promise<string> {
  const id = `tx_${crypto.randomUUID()}`;
  await db.transactions.add({ ...t, id, createdAt: new Date().toISOString() });
  return id;
}

export const tripTransactions = (tripId: string) =>
  db.transactions.where('tripId').equals(tripId).toArray();

// Set the city of a day. Stored on the trip (a day = a city), so it persists
// even for days without transactions and even when cleared to empty.
export async function setTripCity(tripId: string, date: string, city: string) {
  const trip = await db.trips.get(tripId);
  if (!trip) return;
  const cities = { ...(trip.cities ?? {}) };
  const v = city.trim();
  if (v) cities[date] = v;
  else delete cities[date];
  await db.trips.update(tripId, { cities });
}

export const updateTransaction = (id: string, patch: Partial<Transaction>) =>
  db.transactions.update(id, patch);

export const deleteTransaction = (id: string) => db.transactions.delete(id);

export const deleteTransactions = (ids: string[]) => db.transactions.bulkDelete(ids);

// ---- categories CRUD ---------------------------------------------------------
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
  weekdayAmounts: number[]; // length 7, gross expense by weekday (index 0 = Sunday)
  cityTable: {
    city: string;
    days: number;
    total: number;
    avgPerDay: number;
    topCategory: string;
  }[];
  categoryTable: {
    name: string;
    color: string;
    total: number;
    pct: number;
    count: number;
    avgTicket: number;
  }[];
  calendar: { date: string; amount: number }[]; // each day in the trip span, gross expense
  maxDaily: number; // largest single-day gross (for the heatmap color scale)
  split: { integral: number; share: number; savings: number }; // splitting savings
}

const NO_CAT = { name: 'No category', color: '#adb5bd' };
const IOF_CAT = { name: 'IOF refund', color: '#868e96' };

export function computeStats(
  txs: Transaction[],
  cats: Category[],
  cities: Record<string, string> = {},
): TripStats {
  const catById = new Map(cats.map((c) => [c.id, c]));
  const catOf = (t: Transaction) => {
    if (t.kind === 'IOF_REFUND') return IOF_CAT;
    if (!t.categoryId) return NO_CAT;
    return catById.get(t.categoryId) ?? NO_CAT;
  };
  // City of a transaction is the city of its day (stored on the trip).
  const cityOf = (t: Transaction) => (t.date ? cities[t.date] : undefined) || undefined;

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
  const weekday = [0, 0, 0, 0, 0, 0, 0]; // index 0 = Sunday
  const catCount = new Map<string, number>(); // byCat key -> transaction count
  const cityDays = new Map<string, Set<string>>(); // city -> set of dates
  const cityCat = new Map<string, Map<string, number>>(); // city -> { catName: amount }
  const dateGross = new Map<string, number>(); // date -> gross expense
  let integralExp = 0; // sum of full (integral) amounts of expenses

  for (const t of txs) {
    const c = cost(t);
    const cat = catOf(t);
    if (c >= 0) gross += c;
    else refunds += c;
    if (t.period === 'BEFORE') before += c;
    else during += c;
    if (t.kind === 'IOF_REFUND') iofRefund += c;
    if (t.period === 'DURING' && t.date) days.add(t.date);

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
      catCount.set(key, (catCount.get(key) ?? 0) + 1);
      integralExp += t.amount; // full value (= amount; larger than `c` when split)

      if (t.period === 'DURING' && t.date) {
        const dm = dayMap.get(t.date) ?? {};
        dm[cat.name] = (dm[cat.name] ?? 0) + c;
        dayMap.set(t.date, dm);
        weekday[new Date(t.date + 'T00:00:00').getDay()] += c;
        dateGross.set(t.date, (dateGross.get(t.date) ?? 0) + c);
      }

      const bd = bdMap.get(cat.name) ?? { antes: 0, durante: 0 };
      if (t.period === 'BEFORE') bd.antes += c;
      else bd.durante += c;
      bdMap.set(cat.name, bd);

      const cy = cityOf(t);
      if (cy) {
        cityMap.set(cy, (cityMap.get(cy) ?? 0) + c);
        if (t.date) {
          let s = cityDays.get(cy);
          if (!s) cityDays.set(cy, (s = new Set()));
          s.add(t.date);
        }
        let cc = cityCat.get(cy);
        if (!cc) cityCat.set(cy, (cc = new Map()));
        cc.set(cat.name, (cc.get(cat.name) ?? 0) + c);
      }
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

  const weekdayAmounts = weekday.map((n) => round(n));

  const totalCat = byCategory.reduce((s, c) => s + c.amount, 0) || 1;
  const categoryTable = byCategory.map((c) => {
    const count = catCount.get(c.id ?? c.name) ?? 0;
    return {
      name: c.name,
      color: c.color,
      total: round(c.amount),
      pct: round((c.amount / totalCat) * 100),
      count,
      avgTicket: count ? round(c.amount / count) : 0,
    };
  });

  const cityTable = byCity.map((cc) => {
    const dys = cityDays.get(cc.city)?.size ?? 0;
    const cm = cityCat.get(cc.city);
    const topCategory =
      cm && cm.size ? [...cm.entries()].sort(([, a], [, b]) => b - a)[0][0] : '—';
    return {
      city: cc.city,
      days: dys,
      total: cc.amount,
      avgPerDay: dys ? round(cc.amount / dys) : cc.amount,
      topCategory,
    };
  });

  // Calendar: every day from the first to the last dated expense (0 when none).
  const calDates = [...dateGross.keys()].sort();
  const calendar: { date: string; amount: number }[] = [];
  let maxDaily = 0;
  if (calDates.length) {
    const p = (n: number) => String(n).padStart(2, '0');
    const end = new Date(calDates[calDates.length - 1] + 'T00:00:00');
    for (let d = new Date(calDates[0] + 'T00:00:00'); d <= end; d.setDate(d.getDate() + 1)) {
      const iso = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
      const amt = round(dateGross.get(iso) ?? 0);
      maxDaily = Math.max(maxDaily, amt);
      calendar.push({ date: iso, amount: amt });
    }
  }

  const split = {
    integral: round(integralExp),
    share: round(gross),
    savings: round(integralExp - gross),
  };

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
    weekdayAmounts,
    cityTable,
    categoryTable,
    calendar,
    maxDaily,
    split,
  };
}

const round = (n: number) => Math.round(n * 100) / 100;
function round2(o: Record<string, number>): Record<string, number> {
  const out: Record<string, number> = {};
  for (const k in o) out[k] = round(o[k]);
  return out;
}
