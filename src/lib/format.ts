// Formatting and date helpers. Locale defaults to pt-BR but can be overridden —
// the i18n layer passes the locale that matches the current language.

const pad2 = (n: number) => String(n).padStart(2, '0');

// Splits a formatted currency amount into its symbol ('R$', or '-R$' when
// negative) and its number ('3.709,80'), so callers can lay them out as
// separate, independently-aligned pieces (e.g. a right-aligned amount column
// with the symbol pinned to its own column). Also used by `money` below to
// guarantee one consistent space between symbol and number in every locale —
// en-US's own currency formatting omits it ('R$3,709.80'), pt-BR's doesn't.
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

// Normalizes a value to a local 'YYYY-MM-DD' string. Accepts the strings or Date
// objects that Mantine's date inputs may yield across versions. Uses local date
// parts (not toISOString, which would shift across the UTC boundary).
export function toISO(d: unknown): string | null {
  if (!d) return null;
  if (typeof d === 'string') return d.slice(0, 10);
  if (d instanceof Date) return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
  return null;
}

// Inclusive list of 'YYYY-MM-DD' dates between start and end.
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

// Groups a day -> city map into contiguous date ranges per city, for display
// (e.g. "Barcelona, 18–19 mai" instead of one row per day). Purely a read of
// `cities` — never mutates it, so it's safe to recompute on every render.
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
