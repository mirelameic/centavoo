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

    test('formats with en-US grouping when an explicit locale is given', () {
      expect(money(3709.8, locale: 'en'), 'R\$ 3,709.80');
    });

    test('follows the global appLocale when no explicit locale is given', () {
      appLocale = 'en';
      expect(money(3709.8), 'R\$ 3,709.80');
      appLocale = 'pt_BR';
    });
  });

  group('parseAmountInput', () {
    test('parses a plain integer', () {
      expect(parseAmountInput('50'), 50);
    });

    test('treats a lone comma as the decimal separator (pt-BR keyboard)', () {
      expect(parseAmountInput('50,5'), 50.5);
    });

    test('treats a lone dot as the decimal separator (numeric keypad)', () {
      expect(parseAmountInput('50.5'), 50.5);
    });

    test('parses pt-BR formatted thousands with a comma decimal', () {
      expect(parseAmountInput('1.500,50'), 1500.5);
    });

    test('parses en-US formatted thousands with a dot decimal', () {
      expect(parseAmountInput('1,500.50'), 1500.5);
    });

    test('parses a large pt-BR amount with multiple thousand groups', () {
      expect(parseAmountInput('12.345.678,90'), 12345678.9);
    });

    test('returns null for non-numeric text', () {
      expect(parseAmountInput('abc'), isNull);
    });
  });

  group('fmtDate', () {
    test('formats as "day de month" in Portuguese', () {
      expect(fmtDate('2026-05-17'), '17 de mai.');
    });

    test('returns an em dash for a null date', () {
      expect(fmtDate(null), '—');
    });

    test('formats as "month day" in English when an explicit locale is given', () {
      expect(fmtDate('2026-05-17', locale: 'en'), 'May 17');
    });

    test('follows the global appLocale when no explicit locale is given', () {
      appLocale = 'en';
      expect(fmtDate('2026-05-17'), 'May 17');
      appLocale = 'pt_BR';
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
