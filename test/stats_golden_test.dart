import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/stats/stats.dart';

Category categoryFromJson(Map<String, dynamic> j) => Category(
      id: j['id'],
      tripId: j['tripId'],
      name: j['name'],
      color: j['color'],
      icon: j['icon'],
      sortOrder: j['sortOrder'],
    );

Transaction transactionFromJson(Map<String, dynamic> j) => Transaction(
      id: j['id'],
      tripId: j['tripId'],
      period: j['period'],
      date: j['date'],
      description: j['description'],
      amount: (j['amount'] as num).toDouble(),
      categoryId: j['categoryId'],
      kind: j['kind'],
      isIof: j['isIof'],
      splitCount: j['splitCount'],
      createdAt: j['createdAt'],
    );

void main() {
  final europa = jsonDecode(File('assets/europa.json').readAsStringSync()) as Map<String, dynamic>;
  final golden = jsonDecode(File('test/fixtures/stats-golden-europa.json').readAsStringSync()) as Map<String, dynamic>;

  final trip = (europa['trips'] as List).first as Map<String, dynamic>;
  final cities = (trip['cities'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
  final categories = (europa['categories'] as List).map((c) => categoryFromJson(c)).toList();
  final transactions = (europa['transactions'] as List).map((t) => transactionFromJson(t)).toList();

  test('computeStats on the real Europa trip matches the TypeScript golden output', () {
    final s = computeStats(transactions, categories, cities);
    final g = golden['stats'] as Map<String, dynamic>;
    expect(s.gross, g['gross']);
    expect(s.refunds, g['refunds']);
    expect(s.net, g['net']);
    expect(s.before, g['before']);
    expect(s.during, g['during']);
    expect(s.iofRefund, g['iofRefund']);
    expect(s.days, g['days']);
    expect(s.avgPerDay, g['avgPerDay']);
    expect(s.byCategory.length, (g['byCategory'] as List).length);
    for (var i = 0; i < s.byCategory.length; i++) {
      final gc = (g['byCategory'] as List)[i] as Map<String, dynamic>;
      expect(s.byCategory[i].name, gc['name']);
      expect(s.byCategory[i].amount, gc['amount']);
    }
    expect(s.cumulativeByDay.length, (g['cumulativeByDay'] as List).length);
    for (var i = 0; i < s.cumulativeByDay.length; i++) {
      final gc = (g['cumulativeByDay'] as List)[i] as Map<String, dynamic>;
      expect(s.cumulativeByDay[i].date, gc['date']);
      expect(s.cumulativeByDay[i].total, gc['total']);
    }
    expect(s.byCity.length, (g['byCity'] as List).length);
    for (var i = 0; i < s.byCity.length; i++) {
      final gc = (g['byCity'] as List)[i] as Map<String, dynamic>;
      expect(s.byCity[i].city, gc['city']);
      expect(s.byCity[i].amount, gc['amount']);
      expect(s.byCity[i].color, gc['color']);
    }
    expect(s.split.integral, g['split']['integral']);
    expect(s.split.share, g['split']['share']);
    expect(s.split.savings, g['split']['savings']);
  });

  test('cityBreakdown on the real Europa trip matches the TypeScript golden output', () {
    final result = cityBreakdown(transactions, categories, cities);
    final g = golden['cityBreakdown'] as Map<String, dynamic>;
    expect(result.byCity.length, (g['byCity'] as List).length);
    for (var i = 0; i < result.byCity.length; i++) {
      final gc = (g['byCity'] as List)[i] as Map<String, dynamic>;
      expect(result.byCity[i].city, gc['city']);
      expect(result.byCity[i].amount, gc['amount']);
      expect(result.byCity[i].color, gc['color']);
    }
  });

  test('cityBreakdown with a category filter matches the TypeScript golden output', () {
    final g = golden['cityBreakdownFiltered'] as Map<String, dynamic>;
    final filterIds = (g['filterCategoryIds'] as List).cast<String>().toSet();
    final result = cityBreakdown(transactions, categories, cities, filterIds);
    final gr = g['result'] as Map<String, dynamic>;
    expect(result.byCity.length, (gr['byCity'] as List).length);
    for (var i = 0; i < result.byCity.length; i++) {
      final gc = (gr['byCity'] as List)[i] as Map<String, dynamic>;
      expect(result.byCity[i].city, gc['city']);
      expect(result.byCity[i].amount, gc['amount']);
    }
  });
}
