import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/categorize.dart';
import 'package:centavoo/models/category_rule.dart';

CategoryRule rule(String keyword, String categoryId, {int priority = 0}) {
  return CategoryRule(keyword: keyword, categoryId: categoryId, priority: priority);
}

void main() {
  test('returns the category for a keyword found in the description, case-insensitively', () {
    final rules = [rule('uber', 'transport')];
    expect(suggestCategory('Corrida de Uber até o hotel', rules), 'transport');
  });

  test('returns null when no keyword matches', () {
    final rules = [rule('uber', 'transport')];
    expect(suggestCategory('Jantar no restaurante', rules), isNull);
  });

  test('prefers the higher-priority rule when multiple keywords match', () {
    final rules = [rule('uber', 'transport', priority: 1), rule('uber eats', 'food', priority: 2)];
    expect(suggestCategory('Uber Eats - pedido', rules), 'food');
  });

  test('prefers the longer keyword when priorities tie', () {
    final rules = [rule('uber', 'transport'), rule('uber eats', 'food')];
    expect(suggestCategory('Uber Eats - pedido', rules), 'food');
  });
}
