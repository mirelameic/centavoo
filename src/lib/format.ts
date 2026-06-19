// Formatting helpers (currency and dates). Locale defaults to pt-BR but can be
// overridden — the i18n layer passes the locale that matches the current language.

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

export function dayMonth(d?: string | null): string {
  if (!d) return '—';
  const [, m, day] = d.split('-');
  return `${day}/${m}`;
}

// Inclusive number of days between two 'YYYY-MM-DD' dates.
export function daysBetween(start?: string | null, end?: string | null): number {
  if (!start || !end) return 0;
  const a = new Date(start + 'T00:00:00').getTime();
  const b = new Date(end + 'T00:00:00').getTime();
  return Math.round((b - a) / 86_400_000) + 1;
}
