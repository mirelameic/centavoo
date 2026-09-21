import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/screens/trip/transactions_tab.dart';
import 'package:centavoo/widgets/trip/tx_row.dart';

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

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(
        body: CustomScrollView(slivers: [
          TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
        ]),
      ),
    ));

    expect(find.text('2 resultado(s) · R\$ 300,00'), findsOneWidget);
    expect(find.text('Jantar'), findsOneWidget);
    expect(find.text('Hotel'), findsOneWidget);
    await db.close();
  });

  testWidgets('only builds the visible rows out of a large transaction list (virtualized)', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final txs = [
      for (var i = 0; i < 300; i++) tx(id: '$i', description: 'Item $i', amount: 10),
    ];

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomScrollView(slivers: [
          TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
        ]),
      ),
    ));

    final builtRows = find.byType(TxRow).evaluate().length;
    expect(builtRows, greaterThan(0));
    expect(builtRows, lessThan(txs.length));
    await db.close();
  });

  testWidgets('filtering by city chip narrows the list', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final txs = [
      tx(id: '1', description: 'Jantar', amount: 100, date: '2026-05-01'),
      tx(id: '2', description: 'Hotel', amount: 200, date: '2026-05-02'),
    ];
    final cities = {'2026-05-01': 'Lisboa', '2026-05-02': 'Porto'};

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomScrollView(slivers: [
          TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: cities, currency: 'BRL'),
        ]),
      ),
    ));

    await tester.tap(find.widgetWithText(FilterChip, 'Lisboa'));
    await tester.pump();

    expect(find.text('Jantar'), findsOneWidget);
    expect(find.text('Hotel'), findsNothing);
    await db.close();
  });

  testWidgets('filtering by period segment narrows to before or during', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final txs = [
      tx(id: '1', description: 'TxAntes', amount: 50, period: periodBefore),
      tx(id: '2', description: 'TxDurante', amount: 100, period: periodDuring),
    ];

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomScrollView(slivers: [
          TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
        ]),
      ),
    ));

    await tester.tap(find.descendant(
      of: find.byType(SegmentedButton<String?>),
      matching: find.text('Antes'),
    ));
    await tester.pump();

    expect(find.text('TxAntes'), findsOneWidget);
    expect(find.text('TxDurante'), findsNothing);
    await db.close();
  });

  testWidgets('clear filters button resets the search and shows every transaction again', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final txs = [
      tx(id: '1', description: 'Jantar', amount: 100),
      tx(id: '2', description: 'Hotel', amount: 200),
    ];

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomScrollView(slivers: [
          TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
        ]),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'jan');
    await tester.pump();
    expect(find.text('Hotel'), findsNothing);

    await tester.tap(find.text('Limpar filtros'));
    await tester.pump();

    expect(find.text('Jantar'), findsOneWidget);
    expect(find.text('Hotel'), findsOneWidget);
    await db.close();
  });

  testWidgets('sorting by amount and toggling the direction reorders the rows', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final txs = [
      tx(id: '1', description: 'Barato', amount: 50, date: '2026-05-01'),
      tx(id: '2', description: 'Caro', amount: 500, date: '2026-05-02'),
    ];

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomScrollView(slivers: [
          TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
        ]),
      ),
    ));

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valor'));
    await tester.pumpAndSettle();

    var baratoPos = tester.getTopLeft(find.text('Barato'));
    var caroPos = tester.getTopLeft(find.text('Caro'));
    expect(baratoPos.dy, lessThan(caroPos.dy));

    await tester.tap(find.byTooltip('toggle-sort-direction'));
    await tester.pump();

    baratoPos = tester.getTopLeft(find.text('Barato'));
    caroPos = tester.getTopLeft(find.text('Caro'));
    expect(caroPos.dy, lessThan(baratoPos.dy));
    await db.close();
  });

  testWidgets('selecting all rows and clearing the selection', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final txs = [
      tx(id: '1', description: 'Jantar', amount: 100),
      tx(id: '2', description: 'Hotel', amount: 200),
    ];

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomScrollView(slivers: [
          TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
        ]),
      ),
    ));

    await tester.tap(find.text('Selecionar'));
    await tester.pump();
    await tester.tap(find.text('Selecionar todos'));
    await tester.pump();

    expect(find.text('2 selecionadas'), findsOneWidget);

    await tester.tap(find.text('Limpar seleção'));
    await tester.pump();

    expect(find.text('0 selecionadas'), findsOneWidget);
    await db.close();
  });

  testWidgets('tapping a selected row again deselects it', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final txs = [
      tx(id: '1', description: 'Jantar', amount: 100),
      tx(id: '2', description: 'Hotel', amount: 200),
    ];

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CustomScrollView(slivers: [
          TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
        ]),
      ),
    ));

    await tester.tap(find.text('Selecionar'));
    await tester.pump();
    await tester.tap(find.text('Jantar'));
    await tester.pump();
    expect(find.text('1 selecionadas'), findsOneWidget);

    await tester.tap(find.text('Jantar'));
    await tester.pump();
    expect(find.text('0 selecionadas'), findsOneWidget);
    await db.close();
  });

  testWidgets('typing in the search box filters by description', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final txs = [
      tx(id: '1', description: 'Jantar', amount: 100),
      tx(id: '2', description: 'Hotel', amount: 200),
    ];

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(
        body: CustomScrollView(slivers: [
          TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
        ]),
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

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(
        body: CustomScrollView(slivers: [
          TransactionsTab(
            db: db,
            txs: txs,
            catById: {for (final c in cats) c.id: c},
            cats: cats,
            cities: const {},
            currency: 'BRL',
          ),
        ]),
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

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(
        body: CustomScrollView(slivers: [
          TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
        ]),
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

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(
        body: CustomScrollView(slivers: [
          TransactionsTab(db: db, txs: txs, catById: const {}, cats: const [], cities: const {}, currency: 'BRL'),
        ]),
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
