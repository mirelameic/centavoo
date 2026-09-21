import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/stats/stats.dart';

Transaction tx({
  String id = 'tx',
  String tripId = 't1',
  String period = periodDuring,
  String? date,
  String description = '',
  double amount = 0,
  String? categoryId,
  String kind = kindExpense,
  bool isIof = false,
  int splitCount = 1,
  String createdAt = '2026-01-01T00:00:00Z',
}) {
  return Transaction(
    id: id,
    tripId: tripId,
    period: period,
    date: date,
    description: description,
    amount: amount,
    categoryId: categoryId,
    kind: kind,
    isIof: isIof,
    splitCount: splitCount,
    createdAt: createdAt,
  );
}

Category cat(String id, String name, {String color = '#000'}) {
  return Category(id: id, tripId: 't1', name: name, color: color, sortOrder: 0);
}

void main() {
  group('cost', () {
    test('returns the full amount when not split', () {
      expect(cost(tx(amount: 100)), 100);
    });
    test('divides by splitCount', () {
      expect(cost(tx(amount: 100, splitCount: 4)), 25);
    });
    test('treats splitCount 0 as 1', () {
      expect(cost(tx(amount: 100, splitCount: 0)), 100);
    });
  });

  group('computeStats — totals', () {
    final s = computeStats([
      tx(amount: 100, period: periodDuring),
      tx(amount: 50, period: periodBefore),
      tx(amount: -30, kind: kindRefund, period: periodDuring),
      tx(amount: -10, kind: kindRefund, isIof: true, period: periodDuring),
    ], []);

    test('sums gross from positive costs only', () => expect(s.gross, 150));
    test('sums refunds from negative costs', () => expect(s.refunds, -40));
    test('net = gross + refunds', () => expect(s.net, 110));
    test('splits before/during by period', () {
      expect(s.before, 50);
      expect(s.during, 60);
    });
    test('sums IOF refunds separately', () => expect(s.iofRefund, -10));
    test('keeps refunds (incl. IOF) out of the category breakdown', () {
      expect(s.byCategory, hasLength(1));
      expect(s.byCategory[0].name, 'No category');
      expect(s.byCategory[0].amount, 150);
    });
  });

  group('computeStats — categories', () {
    test('aggregates by categoryId, sorted desc, with table metrics', () {
      final cats = [cat('c1', 'Food'), cat('c2', 'Transport')];
      final s = computeStats([
        tx(amount: 100, categoryId: 'c1'),
        tx(amount: 40, categoryId: 'c1'),
        tx(amount: 60, categoryId: 'c2'),
      ], cats);

      expect(s.byCategory.map((c) => [c.name, c.amount]).toList(), [
        ['Food', 140],
        ['Transport', 60],
      ]);
      final food = s.categoryTable.firstWhere((c) => c.name == 'Food');
      expect(food.total, 140);
      expect(food.count, 2);
      expect(food.avgTicket, 70);
      expect(food.pct, 70);
      final transport = s.categoryTable.firstWhere((c) => c.name == 'Transport');
      expect(transport.total, 60);
      expect(transport.count, 1);
      expect(transport.avgTicket, 60);
      expect(transport.pct, 30);
    });

    test('labels a missing categoryId as "No category"', () {
      final s = computeStats([tx(amount: 20, categoryId: null)], []);
      expect(s.byCategory[0].name, 'No category');
      expect(s.byCategory[0].amount, 20);
    });

    test('labels an unknown categoryId as "No category"', () {
      final s = computeStats([tx(amount: 10, categoryId: 'ghost')], []);
      expect(s.byCategory[0].name, 'No category');
    });
  });

  group('computeStats — split savings', () {
    test('charges only the share but records the full value and the savings', () {
      final s = computeStats([tx(amount: 100, splitCount: 2)], []);
      expect(s.gross, 50);
      expect(s.net, 50);
      expect(s.split.integral, 100);
      expect(s.split.share, 50);
      expect(s.split.savings, 50);
    });
  });

  group('computeStats — before × during by category', () {
    test('reports each category split, drops empties, sorts desc', () {
      final cats = [cat('c1', 'Food'), cat('c2', 'Transport')];
      final s = computeStats([
        tx(amount: 100, categoryId: 'c1', period: periodBefore),
        tx(amount: 30, categoryId: 'c1', period: periodDuring),
        tx(amount: 20, categoryId: 'c2', period: periodDuring),
      ], cats);

      expect(s.beforeDuringData.map((b) => [b.category, b.before, b.during]).toList(), [
        ['Food', 100, 30],
        ['Transport', 0, 20],
      ]);
    });
  });

  group('computeStats — days, weekday and daily series', () {
    final s = computeStats([
      tx(amount: 100, date: '2026-06-21'),
      tx(amount: 50, date: '2026-06-22'),
      tx(amount: -30, kind: kindRefund, date: '2026-06-22'),
      tx(amount: -10, kind: kindRefund, date: '2026-06-23'),
    ], []);

    test('counts distinct during-dated days (refund days included)', () {
      expect(s.days, 3);
    });
    test('avgPerDay = during net / days', () {
      expect(s.avgPerDay, 36.67);
    });
    test('buckets expenses by weekday (Sunday = index 0)', () {
      expect(s.weekdayAmounts[0], 100);
      expect(s.weekdayAmounts[1], 50);
      expect(s.weekdayAmounts.reduce((a, b) => a + b), 150);
    });
    test('builds the daily series only from dated expenses, ascending', () {
      expect(s.dayData.map((d) => d.date).toList(), ['21/06', '22/06']);
      expect(s.dayData[0].date, '21/06');
      expect(s.dayData[0].values['No category'], 100);
    });
  });

  group('computeStats — by city', () {
    final cities = {'2026-06-21': 'Paris', '2026-06-22': 'Lyon', '2026-06-23': 'Paris'};
    final s = computeStats([
      tx(amount: 100, categoryId: 'c1', date: '2026-06-21'),
      tx(amount: 50, categoryId: 'c1', date: '2026-06-23'),
      tx(amount: 80, categoryId: 'c1', date: '2026-06-22'),
      tx(amount: 40, categoryId: 'c1', date: '2026-06-24'),
    ], [cat('c1', 'Food')], cities);

    test('totals by city (desc), colored by name', () {
      expect(s.byCity.map((c) => [c.city, c.amount, c.color]).toList(), [
        ['Paris', 150, '#0E8C6B'],
        ['Lyon', 80, '#7D1F44'],
      ]);
    });
    test('builds the city table with days, avg and top category', () {
      expect(s.cityTable.length, 2);
      expect(s.cityTable[0].city, 'Paris');
      expect(s.cityTable[0].days, 2);
      expect(s.cityTable[0].total, 150);
      expect(s.cityTable[0].avgPerDay, 75);
      expect(s.cityTable[0].topCategory, 'Food');
      expect(s.cityTable[1].city, 'Lyon');
      expect(s.cityTable[1].days, 1);
      expect(s.cityTable[1].total, 80);
      expect(s.cityTable[1].avgPerDay, 80);
      expect(s.cityTable[1].topCategory, 'Food');
    });
  });

  group('computeStats — edge cases', () {
    test('returns zeros and empty arrays for no transactions', () {
      final s = computeStats([], []);
      expect(s.gross, 0);
      expect(s.net, 0);
      expect(s.days, 0);
      expect(s.avgPerDay, 0);
      expect(s.byCategory, <CatAgg>[]);
      expect(s.byCity, isEmpty);
      expect(s.split.integral, 0);
      expect(s.split.share, 0);
      expect(s.split.savings, 0);
    });

    test('handles a refund-only trip', () {
      final s = computeStats([tx(amount: -30, kind: kindRefund)], []);
      expect(s.gross, 0);
      expect(s.refunds, -30);
      expect(s.net, -30);
      expect(s.byCategory, isEmpty);
    });
  });

  group('computeStats — rounding & float safety', () {
    test('tames floating-point drift in totals (0.1 + 0.2)', () {
      final s = computeStats([tx(amount: 0.1), tx(amount: 0.2)], []);
      expect(s.gross, 0.3);
    });

    test('rounds a repeating-decimal split to 2 places', () {
      final s = computeStats([tx(amount: 10, splitCount: 3)], []);
      expect(s.gross, 3.33);
      expect(s.split.integral, 10);
      expect(s.split.share, 3.33);
      expect(s.split.savings, 6.67);
    });

    test('rounds per-day category amounts', () {
      final s = computeStats(
        [tx(amount: 10, splitCount: 3, categoryId: 'c1', date: '2026-06-22')],
        [cat('c1', 'Food')],
      );
      expect(s.dayData[0].date, '22/06');
      expect(s.dayData[0].values['Food'], 3.33);
    });
  });

  group('computeStats — period boundaries', () {
    test('keeps a dated BEFORE expense out of the daily/weekday series but in totals', () {
      final s = computeStats(
        [tx(amount: 100, categoryId: 'c1', period: periodBefore, date: '2026-06-21')],
        [cat('c1', 'Food')],
      );
      expect(s.before, 100);
      expect(s.days, 0);
      expect(s.dayData, isEmpty);
      expect(s.weekdayAmounts.reduce((a, b) => a + b), 0);
      expect(s.beforeDuringData.map((b) => [b.category, b.before, b.during]).toList(), [
        ['Food', 100, 0],
      ]);
      expect(s.byCategory[0].name, 'Food');
      expect(s.byCategory[0].amount, 100);
    });

    test('excludes a refund-only category from the breakdowns', () {
      final cats = [cat('c1', 'Food'), cat('c2', 'Transport')];
      final s = computeStats([
        tx(amount: -50, kind: kindRefund, categoryId: 'c1'),
        tx(amount: 20, categoryId: 'c2'),
      ], cats);
      expect(s.byCategory.map((c) => c.name).toList(), ['Transport']);
      expect(s.beforeDuringData.map((b) => b.category).toList(), ['Transport']);
      expect(s.refunds, -50);
    });

    test('allows a negative avgPerDay when refunds dominate a day', () {
      final s = computeStats([
        tx(amount: 10, date: '2026-06-22'),
        tx(amount: -40, kind: kindRefund, date: '2026-06-22'),
      ], []);
      expect(s.days, 1);
      expect(s.during, -30);
      expect(s.avgPerDay, -30);
    });
  });

  group('computeStats — daily series grouping', () {
    test('aggregates multiple categories and rows on the same day', () {
      final cats = [cat('c1', 'Food'), cat('c2', 'Transport')];
      final s = computeStats([
        tx(amount: 10, categoryId: 'c1', date: '2026-06-22'),
        tx(amount: 20, categoryId: 'c1', date: '2026-06-22'),
        tx(amount: 5, categoryId: 'c2', date: '2026-06-22'),
      ], cats);
      expect(s.dayData.length, 1);
      expect(s.dayData[0].date, '22/06');
      expect(s.dayData[0].values, {'Food': 30, 'Transport': 5});
    });

    test('zero-pads single-digit day and month', () {
      final s = computeStats([tx(amount: 5, date: '2026-03-05')], []);
      expect(s.dayData[0].date, '05/03');
    });
  });

  group('computeStats — city edge cases', () {
    test('treats an empty-string city mapping as no city', () {
      final s = computeStats([tx(amount: 50, date: '2026-06-21')], [], {'2026-06-21': ''});
      expect(s.byCity, isEmpty);
    });

    test('handles more cities than the palette has colors', () {
      final cities = <String, String>{};
      final txs = <Transaction>[];
      for (var i = 0; i < 11; i++) {
        final date = '2026-03-${(i + 1).toString().padLeft(2, '0')}';
        cities[date] = 'City$i';
        txs.add(tx(amount: 110.0 - i, date: date));
      }
      final s = computeStats(txs, [], cities);
      expect(s.byCity, hasLength(11));
    });

    test('keeps a city\'s color tied to its name, not its spend rank', () {
      final cities = {'2026-03-01': 'Paris', '2026-03-02': 'Lyon'};
      final a = computeStats(
        [tx(amount: 100, date: '2026-03-01'), tx(amount: 10, date: '2026-03-02')],
        [],
        cities,
      );
      final b = computeStats(
        [tx(amount: 10, date: '2026-03-01'), tx(amount: 100, date: '2026-03-02')],
        [],
        cities,
      );
      String? colorOf(List<dynamic> rows, String city) =>
          rows.cast<dynamic>().firstWhere((r) => r.city == city, orElse: () => null)?.color;
      expect(colorOf(a.byCity, 'Paris'), colorOf(b.byCity, 'Paris'));
      expect(colorOf(a.byCity, 'Lyon'), colorOf(b.byCity, 'Lyon'));
    });
  });

  group('computeStats — cumulative spend', () {
    test('runs a total across dated during-period days, ascending', () {
      final s = computeStats([
        tx(amount: 100, date: '2026-06-21'),
        tx(amount: 50, date: '2026-06-22'),
        tx(amount: 20, date: '2026-06-23'),
      ], []);
      expect(s.cumulativeByDay.map((c) => [c.date, c.total]).toList(), [
        ['21/06', 100],
        ['22/06', 150],
        ['23/06', 170],
      ]);
    });

    test('is empty when there are no dated during-period expenses', () {
      final s = computeStats([tx(amount: 100, period: periodBefore, date: '2026-06-21')], []);
      expect(s.cumulativeByDay, isEmpty);
    });

    test('carries a refund into the running total on its day', () {
      final s = computeStats([
        tx(amount: 100, date: '2026-06-21'),
        tx(amount: -30, kind: kindRefund, date: '2026-06-22'),
      ], []);
      expect(s.cumulativeByDay.map((c) => [c.date, c.total]).toList(), [
        ['21/06', 100],
        ['22/06', 70],
      ]);
    });

    test('sums same-day transactions into a single point before accumulating', () {
      final s = computeStats([
        tx(amount: 10, date: '2026-06-22'),
        tx(amount: 20, date: '2026-06-22'),
        tx(amount: 5, date: '2026-06-23'),
      ], []);
      expect(s.cumulativeByDay.map((c) => [c.date, c.total]).toList(), [
        ['22/06', 30],
        ['23/06', 35],
      ]);
    });
  });

  group('computeStats — known quirks', () {
    test('keeps null and unknown categoryId as separate "No category" buckets', () {
      final s = computeStats([
        tx(amount: 20, categoryId: null),
        tx(amount: 10, categoryId: 'ghost'),
      ], []);
      expect(s.byCategory, hasLength(2));
      expect(s.byCategory.every((c) => c.name == 'No category'), true);
      expect(s.byCategory.map((c) => c.amount).toList(), [20, 10]);
    });
  });

  group('cityBreakdown', () {
    final cities = {'2026-06-21': 'Paris', '2026-06-22': 'Lyon'};
    final cats = [cat('c1', 'Food'), cat('c2', 'Bar')];
    final txs = [
      tx(amount: 100, categoryId: 'c1', date: '2026-06-21'),
      tx(amount: 30, categoryId: null, date: '2026-06-21'),
      tx(amount: 50, categoryId: 'c2', date: '2026-06-22'),
      tx(amount: -10, kind: kindRefund, categoryId: 'c1', date: '2026-06-21'),
    ];

    test('totals expenses by city with the top category', () {
      final result = cityBreakdown(txs, cats, cities);
      expect(result.byCity.map((c) => [c.city, c.amount, c.color]).toList(), [
        ['Paris', 130, '#0E8C6B'],
        ['Lyon', 50, '#7D1F44'],
      ]);
      expect(result.cityTable[0].city, 'Paris');
      expect(result.cityTable[0].days, 1);
      expect(result.cityTable[0].total, 130);
      expect(result.cityTable[0].topCategory, 'Food');
    });

    test('keeps each city\'s color the same even when a filter changes the ranking', () {
      final result = cityBreakdown(txs, cats, cities, {'c2'});
      expect(result.byCity.map((c) => [c.city, c.amount, c.color]).toList(), [
        ['Lyon', 50, '#7D1F44'],
      ]);
    });

    test('shows "—" as top category when the spend has no category', () {
      final result = cityBreakdown(
        [tx(amount: 30, date: '2026-06-21')],
        [],
        {'2026-06-21': 'Paris'},
      );
      expect(result.cityTable[0].topCategory, '—');
    });
  });
}
