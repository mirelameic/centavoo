import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/logic/categorize.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/category_rule.dart';

CategoryRule rule(String keyword, String categoryId, {String? categoryName, int priority = 0}) {
  return CategoryRule(keyword: keyword, categoryId: categoryId, categoryName: categoryName, priority: priority);
}

Category cat(String id, String name) => Category(id: id, tripId: 't', name: name, color: '#000000', sortOrder: 0);

void main() {
  final cats = [cat('transport', 'Transporte'), cat('food', 'Alimentação')];

  test('returns the category for a keyword found in the description, case-insensitively', () {
    final rules = [rule('uber', 'transport')];
    expect(suggestCategory('Corrida de Uber até o hotel', rules, cats), 'transport');
  });

  test('returns null when no keyword matches', () {
    final rules = [rule('uber', 'transport')];
    expect(suggestCategory('Jantar no restaurante', rules, cats), isNull);
  });

  test('prefers the higher-priority rule when multiple keywords match', () {
    final rules = [rule('uber', 'transport', priority: 1), rule('uber eats', 'food', priority: 2)];
    expect(suggestCategory('Uber Eats - pedido', rules, cats), 'food');
  });

  test('prefers the longer keyword when priorities tie', () {
    final rules = [rule('uber', 'transport'), rule('uber eats', 'food')];
    expect(suggestCategory('Uber Eats - pedido', rules, cats), 'food');
  });

  test('resolves a rule from another trip to the category with the same name in this trip', () {
    final otherTrip = [cat('cat_new_1', 'transporte'), cat('cat_new_2', 'Compras')];
    final rules = [rule('uber', 'cat_transporte', categoryName: 'Transporte')];
    expect(suggestCategory('Uber aeroporto', rules, otherTrip), 'cat_new_1');
  });

  test('skips a matching rule whose category does not exist in this trip, falling back to the next match', () {
    final rules = [
      rule('uber eats', 'gone', categoryName: 'Delivery', priority: 5),
      rule('uber', 'transport', priority: 1),
    ];
    expect(suggestCategory('Uber Eats - pedido', rules, cats), 'transport');
  });

  test('returns null when the only matching rule cannot be resolved', () {
    final rules = [rule('uber', 'gone')];
    expect(suggestCategory('Uber', rules, cats), isNull);
  });
}
