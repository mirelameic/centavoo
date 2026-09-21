import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/mappers.dart';

void main() {
  test('tripFromRow decodes citiesJson into a map', () {
    final row = TripRow(
      id: 't1',
      name: 'Japan',
      currency: 'BRL',
      citiesJson: '{"2026-01-01":"Tokyo"}',
      createdAt: '2026-01-01T00:00:00Z',
      sortOrder: 0,
    );
    final trip = tripFromRow(row);
    expect(trip.id, 't1');
    expect(trip.cities, {'2026-01-01': 'Tokyo'});
  });

  test('tripFromRow decodes cityListJson into a list, defaulting to null when absent', () {
    final withList = tripFromRow(TripRow(
      id: 't1',
      name: 'Japan',
      currency: 'BRL',
      citiesJson: '{}',
      cityListJson: '["Tokyo","Kyoto"]',
      createdAt: '2026-01-01T00:00:00Z',
      sortOrder: 0,
    ));
    expect(withList.cityList, ['Tokyo', 'Kyoto']);

    final withoutList = tripFromRow(TripRow(
      id: 't1',
      name: 'Japan',
      currency: 'BRL',
      citiesJson: '{}',
      createdAt: '2026-01-01T00:00:00Z',
      sortOrder: 0,
    ));
    expect(withoutList.cityList, isNull);
  });

  test('categoryFromRow copies every field', () {
    final row = CategoryRow(id: 'c1', tripId: 't1', name: 'Food', color: '#fff', sortOrder: 2);
    final cat = categoryFromRow(row);
    expect(cat.id, 'c1');
    expect(cat.sortOrder, 2);
  });

  test('transactionFromRow copies every field', () {
    final row = TransactionRow(
      id: 'tx1',
      tripId: 't1',
      period: 'DURING',
      description: 'Sushi',
      amount: 50,
      kind: 'EXPENSE',
      isIof: false,
      splitCount: 2,
      createdAt: '2026-01-01T00:00:00Z',
    );
    final tx = transactionFromRow(row);
    expect(tx.id, 'tx1');
    expect(tx.amount, 50);
    expect(tx.splitCount, 2);
  });

  test('categoryRuleFromRow copies every field', () {
    final row = CategoryRuleRow(id: 5, keyword: 'uber', categoryId: 'c1', priority: 2);
    final rule = categoryRuleFromRow(row);
    expect(rule.id, 5);
    expect(rule.keyword, 'uber');
    expect(rule.categoryId, 'c1');
    expect(rule.priority, 2);
  });
}
