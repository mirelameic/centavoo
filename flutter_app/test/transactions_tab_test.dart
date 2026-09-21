import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/screens/trip/transactions_tab.dart';

Transaction tx({
  required String id,
  String period = periodDuring,
  String? date,
  String description = 'd',
  double amount = 0,
  String? categoryId,
}) {
  return Transaction(
    id: id,
    tripId: 't1',
    period: period,
    date: date,
    description: description,
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

  testWidgets('shows the results count and total for the given transactions', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final txs = [
      tx(id: '1', description: 'Jantar', amount: 100),
      tx(id: '2', description: 'Hotel', amount: 200),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
      ),
    ));

    expect(find.text('2 resultado(s) · R\$ 300,00'), findsOneWidget);
    expect(find.text('Jantar'), findsOneWidget);
    expect(find.text('Hotel'), findsOneWidget);
    await db.close();
  });

  testWidgets('typing in the search box filters by description', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final txs = [
      tx(id: '1', description: 'Jantar', amount: 100),
      tx(id: '2', description: 'Hotel', amount: 200),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'jan');
    await tester.pump();

    expect(find.text('Jantar'), findsOneWidget);
    expect(find.text('Hotel'), findsNothing);
    expect(find.text('1 resultado(s) · R\$ 100,00'), findsOneWidget);
    await db.close();
  });

  testWidgets('filtering by category chip narrows the list', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final cats = [cat('c1', 'Comida'), cat('c2', 'Hospedagem')];
    final txs = [
      tx(id: '1', description: 'Jantar', amount: 100, categoryId: 'c1'),
      tx(id: '2', description: 'Hotel', amount: 200, categoryId: 'c2'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionsTab(
          db: db,
          txs: txs,
          catById: {for (final c in cats) c.id: c},
          cats: cats,
          cities: const {},
          currency: 'BRL',
        ),
      ),
    ));

    await tester.tap(find.widgetWithText(FilterChip, 'Comida'));
    await tester.pump();

    expect(find.text('Jantar'), findsOneWidget);
    expect(find.text('Hotel'), findsNothing);
    await db.close();
  });

  testWidgets('selecting rows and bulk-deleting removes them from the database', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    final id1 = await addTransaction(db, TransactionsTableCompanion.insert(
      id: '', tripId: tripId, period: 'DURING', description: 'Jantar', amount: 100,
      kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: '',
    ));
    final id2 = await addTransaction(db, TransactionsTableCompanion.insert(
      id: '', tripId: tripId, period: 'DURING', description: 'Hotel', amount: 200,
      kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: '',
    ));
    final txs = [
      tx(id: id1, description: 'Jantar', amount: 100),
      tx(id: id2, description: 'Hotel', amount: 200),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
      ),
    ));

    await tester.tap(find.text('Selecionar'));
    await tester.pump();
    expect(find.byType(Checkbox), findsNWidgets(2));

    await tester.tap(find.text('Jantar'));
    await tester.pump();
    expect(find.text('1 selecionadas'), findsOneWidget);

    await tester.tap(find.text('Excluir selecionadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    final remaining = await db.select(db.transactionsTable).get();
    expect(remaining.map((r) => r.id), [id2]);
    await db.close();
  });

  testWidgets('deleting a single row via its menu removes it after confirmation', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    final id1 = await addTransaction(db, TransactionsTableCompanion.insert(
      id: '', tripId: tripId, period: 'DURING', description: 'Jantar', amount: 100,
      kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: '',
    ));
    final txs = [tx(id: id1, description: 'Jantar', amount: 100)];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
      ),
    ));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    final remaining = await db.select(db.transactionsTable).get();
    expect(remaining, isEmpty);
    await db.close();
  });
}
