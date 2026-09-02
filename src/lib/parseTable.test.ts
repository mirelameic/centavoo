import { describe, it, expect } from 'vitest';
import { splitRows, parseAmount, parseDate, guessRoles, looksLikeHeaderRow } from './parseTable';

describe('splitRows', () => {
  it('auto-detects tab-separated pasted text', () => {
    expect(splitRows('12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00')).toEqual([
      ['12/03/2026', 'Uber', '45,90'],
      ['13/03/2026', 'Padaria', '12,00'],
    ]);
  });

  it('auto-detects semicolon-separated CSV', () => {
    expect(splitRows('data;descricao;valor\n01/01/2026;Taxi;10,00')).toEqual([
      ['data', 'descricao', 'valor'],
      ['01/01/2026', 'Taxi', '10,00'],
    ]);
  });

  it('respects an explicit delimiter override', () => {
    expect(splitRows('a,b,c', ';')).toEqual([['a,b,c']]);
  });

  it('keeps commas inside quoted fields intact', () => {
    expect(splitRows('01/01/2026,"Uber, viagem",10,00', ',')).toEqual([
      ['01/01/2026', 'Uber, viagem', '10', '00'],
    ]);
  });

  it('drops blank lines and pads short rows', () => {
    expect(splitRows('a,b,c\n\nd,e')).toEqual([
      ['a', 'b', 'c'],
      ['d', 'e', ''],
    ]);
  });

  it('returns an empty array for empty input instead of throwing', () => {
    expect(splitRows('   \n  ')).toEqual([]);
  });
});

describe('parseAmount', () => {
  it('parses plain decimals', () => expect(parseAmount('45.90')).toBe(45.9));
  it('parses BR-style comma decimals', () => expect(parseAmount('45,90')).toBe(45.9));
  it('parses BR-style thousands + decimal', () => expect(parseAmount('1.234,56')).toBe(1234.56));
  it('parses US-style thousands + decimal', () => expect(parseAmount('1,234.56')).toBe(1234.56));
  it('parses a currency-prefixed value', () => expect(parseAmount('R$ 45,90')).toBe(45.9));
  it('treats parentheses as negative', () => expect(parseAmount('(30,00)')).toBe(-30));
  it('parses a leading minus sign', () => expect(parseAmount('-12.50')).toBe(-12.5));
  it('parses a trailing minus sign', () => expect(parseAmount('12,50-')).toBe(-12.5));
  it('treats a lone 3-digit-group comma as thousands, not decimals', () =>
    expect(parseAmount('1,234')).toBe(1234));
  it('treats a lone 3-digit-group dot as thousands, not decimals', () =>
    expect(parseAmount('1.234')).toBe(1234));
  it('returns null for empty or non-numeric text', () => {
    expect(parseAmount('')).toBeNull();
    expect(parseAmount('abc')).toBeNull();
  });
});

describe('parseDate', () => {
  it('parses ISO dates', () => expect(parseDate('2026-03-12')).toBe('2026-03-12'));
  it('parses day-first slash dates', () => expect(parseDate('12/03/2026')).toBe('2026-03-12'));
  it('parses day-first dot dates', () => expect(parseDate('12.03.2026')).toBe('2026-03-12'));
  it('expands a 2-digit year', () => expect(parseDate('12/03/26')).toBe('2026-03-12'));
  it('returns null for an invalid month/day', () => expect(parseDate('32/13/2026')).toBeNull());
  it('returns null for unrecognized text', () => expect(parseDate('yesterday')).toBeNull());
});

describe('guessRoles', () => {
  it('identifies date, amount and description columns', () => {
    const rows = [
      ['12/03/2026', 'Uber', '45,90'],
      ['13/03/2026', 'Padaria', '12,00'],
    ];
    expect(guessRoles(rows)).toEqual(['date', 'description', 'amount']);
  });
});

describe('looksLikeHeaderRow', () => {
  it('detects a header row when it does not parse but later rows do', () => {
    const rows = [
      ['data', 'descricao', 'valor'],
      ['12/03/2026', 'Uber', '45,90'],
    ];
    expect(looksLikeHeaderRow(rows, ['date', 'description', 'amount'])).toBe(true);
  });

  it('returns false when the first row already parses as data', () => {
    const rows = [
      ['12/03/2026', 'Uber', '45,90'],
      ['13/03/2026', 'Padaria', '12,00'],
    ];
    expect(looksLikeHeaderRow(rows, ['date', 'description', 'amount'])).toBe(false);
  });
});
