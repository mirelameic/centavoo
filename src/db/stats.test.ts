import { describe, it, expect } from 'vitest';
import { cost, computeStats, cityBreakdown } from './stats';
import type { Category, CityMap, Transaction } from './schema';

// --- builders (keep each test to just the fields that matter) ----------------
function tx(p: Partial<Transaction> = {}): Transaction {
  return {
    id: 'tx',
    tripId: 't1',
    period: 'DURING',
    date: null,
    description: '',
    amount: 0,
    categoryId: null,
    kind: 'EXPENSE',
    isIof: false,
    splitCount: 1,
    city: null,
    createdAt: '2026-01-01T00:00:00Z',
    ...p,
  };
}
function cat(id: string, name: string, color = '#000'): Category {
  return { id, tripId: 't1', name, color, sortOrder: 0 };
}

describe('cost', () => {
  it('returns the full amount when not split', () => {
    expect(cost(tx({ amount: 100 }))).toBe(100);
  });
  it('divides by splitCount', () => {
    expect(cost(tx({ amount: 100, splitCount: 4 }))).toBe(25);
  });
  it('treats splitCount 0 as 1', () => {
    expect(cost(tx({ amount: 100, splitCount: 0 }))).toBe(100);
  });
});

describe('computeStats — totals', () => {
  const s = computeStats([
    tx({ amount: 100, period: 'DURING' }),
    tx({ amount: 50, period: 'BEFORE' }),
    tx({ amount: -30, kind: 'REFUND', period: 'DURING' }),
    tx({ amount: -10, kind: 'IOF_REFUND', isIof: true, period: 'DURING' }),
  ], []);

  it('sums gross from positive costs only', () => expect(s.gross).toBe(150));
  it('sums refunds from negative costs', () => expect(s.refunds).toBe(-40));
  it('net = gross + refunds', () => expect(s.net).toBe(110));
  it('splits before/during by period', () => {
    expect(s.before).toBe(50);
    expect(s.during).toBe(60); // 100 - 30 - 10
  });
  it('sums IOF refunds separately', () => expect(s.iofRefund).toBe(-10));
  it('keeps refunds (incl. IOF) out of the category breakdown', () => {
    expect(s.byCategory).toHaveLength(1);
    expect(s.byCategory[0]).toMatchObject({ name: 'No category', amount: 150 });
  });
});

describe('computeStats — categories', () => {
  it('aggregates by categoryId, sorted desc, with table metrics', () => {
    const cats = [cat('c1', 'Food'), cat('c2', 'Transport')];
    const s = computeStats([
      tx({ amount: 100, categoryId: 'c1' }),
      tx({ amount: 40, categoryId: 'c1' }),
      tx({ amount: 60, categoryId: 'c2' }),
    ], cats);

    expect(s.byCategory.map((c) => [c.name, c.amount])).toEqual([
      ['Food', 140],
      ['Transport', 60],
    ]);
    expect(s.categoryTable.find((c) => c.name === 'Food')).toMatchObject({
      total: 140, count: 2, avgTicket: 70, pct: 70,
    });
    expect(s.categoryTable.find((c) => c.name === 'Transport')).toMatchObject({
      total: 60, count: 1, avgTicket: 60, pct: 30,
    });
  });

  it('labels a missing categoryId as "No category"', () => {
    const s = computeStats([tx({ amount: 20, categoryId: null })], []);
    expect(s.byCategory[0]).toMatchObject({ name: 'No category', amount: 20 });
  });

  it('labels an unknown categoryId as "No category"', () => {
    const s = computeStats([tx({ amount: 10, categoryId: 'ghost' })], []);
    expect(s.byCategory[0].name).toBe('No category');
  });
});

describe('computeStats — split savings', () => {
  it('charges only the share but records the full value and the savings', () => {
    const s = computeStats([tx({ amount: 100, splitCount: 2 })], []);
    expect(s.gross).toBe(50);
    expect(s.net).toBe(50);
    expect(s.split).toEqual({ integral: 100, share: 50, savings: 50 });
  });
});

describe('computeStats — before × during by category', () => {
  it('reports each category split, drops empties, sorts desc', () => {
    const cats = [cat('c1', 'Food'), cat('c2', 'Transport')];
    const s = computeStats([
      tx({ amount: 100, categoryId: 'c1', period: 'BEFORE' }),
      tx({ amount: 30, categoryId: 'c1', period: 'DURING' }),
      tx({ amount: 20, categoryId: 'c2', period: 'DURING' }),
    ], cats);

    expect(s.beforeDuringData).toEqual([
      { category: 'Food', before: 100, during: 30 },
      { category: 'Transport', before: 0, during: 20 },
    ]);
  });
});

describe('computeStats — days, weekday and daily series', () => {
  // 2026-06-21 = Sunday (getDay 0), 2026-06-22 = Monday (1), 2026-06-23 = Tuesday.
  const s = computeStats([
    tx({ amount: 100, date: '2026-06-21' }),
    tx({ amount: 50, date: '2026-06-22' }),
    tx({ amount: -30, kind: 'REFUND', date: '2026-06-22' }),
    tx({ amount: -10, kind: 'REFUND', date: '2026-06-23' }),
  ], []);

  it('counts distinct during-dated days (refund days included)', () => {
    expect(s.days).toBe(3);
  });
  it('avgPerDay = during net / days', () => {
    expect(s.avgPerDay).toBe(36.67); // (100 + 50 - 30 - 10) / 3
  });
  it('buckets expenses by weekday (Sunday = index 0)', () => {
    expect(s.weekdayAmounts[0]).toBe(100);
    expect(s.weekdayAmounts[1]).toBe(50);
    expect(s.weekdayAmounts.reduce((a, b) => a + b, 0)).toBe(150);
  });
  it('builds the daily series only from dated expenses, ascending', () => {
    expect(s.dayData.map((d) => d.date)).toEqual(['21/06', '22/06']);
    expect(s.dayData[0]).toMatchObject({ date: '21/06', 'No category': 100 });
  });
});

describe('computeStats — by city', () => {
  const cities = { '2026-06-21': 'Paris', '2026-06-22': 'Lyon', '2026-06-23': 'Paris' };
  const s = computeStats([
    tx({ amount: 100, categoryId: 'c1', date: '2026-06-21' }),
    tx({ amount: 50, categoryId: 'c1', date: '2026-06-23' }),
    tx({ amount: 80, categoryId: 'c1', date: '2026-06-22' }),
    tx({ amount: 40, categoryId: 'c1', date: '2026-06-24' }), // no city mapping
  ], [cat('c1', 'Food')], cities);

  it('totals by city (desc) with palette colors by rank', () => {
    expect(s.byCity).toEqual([
      { city: 'Paris', amount: 150, color: '#4263EB' },
      { city: 'Lyon', amount: 80, color: '#0CA678' },
    ]);
  });
  it('builds the city table with days, avg and top category', () => {
    expect(s.cityTable).toEqual([
      { city: 'Paris', days: 2, total: 150, avgPerDay: 75, topCategory: 'Food' },
      { city: 'Lyon', days: 1, total: 80, avgPerDay: 80, topCategory: 'Food' },
    ]);
  });
});

describe('computeStats — edge cases', () => {
  it('returns zeros and empty arrays for no transactions', () => {
    const s = computeStats([], []);
    expect(s).toMatchObject({ gross: 0, net: 0, days: 0, avgPerDay: 0 });
    expect(s.byCategory).toEqual([]);
    expect(s.byCity).toEqual([]);
    expect(s.split).toEqual({ integral: 0, share: 0, savings: 0 });
  });

  it('handles a refund-only trip', () => {
    const s = computeStats([tx({ amount: -30, kind: 'REFUND' })], []);
    expect(s.gross).toBe(0);
    expect(s.refunds).toBe(-30);
    expect(s.net).toBe(-30);
    expect(s.byCategory).toEqual([]);
  });
});

describe('cityBreakdown', () => {
  const cities = { '2026-06-21': 'Paris', '2026-06-22': 'Lyon' };
  const cats = [cat('c1', 'Food'), cat('c2', 'Bar')];
  const txs = [
    tx({ amount: 100, categoryId: 'c1', date: '2026-06-21' }),
    tx({ amount: 30, categoryId: null, date: '2026-06-21' }),
    tx({ amount: 50, categoryId: 'c2', date: '2026-06-22' }),
    tx({ amount: -10, kind: 'REFUND', categoryId: 'c1', date: '2026-06-21' }),
  ];

  it('totals expenses by city with the top category', () => {
    const { byCity, cityTable } = cityBreakdown(txs, cats, cities);
    expect(byCity).toEqual([
      { city: 'Paris', amount: 130, color: '#4263EB' },
      { city: 'Lyon', amount: 50, color: '#0CA678' },
    ]);
    expect(cityTable[0]).toMatchObject({ city: 'Paris', days: 1, total: 130, topCategory: 'Food' });
  });

  it('restricts to the allowed categories (uncategorized excluded)', () => {
    const { byCity } = cityBreakdown(txs, cats, cities, new Set(['c2']));
    expect(byCity).toEqual([{ city: 'Lyon', amount: 50, color: '#4263EB' }]);
  });

  it('shows "—" as top category when the spend has no category', () => {
    const { cityTable } = cityBreakdown(
      [tx({ amount: 30, date: '2026-06-21' })],
      [],
      { '2026-06-21': 'Paris' },
    );
    expect(cityTable[0].topCategory).toBe('—');
  });
});

// ===========================================================================
// Corner cases — rounding, period boundaries, grouping, city edges, quirks
// ===========================================================================

describe('computeStats — rounding & float safety', () => {
  it('tames floating-point drift in totals (0.1 + 0.2)', () => {
    const s = computeStats([tx({ amount: 0.1 }), tx({ amount: 0.2 })], []);
    expect(s.gross).toBe(0.3);
  });

  it('rounds a repeating-decimal split to 2 places', () => {
    const s = computeStats([tx({ amount: 10, splitCount: 3 })], []);
    expect(s.gross).toBe(3.33);
    expect(s.split).toEqual({ integral: 10, share: 3.33, savings: 6.67 });
  });

  it('rounds per-day category amounts', () => {
    const s = computeStats(
      [tx({ amount: 10, splitCount: 3, categoryId: 'c1', date: '2026-06-22' })],
      [cat('c1', 'Food')],
    );
    expect(s.dayData[0]).toEqual({ date: '22/06', Food: 3.33 });
  });
});

describe('computeStats — period boundaries', () => {
  it('keeps a dated BEFORE expense out of the daily/weekday series but in totals', () => {
    const s = computeStats(
      [tx({ amount: 100, categoryId: 'c1', period: 'BEFORE', date: '2026-06-21' })],
      [cat('c1', 'Food')],
    );
    expect(s.before).toBe(100);
    expect(s.days).toBe(0); // only DURING dates count as days
    expect(s.dayData).toEqual([]);
    expect(s.weekdayAmounts.reduce((a, b) => a + b, 0)).toBe(0);
    expect(s.beforeDuringData).toEqual([{ category: 'Food', before: 100, during: 0 }]);
    expect(s.byCategory[0]).toMatchObject({ name: 'Food', amount: 100 });
  });

  it('excludes a refund-only category from the breakdowns', () => {
    const cats = [cat('c1', 'Food'), cat('c2', 'Transport')];
    const s = computeStats([
      tx({ amount: -50, kind: 'REFUND', categoryId: 'c1' }),
      tx({ amount: 20, categoryId: 'c2' }),
    ], cats);
    expect(s.byCategory.map((c) => c.name)).toEqual(['Transport']);
    expect(s.beforeDuringData.map((b) => b.category)).toEqual(['Transport']);
    expect(s.refunds).toBe(-50);
  });

  it('allows a negative avgPerDay when refunds dominate a day', () => {
    const s = computeStats([
      tx({ amount: 10, date: '2026-06-22' }),
      tx({ amount: -40, kind: 'REFUND', date: '2026-06-22' }),
    ], []);
    expect(s.days).toBe(1);
    expect(s.during).toBe(-30);
    expect(s.avgPerDay).toBe(-30);
  });
});

describe('computeStats — daily series grouping', () => {
  it('aggregates multiple categories and rows on the same day', () => {
    const cats = [cat('c1', 'Food'), cat('c2', 'Transport')];
    const s = computeStats([
      tx({ amount: 10, categoryId: 'c1', date: '2026-06-22' }),
      tx({ amount: 20, categoryId: 'c1', date: '2026-06-22' }),
      tx({ amount: 5, categoryId: 'c2', date: '2026-06-22' }),
    ], cats);
    expect(s.dayData).toEqual([{ date: '22/06', Food: 30, Transport: 5 }]);
  });

  it('zero-pads single-digit day and month', () => {
    const s = computeStats([tx({ amount: 5, date: '2026-03-05' })], []);
    expect(s.dayData[0].date).toBe('05/03');
  });
});

describe('computeStats — city edge cases', () => {
  it('treats an empty-string city mapping as no city', () => {
    const s = computeStats([tx({ amount: 50, date: '2026-06-21' })], [], { '2026-06-21': '' });
    expect(s.byCity).toEqual([]);
  });

  it('wraps the city palette after 10 cities', () => {
    const cities: CityMap = {};
    const txs: Transaction[] = [];
    for (let i = 0; i < 11; i++) {
      const date = `2026-03-${String(i + 1).padStart(2, '0')}`;
      cities[date] = `City${i}`;
      txs.push(tx({ amount: 110 - i, date })); // descending → City0 ranks first
    }
    const s = computeStats(txs, [], cities);
    expect(s.byCity).toHaveLength(11);
    expect(s.byCity[0].color).toBe('#4263EB');
    expect(s.byCity[10].color).toBe(s.byCity[0].color); // 10 % 10 → palette[0]
  });
});

describe('computeStats — known quirks', () => {
  // Current behavior: a null categoryId and an unknown (dangling) categoryId do
  // NOT merge — they produce two separate "No category" buckets. Unknown ids
  // shouldn't occur in practice (deleting a category nulls its transactions),
  // but this locks in the behavior so a future change is a conscious decision.
  it('keeps null and unknown categoryId as separate "No category" buckets', () => {
    const s = computeStats([
      tx({ amount: 20, categoryId: null }),
      tx({ amount: 10, categoryId: 'ghost' }),
    ], []);
    expect(s.byCategory).toHaveLength(2);
    expect(s.byCategory.every((c) => c.name === 'No category')).toBe(true);
    expect(s.byCategory.map((c) => c.amount)).toEqual([20, 10]);
  });
});
