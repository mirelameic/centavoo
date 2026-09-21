import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/mappers.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/models/category_rule.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/widgets/trip/transaction_form.dart';

Future<void> openForm(
  WidgetTester tester,
  AppDatabase db, {
  required String tripId,
  List<CategoryRule> rules = const [],
  Transaction? editing,
}) async {
  final tripRow = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingle();
  final catRows = await (db.select(db.categoriesTable)..where((c) => c.tripId.equals(tripId))).get();

  await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => TransactionForm(
            db: db,
            trip: tripFromRow(tripRow),
            categories: catRows.map(categoryFromRow).toList(),
            rules: rules,
            editing: editing,
          ),
        ),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('the save button is disabled until description and a positive amount are set', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openForm(tester, db, tripId: tripId);

    expect(find.text('Nova transação'), findsOneWidget);
    final saveButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Salvar'));
    expect(saveButton.onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Jantar');
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '50');
    await tester.pump();

    final saveButtonAfter = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Salvar'));
    expect(saveButtonAfter.onPressed, isNotNull);
    await db.close();
  });

  testWidgets('saving a new expense inserts it with the entered fields', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', startDate: '2026-05-17');
    await openForm(tester, db, tripId: tripId);

    await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Jantar');
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '50');
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final txs = await db.select(db.transactionsTable).get();
    expect(txs, hasLength(1));
    expect(txs.first.description, 'Jantar');
    expect(txs.first.amount, 50);
    expect(txs.first.kind, kindExpense);
    expect(txs.first.period, periodDuring);
    await db.close();
  });

  testWidgets('saving an amount typed with a full pt-BR thousand separator works', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', startDate: '2026-05-17');
    await openForm(tester, db, tripId: tripId);

    await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Passagem aérea');
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '1.500,50');
    await tester.pump();

    final saveButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Salvar'));
    expect(saveButton.onPressed, isNotNull);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final txs = await db.select(db.transactionsTable).get();
    expect(txs.first.amount, 1500.5);
    await db.close();
  });

  testWidgets('choosing refund negates the amount and shows the IOF checkbox', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openForm(tester, db, tripId: tripId);

    await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Estorno');
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '20');
    await tester.pump();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Gasto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reembolso').last);
    await tester.pumpAndSettle();

    expect(find.text('Reembolso de IOF'), findsOneWidget);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final txs = await db.select(db.transactionsTable).get();
    expect(txs.first.amount, -20);
    expect(txs.first.kind, kindRefund);
    await db.close();
  });

  testWidgets('typing a description matching a category rule auto-suggests that category', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    final catId = await addCategory(db, tripId: tripId, name: 'Comida', color: '#0E8C6B');
    final rules = [CategoryRule(keyword: 'jantar', categoryId: catId, priority: 1)];

    await openForm(tester, db, tripId: tripId, rules: rules);

    await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Jantar no restaurante');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Comida'), findsOneWidget);
    await db.close();
  });

  testWidgets('toggling the IOF checkbox persists isIof on save', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openForm(tester, db, tripId: tripId);

    await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Estorno IOF');
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '15');
    await tester.pump();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Gasto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reembolso').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reembolso de IOF'));
    await tester.pump();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final txs = await db.select(db.transactionsTable).get();
    expect(txs.first.isIof, isTrue);
    await db.close();
  });

  testWidgets('selecting a category from the dropdown persists it on save', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    final catId = await addCategory(db, tripId: tripId, name: 'Transporte', color: '#B8860B');
    await openForm(tester, db, tripId: tripId);

    await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Uber');
    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '25');
    await tester.pump();

    await tester.ensureVisible(find.widgetWithText(DropdownButtonFormField<String?>, '—'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, '—'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Transporte').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transporte').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final txs = await db.select(db.transactionsTable).get();
    expect(txs.first.categoryId, catId);
    await db.close();
  });

  testWidgets('editing an existing transaction pre-fills the fields and updates it on save', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    final id = await addTransaction(db, TransactionsTableCompanion.insert(
      id: '', tripId: tripId, period: 'DURING', description: 'Almoço', amount: 30,
      kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: '',
    ));
    final row = await (db.select(db.transactionsTable)..where((t) => t.id.equals(id))).getSingle();

    await openForm(tester, db, tripId: tripId, editing: transactionFromRow(row));

    expect(find.text('Editar transação'), findsOneWidget);
    expect(find.text('Almoço'), findsOneWidget);
    expect(find.text('30.00'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Descrição'), 'Jantar');
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final updated = await (db.select(db.transactionsTable)..where((t) => t.id.equals(id))).getSingle();
    expect(updated.description, 'Jantar');
    await db.close();
  });
}
