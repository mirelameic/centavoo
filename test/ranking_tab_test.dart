import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/screens/trip/ranking_tab.dart';

Transaction tx({
  required String id,
  String period = periodDuring,
  String? date,
  String description = '',
  double amount = 0,
  String? categoryId,
  String kind = kindExpense,
  int splitCount = 1,
}) {
  return Transaction(
    id: id,
    tripId: 't1',
    period: period,
    date: date,
    description: description,
    amount: amount,
    categoryId: categoryId,
    kind: kind,
    isIof: false,
    splitCount: splitCount,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

Category cat(String id, String name, {String color = '#0E8C6B'}) {
  return Category(id: id, tripId: 't1', name: name, color: color, sortOrder: 0);
}

void main() {
  testWidgets('shows the empty state when there are no transactions', (tester) async {
    await tester.pumpWidget(const MaterialApp(locale: Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(body: RankingTab(txs: [], catById: {}, cities: {}, currency: 'BRL')),
    ));
    expect(find.text('Nenhuma transação ainda.'), findsOneWidget);
  });

  testWidgets('shows top-10 before and during transactions sorted by amount, each section headed', (tester) async {
    final cats = {'c1': cat('c1', 'Hospedagem')};
    final txs = [
      tx(id: '1', period: periodBefore, description: 'Hotel', amount: 500, categoryId: 'c1'),
      tx(id: '2', period: periodBefore, description: 'Passagem', amount: 900, categoryId: 'c1'),
      tx(id: '3', period: periodDuring, description: 'Jantar', amount: 100, categoryId: 'c1'),
      tx(id: '4', period: periodDuring, description: 'Reembolso', amount: -50, kind: kindRefund),
    ];

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(body: RankingTab(txs: txs, catById: cats, cities: const {}, currency: 'BRL')),
    ));

    expect(find.text('Maiores gastos · antes'), findsOneWidget);
    expect(find.text('Maiores gastos · durante'), findsOneWidget);
    expect(find.text('Passagem'), findsOneWidget);
    expect(find.text('Hotel'), findsOneWidget);
    expect(find.text('Jantar'), findsOneWidget);
    expect(find.text('Reembolso'), findsNothing);

    final passagemTop = tester.getTopLeft(find.text('Passagem')).dy;
    final hotelTop = tester.getTopLeft(find.text('Hotel')).dy;
    expect(passagemTop, lessThan(hotelTop));
  });
}
