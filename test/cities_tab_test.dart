import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/screens/trip/cities_tab.dart';

Transaction tx({
  required String id,
  String? date,
  double amount = 0,
  String? categoryId,
}) {
  return Transaction(
    id: id,
    tripId: 't1',
    period: periodDuring,
    date: date,
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
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('shows the empty state when no transaction has a city', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(
        body: SingleChildScrollView(
          child: CitiesTab(db: db, tripId: 't1', txs: const [], cats: const [], cities: const {}, currency: 'BRL'),
        ),
      ),
    ));
    expect(find.text('Nenhuma transação com cidade ainda.'), findsOneWidget);
    await db.close();
  });

  testWidgets('shows the city table and legend for transactions with a dated city', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cats = [cat('c1', 'Comida')];
    final txs = [
      tx(id: '1', date: '2026-05-01', amount: 100, categoryId: 'c1'),
      tx(id: '2', date: '2026-05-02', amount: 50, categoryId: 'c1'),
    ];
    final cities = {'2026-05-01': 'Lisboa', '2026-05-02': 'Lisboa'};

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(
        body: SingleChildScrollView(
          child: CitiesTab(db: db, tripId: 't1', txs: txs, cats: cats, cities: cities, currency: 'BRL'),
        ),
      ),
    ));

    expect(find.text('Lisboa'), findsWidgets);
    expect(find.text('2 dia(s) · Média/dia: R\$ 75,00'), findsOneWidget);
    expect(find.text('Comida'), findsWidgets);
    await db.close();
  });

  testWidgets('filtering by category narrows the city breakdown table', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cats = [cat('c1', 'Comida'), cat('c2', 'Transporte')];
    final txs = [
      tx(id: '1', date: '2026-05-01', amount: 100, categoryId: 'c1'),
      tx(id: '2', date: '2026-05-02', amount: 200, categoryId: 'c2'),
    ];
    final cities = {'2026-05-01': 'Lisboa', '2026-05-02': 'Porto'};

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(
        body: SingleChildScrollView(
          child: CitiesTab(db: db, tripId: 't1', txs: txs, cats: cats, cities: cities, currency: 'BRL'),
        ),
      ),
    ));

    expect(find.text('1 dia(s) · Média/dia: R\$ 100,00'), findsOneWidget);
    expect(find.text('1 dia(s) · Média/dia: R\$ 200,00'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Comida'));
    await tester.pump();

    expect(find.text('1 dia(s) · Média/dia: R\$ 100,00'), findsOneWidget);
    expect(find.text('1 dia(s) · Média/dia: R\$ 200,00'), findsNothing);
    await db.close();
  });

  testWidgets('shows the per-day city editor below the breakdown', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final txs = [tx(id: '1', date: '2026-05-01', amount: 100)];
    final cities = {'2026-05-01': 'Lisboa'};

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(
        body: SingleChildScrollView(
          child: CitiesTab(db: db, tripId: 't1', txs: txs, cats: const [], cities: cities, currency: 'BRL'),
        ),
      ),
    ));

    expect(find.text('Cidades por dia'), findsOneWidget);
    expect(find.text('Cidades da viagem'), findsOneWidget);
    await db.close();
  });
}
