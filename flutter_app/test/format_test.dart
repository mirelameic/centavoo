import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/models/transaction.dart' show periodBefore, periodDuring;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('money', () {
    test('formats with the currency symbol, a space, and pt-BR grouping', () {
      expect(money(3709.8), 'R\$ 3.709,80');
    });

    test('keeps the minus sign attached to the symbol, not the number', () {
      expect(money(-30), '-R\$ 30,00');
    });
  });

  group('fmtDate', () {
    test('formats as "day de month" in Portuguese', () {
      expect(fmtDate('2026-05-17'), '17 de mai.');
    });

    test('returns an em dash for a null date', () {
      expect(fmtDate(null), '—');
    });
  });

  group('periodForDate', () {
    test('returns BEFORE when the date is earlier than the trip start', () {
      expect(periodForDate('2026-05-16', '2026-05-17'), periodBefore);
    });

    test('returns DURING when the date is on or after the trip start', () {
      expect(periodForDate('2026-05-17', '2026-05-17'), periodDuring);
      expect(periodForDate('2026-05-18', '2026-05-17'), periodDuring);
    });

    test('returns null when either date is missing', () {
      expect(periodForDate(null, '2026-05-17'), isNull);
      expect(periodForDate('2026-05-17', null), isNull);
    });
  });

  group('dateRange', () {
    test('returns every ISO date from start to end inclusive', () {
      expect(dateRange('2026-05-17', '2026-05-20'), [
        '2026-05-17',
        '2026-05-18',
        '2026-05-19',
        '2026-05-20',
      ]);
    });

    test('returns a single day when start equals end', () {
      expect(dateRange('2026-05-17', '2026-05-17'), ['2026-05-17']);
    });

    test('crosses a month boundary correctly', () {
      expect(dateRange('2026-05-30', '2026-06-02'), [
        '2026-05-30',
        '2026-05-31',
        '2026-06-01',
        '2026-06-02',
      ]);
    });
  });

  group('groupCityBlocks', () {
    test('groups consecutive days with the same city into one block', () {
      final days = ['2026-05-17', '2026-05-18', '2026-05-19'];
      final cities = {'2026-05-17': 'Lisboa', '2026-05-18': 'Lisboa', '2026-05-19': 'Lisboa'};
      final blocks = groupCityBlocks(days, cities);
      expect(blocks.length, 1);
      expect(blocks[0].city, 'Lisboa');
      expect(blocks[0].start, '2026-05-17');
      expect(blocks[0].end, '2026-05-19');
      expect(blocks[0].days, days);
    });

    test('splits into separate blocks when the city changes', () {
      final days = ['2026-05-17', '2026-05-18', '2026-05-19'];
      final cities = {'2026-05-17': 'Lisboa', '2026-05-18': 'Porto', '2026-05-19': 'Porto'};
      final blocks = groupCityBlocks(days, cities);
      expect(blocks.length, 2);
      expect(blocks[0].city, 'Lisboa');
      expect(blocks[1].city, 'Porto');
      expect(blocks[1].start, '2026-05-18');
      expect(blocks[1].end, '2026-05-19');
    });

    test('skips days with no assigned city', () {
      final days = ['2026-05-17', '2026-05-18', '2026-05-19'];
      final cities = {'2026-05-17': 'Lisboa', '2026-05-19': 'Lisboa'};
      final blocks = groupCityBlocks(days, cities);
      expect(blocks.length, 2);
      expect(blocks[0].days, ['2026-05-17']);
      expect(blocks[1].days, ['2026-05-19']);
    });

    test('a gap in days breaks the block even with the same city', () {
      final days = ['2026-05-17', '2026-05-19'];
      final cities = {'2026-05-17': 'Lisboa', '2026-05-19': 'Lisboa'};
      final blocks = groupCityBlocks(days, cities);
      expect(blocks.length, 2);
    });
  });
}
