import type { Category, CityMap, Transaction } from './schema';

export const cost = (t: Transaction) => t.amount / (t.splitCount || 1);

export const CITY_PALETTE = [
  '#C2540D', '#0E8C6B', '#B8860B', '#B23368', '#7A4A2A',
  '#3D8B4C', '#C1352E', '#6B8A1E', '#7D1F44', '#5C5650',
];

export function colorForCity(name: string): string {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0;
  return CITY_PALETTE[h % CITY_PALETTE.length];
}

export interface CatAgg {
  id: string | null;
  name: string;
  color: string;
  icon?: string;
  amount: number;
}

export interface TripStats {
  gross: number;
  refunds: number;
  net: number;
  before: number;
  during: number;
  iofRefund: number;
  days: number;
  avgPerDay: number;
  byCategory: CatAgg[];
  usedCategories: { name: string; color: string }[];
  dayData: Record<string, number | string>[];
  beforeDuringData: { category: string; before: number; during: number }[];
  byCity: { city: string; amount: number; color: string }[];
  weekdayAmounts: number[];
  cityTable: CityRow[];
  categoryTable: {
    name: string;
    color: string;
    icon?: string;
    total: number;
    pct: number;
    count: number;
    avgTicket: number;
  }[];
  split: { integral: number; share: number; savings: number };
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
    if (t.isIof) return IOF_CAT;
    if (!t.categoryId) return NO_CAT;
    return catById.get(t.categoryId) ?? NO_CAT;
  };
  const cityOf = (t: Transaction) => (t.date ? cities[t.date] : undefined) || undefined;

  let gross = 0,
    refunds = 0,
    before = 0,
    during = 0,
    iofRefund = 0;
  const days = new Set<string>();

  const byCat = new Map<string, CatAgg>();
  const dayMap = new Map<string, Record<string, number>>();
  const bdMap = new Map<string, { before: number; during: number }>();
  const cityMap = new Map<string, number>();
  const weekday = [0, 0, 0, 0, 0, 0, 0];
  const catCount = new Map<string, number>();
  const cityDays = new Map<string, Set<string>>();
  const cityCat = new Map<string, Map<string, number>>();
  let integralExp = 0;

  for (const t of txs) {
    const c = cost(t);
    const cat = catOf(t);
    if (c >= 0) gross += c;
    else refunds += c;
    if (t.period === 'BEFORE') before += c;
    else during += c;
    if (t.isIof) iofRefund += c;
    if (t.period === 'DURING' && t.date) days.add(t.date);

    if (c > 0) {
      const key = t.categoryId ?? cat.name;
      const agg = byCat.get(key) ?? {
        id: t.categoryId ?? null,
        name: cat.name,
        color: cat.color,
        icon: (cat as { icon?: string }).icon,
        amount: 0,
      };
      agg.amount += c;
      byCat.set(key, agg);
      catCount.set(key, (catCount.get(key) ?? 0) + 1);
      integralExp += t.amount;

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
      icon: c.icon,
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

function paletteByCity(cityMap: Map<string, number>) {
  return [...cityMap.entries()]
    .sort(([, a], [, b]) => b - a)
    .map(([city, amount]) => ({
      city,
      amount: round(amount),
      color: colorForCity(city),
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
