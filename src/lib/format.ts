// Formatting and date helpers. Locale defaults to pt-BR but can be overridden —
// the i18n layer passes the locale that matches the current language.

const pad2 = (n: number) => String(n).padStart(2, '0');

export function money(n: number, currency = 'BRL', locale = 'pt-BR'): string {
  return n.toLocaleString(locale, { style: 'currency', currency });
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
