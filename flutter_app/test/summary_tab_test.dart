import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/screens/trip/summary_tab.dart';
import 'package:centavoo/stats/stats.dart';

Transaction tx({
  String id = 'tx',
  String tripId = 't1',
  String period = periodDuring,
  String? date,
  String description = '',
  double amount = 0,
  String? categoryId,
  int splitCount = 1,
}) {
  return Transaction(
    id: id,
    tripId: tripId,
    period: period,
    date: date,
    description: description,
    amount: amount,
    categoryId: categoryId,
    kind: kindExpense,
    isIof: false,
    splitCount: splitCount,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

Category cat(String id, String name, {String color = '#0E8C6B'}) {
  return Category(id: id, tripId: 't1', name: name, color: color, sortOrder: 0);
}

void main() {
  testWidgets('shows category legend rows and the gross total in the donut center', (tester) async {
    final cats = [cat('c1', 'Hospedagem')];
    final txs = [tx(id: '1', categoryId: 'c1', amount: 100)];
    final stats = computeStats(txs, cats);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SummaryTab(stats: stats, currency: 'BRL', hasSplit: false)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Hospedagem'), findsOneWidget);
    expect(find.text('R\$ 100,00'), findsWidgets);
    expect(find.text('Você dividiu × sua parte'), findsNothing);
  });

  testWidgets('shows split cards when hasSplit is true', (tester) async {
    final cats = [cat('c1', 'Hospedagem')];
    final txs = [tx(id: '1', categoryId: 'c1', amount: 100, splitCount: 2)];
    final stats = computeStats(txs, cats);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SummaryTab(stats: stats, currency: 'BRL', hasSplit: true)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Você dividiu × sua parte'), findsOneWidget);
    expect(find.text('VALOR INTEGRAL'), findsOneWidget);
    expect(find.text('SUA PARTE'), findsOneWidget);
    expect(find.text('VOCÊ ECONOMIZOU'), findsOneWidget);
  });
}
