import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/mappers.dart';
import 'package:centavoo/data/repo.dart';
import 'package:drift/drift.dart' show Value;
import 'package:centavoo/models/category_rule.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/widgets/trip/import_transactions.dart';

import 'helpers.dart';

Future<void> openImport(
  WidgetTester tester,
  AppDatabase db, {
  required String tripId,
  List<CategoryRule> rules = const [],
}) async {
  final txRows = await (db.select(db.transactionsTable)..where((t) => t.tripId.equals(tripId))).get();
  final tripRow = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingle();
  final catRows = await (db.select(db.categoriesTable)..where((c) => c.tripId.equals(tripId))).get();

  await tester.pumpWidget(
    ptApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => ImportTransactions(
                db: db,
                trip: tripFromRow(tripRow),
                categories: catRows.map(categoryFromRow).toList(),
                rules: rules,
                existing: txRows.map(transactionFromRow).toList(),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the paste step fits on a phone-sized screen without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openImport(tester, db, tripId: tripId);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.upload_file), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Ou escolher um arquivo (.csv)'), findsOneWidget);

    final buttonSize = tester.getSize(find.byType(OutlinedButton));
    expect(buttonSize.width, greaterThan(20));
    await db.close();
  });

  testWidgets('pasting two valid rows and continuing shows both in the preview', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openImport(tester, db, tripId: tripId);

    await tester.enterText(find.byType(TextField).first, '12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Uber'), findsWidgets);
    expect(find.text('Padaria'), findsWidgets);
    expect(find.text('R\$ 45,90'), findsOneWidget);
    expect(find.text('2 linhas prontas para importar'), findsOneWidget);
    await db.close();
  });

  testWidgets('a header row is auto-detected and excluded from the preview', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openImport(tester, db, tripId: tripId);

    await tester.enterText(find.byType(TextField).first, 'data\tdescricao\tvalor\n12/03/2026\tUber\t45,90');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Uber'), findsWidgets);
    expect(find.text('descricao'), findsNothing);
    expect(find.text('1 linhas prontas para importar'), findsOneWidget);
    await db.close();
  });

  testWidgets('a row with an invalid amount is flagged and excluded from the ready count', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openImport(tester, db, tripId: tripId);

    await tester.enterText(find.byType(TextField).first, '12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\tabc');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('valor inválido'), findsOneWidget);
    expect(find.text('1 linhas prontas para importar · 1 com problema (não serão importadas)'), findsOneWidget);
    await db.close();
  });

  testWidgets('unchecking a valid row excludes it from the ready count', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openImport(tester, db, tripId: tripId);

    await tester.enterText(find.byType(TextField).first, '12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('2 linhas prontas para importar'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('1 linhas prontas para importar'), findsOneWidget);
    await db.close();
  });

  testWidgets('a description matching a category rule is auto-suggested', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    final catId = await addCategory(db, tripId: tripId, name: 'Transporte', color: '#B8860B');
    final rules = [CategoryRule(keyword: 'uber', categoryId: catId, priority: 1)];
    await openImport(tester, db, tripId: tripId, rules: rules);

    await tester.enterText(find.byType(TextField).first, '12/03/2026\tUber\t45,90');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Transporte'), findsOneWidget);
    await db.close();
  });

  testWidgets('a negative amount is treated as a refund and shows the IOF checkbox', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openImport(tester, db, tripId: tripId);

    await tester.enterText(find.byType(TextField).first, '12/03/2026\tEstorno hotel\t-45,90');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Reembolso'), findsOneWidget);
    expect(find.text('Reembolso de IOF'), findsOneWidget);
    await db.close();
  });

  testWidgets('confirming the import inserts every valid row into the database', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openImport(tester, db, tripId: tripId);

    await tester.enterText(find.byType(TextField).first, '12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Importar (2)'));
    await tester.pumpAndSettle();

    final txs = await (db.select(db.transactionsTable)..where((t) => t.tripId.equals(tripId))).get();
    expect(txs, hasLength(2));
    expect(txs.map((t) => t.description).toSet(), {'Uber', 'Padaria'});
    expect(txs.every((t) => t.kind == kindExpense), isTrue);
    await db.close();
  });

  testWidgets('an excluded row is not imported', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openImport(tester, db, tripId: tripId);

    await tester.enterText(find.byType(TextField).first, '12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Importar (1)'));
    await tester.pumpAndSettle();

    final txs = await (db.select(db.transactionsTable)..where((t) => t.tripId.equals(tripId))).get();
    expect(txs, hasLength(1));
    expect(txs.first.description, 'Padaria');
    await db.close();
  });

  testWidgets('the Voltar button returns to the paste step', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openImport(tester, db, tripId: tripId);

    await tester.enterText(find.byType(TextField).first, '12/03/2026\tUber\t45,90');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Cole os dados aqui'), findsOneWidget);
    await db.close();
  });

  Finder rowCheckbox(String description) => find.descendant(
    of: find.ancestor(of: find.text(description), matching: find.byType(Row)).first,
    matching: find.byType(Checkbox),
  );

  Future<void> pasteAndContinue(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }

  testWidgets('a rule pointing at another trip suggests the category with the same name in this trip', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    final rules = [
      CategoryRule(keyword: 'uber', categoryId: 'cat_from_other_trip', categoryName: 'Transporte', priority: 1),
    ];
    await openImport(tester, db, tripId: tripId, rules: rules);

    await pasteAndContinue(tester, '12/03/2026\tUber\t45,90');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Importar (1)'));
    await tester.pumpAndSettle();

    final tx = await (db.select(db.transactionsTable)..where((t) => t.tripId.equals(tripId))).getSingle();
    final cat = await (db.select(db.categoriesTable)..where((c) => c.id.equals(tx.categoryId!))).getSingle();
    expect(cat.tripId, tripId);
    expect(cat.name, 'Transporte');
    await db.close();
  });

  testWidgets('choosing "—" clears a suggested category instead of reverting to the suggestion', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    final catId = await addCategory(db, tripId: tripId, name: 'Mobilidade', color: '#B8860B');
    final rules = [CategoryRule(keyword: 'uber', categoryId: catId, priority: 1)];
    await openImport(tester, db, tripId: tripId, rules: rules);

    await pasteAndContinue(tester, '12/03/2026\tUber\t45,90');
    expect(find.text('Mobilidade'), findsOneWidget);

    await tester.tap(find.text('Mobilidade'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('—').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('—').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Importar (1)'));
    await tester.pumpAndSettle();
    final tx = await (db.select(db.transactionsTable)..where((t) => t.tripId.equals(tripId))).getSingle();
    expect(tx.categoryId, isNull);
    await db.close();
  });

  testWidgets('toggling the header checkbox keeps an excluded row excluded', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openImport(tester, db, tripId: tripId);

    await pasteAndContinue(tester, '12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00\n14/03/2026\tMuseu\t30,00');
    expect(find.text('3 linhas prontas para importar'), findsOneWidget);

    await tester.tap(rowCheckbox('Padaria'));
    await tester.pumpAndSettle();
    expect(find.text('2 linhas prontas para importar'), findsOneWidget);

    await tester.tap(find.text('A primeira linha é um cabeçalho'));
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(rowCheckbox('Padaria')).value, isFalse);
    expect(tester.widget<Checkbox>(rowCheckbox('Museu')).value, isTrue);
    expect(find.text('1 linhas prontas para importar'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Importar (1)'));
    await tester.pumpAndSettle();
    final txs = await (db.select(db.transactionsTable)..where((t) => t.tripId.equals(tripId))).get();
    expect(txs.map((t) => t.description), ['Museu']);
    await db.close();
  });

  testWidgets('rows already in the trip are flagged and unchecked by default, but can be re-included', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await addTransaction(
      db,
      TransactionsTableCompanion.insert(
        id: '',
        tripId: tripId,
        period: 'DURING',
        date: const Value('2026-03-12'),
        description: 'UBER',
        amount: 45.9,
        kind: kindExpense,
        isIof: false,
        splitCount: 1,
        createdAt: '',
      ),
    );
    await openImport(tester, db, tripId: tripId);

    await pasteAndContinue(tester, '12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00');

    expect(find.text('já importada'), findsOneWidget);
    expect(tester.widget<Checkbox>(rowCheckbox('Uber')).value, isFalse);
    expect(find.text('1 linhas prontas para importar · 1 já importadas (desmarcadas)'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Importar (1)'));
    await tester.pumpAndSettle();
    var txs = await (db.select(db.transactionsTable)..where((t) => t.tripId.equals(tripId))).get();
    expect(txs, hasLength(2));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await pasteAndContinue(tester, '12/03/2026\tUber\t45,90');
    await tester.tap(rowCheckbox('Uber'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Importar (1)'));
    await tester.pumpAndSettle();
    txs = await (db.select(db.transactionsTable)..where((t) => t.tripId.equals(tripId))).get();
    expect(txs, hasLength(3));
    await db.close();
  });
}
