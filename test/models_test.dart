import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/models/trip.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/models/category_rule.dart';

void main() {
  test('Trip holds every declared field', () {
    final trip = Trip(
      id: 't1',
      name: 'Japan',
      destination: 'Tokyo',
      startDate: '2026-01-01',
      endDate: '2026-01-10',
      currency: 'BRL',
      cities: {'2026-01-01': 'Tokyo'},
      cityList: ['Tokyo'],
      createdAt: '2026-01-01T00:00:00Z',
    );
    expect(trip.id, 't1');
    expect(trip.cities, {'2026-01-01': 'Tokyo'});
    expect(trip.cityList, ['Tokyo']);
  });

  test('Trip.cities defaults to an empty map', () {
    final trip = Trip(id: 't1', name: 'Japan', currency: 'BRL', createdAt: '2026-01-01T00:00:00Z');
    expect(trip.cities, <String, String>{});
  });

  test('Category holds every declared field', () {
    final cat = Category(id: 'c1', tripId: 't1', name: 'Food', color: '#fff', icon: 'food', sortOrder: 0);
    expect(cat.icon, 'food');
    expect(cat.sortOrder, 0);
  });

  test('Transaction holds every declared field', () {
    final tx = Transaction(
      id: 'tx1',
      tripId: 't1',
      period: periodDuring,
      date: '2026-01-01',
      description: 'Sushi',
      amount: 50,
      categoryId: 'c1',
      kind: kindExpense,
      isIof: false,
      splitCount: 1,
      createdAt: '2026-01-01T00:00:00Z',
    );
    expect(tx.period, periodDuring);
    expect(tx.kind, kindExpense);
  });

  test('CategoryRule holds every declared field', () {
    final rule = CategoryRule(id: 1, keyword: 'sushi', categoryId: 'c1', priority: 1);
    expect(rule.id, 1);
    expect(rule.keyword, 'sushi');
  });
}
