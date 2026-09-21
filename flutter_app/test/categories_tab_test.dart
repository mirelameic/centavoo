import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/screens/trip/categories_tab.dart';
import 'package:centavoo/stats/stats.dart';

Transaction tx({
  required String id,
  String period = periodDuring,
  double amount = 0,
  String? categoryId,
}) {
  return Transaction(
    id: id,
    tripId: 't1',
    period: period,
    description: 'd',
    amount: amount,
    categoryId: categoryId,
    kind: kindExpense,
    isIof: false,
    splitCount: 1,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

Category cat(String id, String name, {String color = '#0E8C6B'}) {
  return Category(id: id, tripId: 't1', name: name, color: color, sortOrder: 0);
}

void main() {
  testWidgets('shows the category table with percentage, count and average ticket', (tester) async {
    final cats = [cat('c1', 'Hospedagem')];
    final txs = [
      tx(id: '1', categoryId: 'c1', amount: 100),
      tx(id: '2', categoryId: 'c1', amount: 200),
    ];
    final stats = computeStats(txs, cats);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CategoriesTab(stats: stats, currency: 'BRL')),
    ));

    expect(find.text('Hospedagem'), findsWidgets);
    expect(find.text('100% · 2 transações'), findsOneWidget);
    expect(find.text('Ticket médio: R\$ 150,00'), findsOneWidget);
    expect(find.text('R\$ 300,00'), findsWidgets);
  });

  testWidgets('shows the before/during toggle legend and hides a series on tap', (tester) async {
    final cats = [cat('c1', 'Hospedagem')];
    final txs = [
      tx(id: '1', period: periodBefore, categoryId: 'c1', amount: 100),
      tx(id: '2', period: periodDuring, categoryId: 'c1', amount: 50),
    ];
    final stats = computeStats(txs, cats);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CategoriesTab(stats: stats, currency: 'BRL')),
    ));

    expect(find.text('Antes'), findsOneWidget);
    expect(find.text('Durante'), findsOneWidget);

    final beforeText = tester.widget<Text>(find.text('Antes'));
    expect(beforeText.style?.decoration, isNot(TextDecoration.lineThrough));

    await tester.tap(find.text('Antes'));
    await tester.pump();

    final afterText = tester.widget<Text>(find.text('Antes'));
    expect(afterText.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('renders without a category table when there are no transactions', (tester) async {
    final stats = computeStats([], []);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CategoriesTab(stats: stats, currency: 'BRL')),
    ));
    expect(find.text('Resumo por categoria'), findsOneWidget);
    expect(find.text('Antes × Durante'), findsOneWidget);
  });
}
