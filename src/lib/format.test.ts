import { describe, it, expect } from 'vitest';
import { groupCityBlocks, money, moneyParts } from './format';

describe('money', () => {
  it('always puts one space between symbol and number in pt-BR', () => {
    expect(money(3709.8, 'BRL', 'pt-BR')).toBe('R$ 3.709,80');
  });

  it('always puts one space between symbol and number in en-US — the locale default has none', () => {
    expect(money(3709.8, 'BRL', 'en-US')).toBe('R$ 3,709.80');
  });

  it('keeps the minus sign attached to the symbol, not the number', () => {
    expect(money(-30, 'BRL', 'pt-BR')).toBe('-R$ 30,00');
    expect(money(-30, 'BRL', 'en-US')).toBe('-R$ 30.00');
  });
});

describe('moneyParts', () => {
  it('splits the symbol from the number', () => {
    expect(moneyParts(3709.8, 'BRL', 'pt-BR')).toEqual({ symbol: 'R$', value: '3.709,80' });
  });

  it('folds a negative sign into the symbol', () => {
    expect(moneyParts(-30, 'BRL', 'pt-BR')).toEqual({ symbol: '-R$', value: '30,00' });
  });
});

describe('groupCityBlocks', () => {
  it('returns nothing for an empty map', () => {
    expect(groupCityBlocks(['2026-05-17', '2026-05-18'], {})).toEqual([]);
  });

  it('skips days with no city assigned', () => {
    const days = ['2026-05-17', '2026-05-18', '2026-05-19'];
    const cities = { '2026-05-18': 'Barcelona' };
    expect(groupCityBlocks(days, cities)).toEqual([
      { city: 'Barcelona', start: '2026-05-18', end: '2026-05-18', days: ['2026-05-18'] },
    ]);
  });

  it('merges consecutive days with the same city into one block', () => {
    const days = ['2026-05-17', '2026-05-18', '2026-05-19'];
    const cities = {
      '2026-05-17': 'Barcelona',
      '2026-05-18': 'Barcelona',
      '2026-05-19': 'Barcelona',
    };
    expect(groupCityBlocks(days, cities)).toEqual([
      {
        city: 'Barcelona',
        start: '2026-05-17',
        end: '2026-05-19',
        days: ['2026-05-17', '2026-05-18', '2026-05-19'],
      },
    ]);
  });

  it('splits into separate blocks when the city changes', () => {
    const days = ['2026-05-17', '2026-05-18', '2026-05-19'];
    const cities = {
      '2026-05-17': 'Barcelona',
      '2026-05-18': 'Atenas',
      '2026-05-19': 'Atenas',
    };
    expect(groupCityBlocks(days, cities)).toEqual([
      { city: 'Barcelona', start: '2026-05-17', end: '2026-05-17', days: ['2026-05-17'] },
      {
        city: 'Atenas',
        start: '2026-05-18',
        end: '2026-05-19',
        days: ['2026-05-18', '2026-05-19'],
      },
    ]);
  });

  it('splits into separate blocks when the same city repeats after a gap', () => {
    const days = ['2026-05-17', '2026-05-18', '2026-05-20'];
    const cities = {
      '2026-05-17': 'Barcelona',
      '2026-05-18': 'Barcelona',
      '2026-05-20': 'Barcelona',
    };
    expect(groupCityBlocks(days, cities)).toEqual([
      {
        city: 'Barcelona',
        start: '2026-05-17',
        end: '2026-05-18',
        days: ['2026-05-17', '2026-05-18'],
      },
      { city: 'Barcelona', start: '2026-05-20', end: '2026-05-20', days: ['2026-05-20'] },
    ]);
  });

  it('is a pure read: never mutates the input map', () => {
    const cities = { '2026-05-17': 'Barcelona' };
    const snapshot = { ...cities };
    groupCityBlocks(['2026-05-17'], cities);
    expect(cities).toEqual(snapshot);
  });
});
