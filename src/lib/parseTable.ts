// Deterministic, format-agnostic parsing for pasted/uploaded transaction tables
// (bank or card statement exports). No column layout is assumed — the caller
// always confirms which column is which before anything is imported, so a
// bad guess here only affects a convenience default, never the actual import.

export type ColumnRole = 'date' | 'description' | 'amount' | 'ignore';
export type DelimiterOption = 'auto' | ',' | ';' | '\t';

// Splits one line on `delimiter`, honoring simple double-quoted fields
// ("a, b" stays one field; "" inside quotes is an escaped quote).
function splitLine(line: string, delimiter: string): string[] {
  const out: string[] = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (inQuotes) {
      if (c === '"') {
        if (line[i + 1] === '"') { cur += '"'; i++; } else inQuotes = false;
      } else {
        cur += c;
      }
    } else if (c === '"') {
      inQuotes = true;
    } else if (c === delimiter) {
      out.push(cur.trim());
      cur = '';
    } else {
      cur += c;
    }
  }
  out.push(cur.trim());
  return out;
}

// How many lines share the most common column count for this delimiter.
function mostCommonCount(counts: number[]): number {
  const tally = new Map<number, number>();
  for (const n of counts) tally.set(n, (tally.get(n) ?? 0) + 1);
  return Math.max(...tally.values());
}

// Picks whichever of tab / semicolon / comma splits the most lines into the
// same (>1) number of columns. Falls back to comma when nothing lines up.
function detectDelimiter(lines: string[]): string {
  let best = ',';
  let bestScore = -1;
  for (const candidate of ['\t', ';', ',']) {
    const counts = lines.map((l) => splitLine(l, candidate).length);
    if (Math.max(...counts) < 2) continue;
    const score = mostCommonCount(counts);
    if (score > bestScore) { bestScore = score; best = candidate; }
  }
  return best;
}

// Parses pasted or file text into a rectangular grid of cells. Blank lines are
// dropped; short rows are padded so every row has the same column count.
export function splitRows(text: string, delimiter: DelimiterOption = 'auto'): string[][] {
  const lines = text
    .replace(/\r\n?/g, '\n')
    .split('\n')
    .filter((l) => l.trim().length > 0);
  if (!lines.length) return [];

  const delim = delimiter === 'auto' ? detectDelimiter(lines) : delimiter;
  const rows = lines.map((l) => splitLine(l, delim));
  const width = Math.max(...rows.map((r) => r.length));
  return rows.map((r) => (r.length < width ? [...r, ...Array(width - r.length).fill('')] : r));
}

// Parses an amount written in any common style: "1.234,56", "1,234.56",
// "R$ 45,90", "(30,00)" (parentheses = negative), "-12.5". Returns null
// (never throws) when the text isn't a recognizable number.
export function parseAmount(raw: string): number | null {
  if (raw == null) return null;
  let s = String(raw).trim();
  if (!s) return null;

  let negative = false;
  if (/^\(.*\)$/.test(s)) { negative = true; s = s.slice(1, -1); }
  s = s.replace(/[^0-9.,-]/g, '');
  if (s.startsWith('-')) { negative = true; s = s.slice(1); }
  if (s.endsWith('-')) { negative = true; s = s.slice(0, -1); }
  s = s.replace(/-/g, '');
  if (!s) return null;

  const lastComma = s.lastIndexOf(',');
  const lastDot = s.lastIndexOf('.');
  let normalized: string;

  if (lastComma !== -1 && lastDot !== -1) {
    // Whichever separator appears last is the decimal one; the other is thousands.
    normalized = lastComma > lastDot
      ? s.replace(/\./g, '').replace(',', '.')
      : s.replace(/,/g, '');
  } else if (lastComma !== -1) {
    const decimals = s.length - lastComma - 1;
    const isDecimal = decimals === 2 && (s.match(/,/g) ?? []).length === 1;
    normalized = isDecimal ? s.replace(',', '.') : s.replace(/,/g, '');
  } else if (lastDot !== -1) {
    const decimals = s.length - lastDot - 1;
    const dotCount = (s.match(/\./g) ?? []).length;
    normalized = dotCount > 1 || decimals === 3 ? s.replace(/\./g, '') : s;
  } else {
    normalized = s;
  }

  const n = Number(normalized);
  if (!Number.isFinite(n)) return null;
  return negative ? -n : n;
}

function toISODate(year: number, month: number, day: number): string | null {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${year}-${pad(month)}-${pad(day)}`;
}

// Parses a date in ISO ('YYYY-MM-DD') or day-first ('DD/MM/YYYY', 'DD-MM-YY',
// 'DD.MM.YYYY') form — day-first is the deterministic choice for the ambiguous
// case, matching the app's pt-BR date convention. Returns null when unrecognized.
export function parseDate(raw: string): string | null {
  if (raw == null) return null;
  const s = String(raw).trim();
  if (!s) return null;

  let m = s.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})/);
  if (m) return toISODate(+m[1], +m[2], +m[3]);

  m = s.match(/^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})/);
  if (m) {
    const year = +m[3] < 100 ? 2000 + +m[3] : +m[3];
    return toISODate(year, +m[2], +m[1]);
  }
  return null;
}

// Best-effort default mapping, shown to the user for confirmation/editing —
// never used to import anything by itself.
export function guessRoles(rows: string[][]): ColumnRole[] {
  const width = rows[0]?.length ?? 0;
  const roles: ColumnRole[] = Array(width).fill('ignore');

  const scoreCol = (col: number, test: (v: string) => boolean) =>
    rows.reduce((n, r) => n + (test(r[col]) ? 1 : 0), 0);

  let dateCol = -1, dateScore = 0;
  for (let c = 0; c < width; c++) {
    const s = scoreCol(c, (v) => parseDate(v) !== null);
    if (s > dateScore) { dateScore = s; dateCol = c; }
  }
  if (dateCol >= 0 && dateScore > 0) roles[dateCol] = 'date';

  let amountCol = -1, amountScore = 0;
  for (let c = 0; c < width; c++) {
    if (c === dateCol) continue;
    const s = scoreCol(c, (v) => /\d/.test(v) && parseAmount(v) !== null);
    if (s > amountScore) { amountScore = s; amountCol = c; }
  }
  if (amountCol >= 0 && amountScore > 0) roles[amountCol] = 'amount';

  const descCol = roles.findIndex((r) => r === 'ignore');
  if (descCol >= 0) roles[descCol] = 'description';

  return roles;
}

// True when the first row looks like labels rather than data — i.e. its
// mapped date/amount cells don't parse but at least one later row's does.
export function looksLikeHeaderRow(rows: string[][], roles: ColumnRole[]): boolean {
  if (rows.length < 2) return false;
  const checkCols = roles
    .map((role, i) => ({ role, i }))
    .filter((c) => c.role === 'date' || c.role === 'amount');
  if (!checkCols.length) return false;

  const rowParses = (r: string[]) =>
    checkCols.some(({ role, i }) => (role === 'date' ? parseDate(r[i]) : parseAmount(r[i])) !== null);

  return !rowParses(rows[0]) && rows.slice(1).some(rowParses);
}
