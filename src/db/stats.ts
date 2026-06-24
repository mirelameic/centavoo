import type { Category, CityMap, Transaction } from './schema';

// Effective cost of a transaction: applies the split (e.g. a shared Airbnb).
// `amount` always holds the full (integral) value; this divides it by splitCount.
export const cost = (t: Transaction) => t.amount / (t.splitCount || 1);

// Palette used to color cities in the "by city" chart.
const CITY_PALETTE = [
  '#4263EB', '#0CA678', '#F08C00', '#E64980', '#7048E8',
  '#1098AD', '#F03E3E', '#66A80F', '#AE3EC9', '#1864AB',
];

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
  beforeDuringData: { category: string; before: number; during: number }[];
  byCity: { city: string; amount: number; color: string }[]; // expenses by city
  weekdayAmounts: number[]; // length 7, gross expense by weekday (index 0 = Sunday)
  cityTable: CityRow[];
  categoryTable: {
    name: string;
    color: string;
    total: number;
    pct: number;
    count: number;
    avgTicket: number;
  }[];
  split: { integral: number; share: number; savings: number }; // splitting savings
}

interface CityRow {
  city: string;
  days: number;
  total: number;
  avgPerDay: number;
  topCategory: string;
}

const NO_CAT = { name: 'No category', color: '#adb5bd' };
const IOF_CAT = { name: 'IOF refund', color: '#868e96' };

export function computeStats(
  txs: Transaction[],
  cats: Category[],
  cities: CityMap = {},
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
  const bdMap = new Map<string, { before: number; during: number }>();
  const cityMap = new Map<string, number>(); // city -> amount
  const weekday = [0, 0, 0, 0, 0, 0, 0]; // index 0 = Sunday
  const catCount = new Map<string, number>(); // byCat key -> transaction count
  const cityDays = new Map<string, Set<string>>(); // city -> set of dates
  const cityCat = new Map<string, Map<string, number>>(); // city -> { catName: amount }
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
      }

      const bd = bdMap.get(cat.name) ?? { before: 0, during: 0 };
      if (t.period === 'BEFORE') bd.before += c;
      else bd.during += c;
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
      return { date: `${d}/${m}`, ...roundValues(perCat) };
    });

  const beforeDuringData = [...bdMap.entries()]
    .map(([category, v]) => ({
      category,
      before: round(v.before),
      during: round(v.during),
    }))
    .filter((r) => r.before || r.during)
    .sort((a, b) => b.before + b.during - (a.before + a.during));

  const byCity = paletteByCity(cityMap);
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

  const cityTable = buildCityTable(byCity, cityDays, cityCat);

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
    split,
  };
}

// Expenses by city, optionally restricted to a set of category ids. Used by the
// "City summary" so the user can ask "how much per city, only on food/shopping".
export function cityBreakdown(
  txs: Transaction[],
  cats: Category[],
  cities: CityMap,
  allowed?: Set<string>,
) {
  const catById = new Map(cats.map((c) => [c.id, c]));
  const cityMap = new Map<string, number>();
  const cityDays = new Map<string, Set<string>>();
  const cityCat = new Map<string, Map<string, number>>();
  for (const t of txs) {
    const c = cost(t);
    if (c <= 0) continue;
    if (allowed && (!t.categoryId || !allowed.has(t.categoryId))) continue;
    const cy = (t.date ? cities[t.date] : undefined) || undefined;
    if (!cy) continue;
    cityMap.set(cy, (cityMap.get(cy) ?? 0) + c);
    if (t.date) {
      let s = cityDays.get(cy);
      if (!s) cityDays.set(cy, (s = new Set()));
      s.add(t.date);
    }
    const cn = (t.categoryId && catById.get(t.categoryId)?.name) || '—';
    let cc = cityCat.get(cy);
    if (!cc) cityCat.set(cy, (cc = new Map()));
    cc.set(cn, (cc.get(cn) ?? 0) + c);
  }
  const byCity = paletteByCity(cityMap);
  return { byCity, cityTable: buildCityTable(byCity, cityDays, cityCat) };
}

// City totals sorted desc, each assigned a stable palette color by rank.
function paletteByCity(cityMap: Map<string, number>) {
  return [...cityMap.entries()]
    .sort(([, a], [, b]) => b - a)
    .map(([city, amount], i) => ({
      city,
      amount: round(amount),
      color: CITY_PALETTE[i % CITY_PALETTE.length],
    }));
}

function buildCityTable(
  byCity: { city: string; amount: number }[],
  cityDays: Map<string, Set<string>>,
  cityCat: Map<string, Map<string, number>>,
): CityRow[] {
  return byCity.map((cc) => {
    const days = cityDays.get(cc.city)?.size ?? 0;
    const cm = cityCat.get(cc.city);
    const topCategory =
      cm && cm.size ? [...cm.entries()].sort(([, a], [, b]) => b - a)[0][0] : '—';
    return {
      city: cc.city,
      days,
      total: cc.amount,
      avgPerDay: days ? round(cc.amount / days) : cc.amount,
      topCategory,
    };
  });
}

const round = (n: number) => Math.round(n * 100) / 100;
function roundValues(o: Record<string, number>): Record<string, number> {
  const out: Record<string, number> = {};
  for (const k in o) out[k] = round(o[k]);
  return out;
}
