import type { Period } from '../db/schema';

const pad2 = (n: number) => String(n).padStart(2, '0');

export function moneyParts(n: number, currency = 'BRL', locale = 'pt-BR'): { symbol: string; value: string } {
  const parts = new Intl.NumberFormat(locale, { style: 'currency', currency }).formatToParts(n);
  let symbol = '';
  let value = '';
  for (const p of parts) {
    if (p.type === 'currency' || p.type === 'minusSign' || p.type === 'plusSign') symbol += p.value;
    else if (p.type !== 'literal') value += p.value;
  }
  return { symbol, value };
}

export function money(n: number, currency = 'BRL', locale = 'pt-BR'): string {
  const { symbol, value } = moneyParts(n, currency, locale);
  return `${symbol} ${value}`;
}

export function fmtDate(d?: string | null, locale = 'pt-BR'): string {
  if (!d) return '—';
  return new Date(d + 'T00:00:00').toLocaleDateString(locale, {
    day: '2-digit',
    month: 'short',
  });
}

export function toISO(d: unknown): string | null {
  if (!d) return null;
  if (typeof d === 'string') return d.slice(0, 10);
  if (d instanceof Date) return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
  return null;
}

export function periodForDate(
  date?: string | null,
  tripStartDate?: string | null,
): Period | null {
  if (!date || !tripStartDate) return null;
  return date < tripStartDate ? 'BEFORE' : 'DURING';
}

export function dateRange(start: string, end: string): string[] {
  const out: string[] = [];
  const e = new Date(end + 'T00:00:00');
  for (let d = new Date(start + 'T00:00:00'); d <= e; d.setDate(d.getDate() + 1)) {
    out.push(`${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`);
  }
  return out;
}

function isNextDay(a: string, b: string): boolean {
  const d = new Date(a + 'T00:00:00');
  d.setDate(d.getDate() + 1);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}` === b;
}

export interface CityBlock {
  city: string;
  start: string;
  end: string;
  days: string[];
}

export function groupCityBlocks(
  days: string[],
  cities: Record<string, string | null | undefined>,
): CityBlock[] {
  const blocks: CityBlock[] = [];
  for (const d of days) {
    const city = cities[d];
    if (!city) continue;
    const last = blocks[blocks.length - 1];
    if (last && last.city === city && isNextDay(last.end, d)) {
      last.end = d;
      last.days.push(d);
    } else {
      blocks.push({ city, start: d, end: d, days: [d] });
    }
  }
  return blocks;
}
