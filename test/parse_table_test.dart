import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/models/transaction.dart' show kindExpense, kindRefund;
import 'package:centavoo/parse_table.dart';

void main() {
  group('splitRows', () {
    test('auto-detects tab-separated pasted text', () {
      expect(splitRows('12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00'), [
        ['12/03/2026', 'Uber', '45,90'],
        ['13/03/2026', 'Padaria', '12,00'],
      ]);
    });

    test('auto-detects semicolon-separated CSV', () {
      expect(splitRows('data;descricao;valor\n01/01/2026;Taxi;10,00'), [
        ['data', 'descricao', 'valor'],
        ['01/01/2026', 'Taxi', '10,00'],
      ]);
    });

    test('respects an explicit delimiter override', () {
      expect(splitRows('a,b,c', delimiter: ';'), [
        ['a,b,c'],
      ]);
    });

    test('keeps commas inside quoted fields intact', () {
      expect(splitRows('01/01/2026,"Uber, viagem",10,00', delimiter: ','), [
        ['01/01/2026', 'Uber, viagem', '10', '00'],
      ]);
    });

    test('drops blank lines and pads short rows', () {
      expect(splitRows('a,b,c\n\nd,e'), [
        ['a', 'b', 'c'],
        ['d', 'e', ''],
      ]);
    });

    test('returns an empty list for empty input instead of throwing', () {
      expect(splitRows('   \n  '), <List<String>>[]);
    });
  });

  group('parseAmount', () {
    test('parses plain decimals', () => expect(parseAmount('45.90'), 45.9));
    test('parses BR-style comma decimals', () => expect(parseAmount('45,90'), 45.9));
    test('parses BR-style thousands + decimal', () => expect(parseAmount('1.234,56'), 1234.56));
    test('parses US-style thousands + decimal', () => expect(parseAmount('1,234.56'), 1234.56));
    test('parses a currency-prefixed value', () => expect(parseAmount('R\$ 45,90'), 45.9));
    test('treats parentheses as negative', () => expect(parseAmount('(30,00)'), -30));
    test('parses a leading minus sign', () => expect(parseAmount('-12.50'), -12.5));
    test('parses a trailing minus sign', () => expect(parseAmount('12,50-'), -12.5));
    test('treats a lone 3-digit-group comma as thousands, not decimals', () => expect(parseAmount('1,234'), 1234));
    test('treats a lone 3-digit-group dot as thousands, not decimals', () => expect(parseAmount('1.234'), 1234));
    test('returns null for empty or non-numeric text', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
    });
  });

  group('parseDate', () {
    test('parses ISO dates', () => expect(parseDate('2026-03-12'), '2026-03-12'));
    test('parses day-first slash dates', () => expect(parseDate('12/03/2026'), '2026-03-12'));
    test('parses day-first dot dates', () => expect(parseDate('12.03.2026'), '2026-03-12'));
    test('expands a 2-digit year', () => expect(parseDate('12/03/26'), '2026-03-12'));
    test('returns null for an invalid month/day', () => expect(parseDate('32/13/2026'), isNull));
    test('returns null for unrecognized text', () => expect(parseDate('yesterday'), isNull));
  });

  group('guessRoles', () {
    test('identifies date, amount and description columns', () {
      final rows = [
        ['12/03/2026', 'Uber', '45,90'],
        ['13/03/2026', 'Padaria', '12,00'],
      ];
      expect(guessRoles(rows), [colDate, colDescription, colAmount]);
    });
  });

  group('deriveKind', () {
    test('treats a negative amount as a refund', () => expect(deriveKind(-30), kindRefund));
    test('treats a positive amount as an expense', () => expect(deriveKind(30), kindExpense));
    test('treats zero as an expense', () => expect(deriveKind(0), kindExpense));
    test('treats a missing amount as an expense', () => expect(deriveKind(null), kindExpense));
  });

  group('deriveIsIof', () {
    test('flags a refund whose description mentions IOF, case-insensitively', () {
      expect(deriveIsIof(kindRefund, 'IOF Compra internacional'), isTrue);
      expect(deriveIsIof(kindRefund, 'iof brisa de mar'), isTrue);
    });
    test('is false for a refund with no IOF mention', () {
      expect(deriveIsIof(kindRefund, 'Estorno hotel cancelado'), isFalse);
    });
    test('is always false for an expense, even if it mentions IOF', () {
      expect(deriveIsIof(kindExpense, 'Taxa IOF cartão'), isFalse);
    });
  });

  group('looksLikeHeaderRow', () {
    test('detects a header row when it does not parse but later rows do', () {
      final rows = [
        ['data', 'descricao', 'valor'],
        ['12/03/2026', 'Uber', '45,90'],
      ];
      expect(looksLikeHeaderRow(rows, [colDate, colDescription, colAmount]), isTrue);
    });

    test('returns false when the first row already parses as data', () {
      final rows = [
        ['12/03/2026', 'Uber', '45,90'],
        ['13/03/2026', 'Padaria', '12,00'],
      ];
      expect(looksLikeHeaderRow(rows, [colDate, colDescription, colAmount]), isFalse);
    });
  });
}
