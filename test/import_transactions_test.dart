import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/mappers.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/models/category_rule.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/widgets/trip/import_transactions.dart';

Future<void> openImport(
  WidgetTester tester,
  AppDatabase db, {
  required String tripId,
  List<CategoryRule> rules = const [],
}) async {
  final tripRow = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingle();
  final catRows = await (db.select(db.categoriesTable)..where((c) => c.tripId.equals(tripId))).get();

  await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
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
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
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

    await tester.enterText(
      find.byType(TextField).first,
      '12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00',
    );
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Uber'), findsWidgets);
    expect(find.text('Padaria'), findsWidgets);
    expect(find.text('45.90'), findsOneWidget);
    expect(find.text('2 linhas prontas para importar'), findsOneWidget);
    await db.close();
  });

  testWidgets('a header row is auto-detected and excluded from the preview', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await openImport(tester, db, tripId: tripId);

    await tester.enterText(
      find.byType(TextField).first,
      'data\tdescricao\tvalor\n12/03/2026\tUber\t45,90',
    );
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

    await tester.enterText(
      find.byType(TextField).first,
      '12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\tabc',
    );
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

    await tester.enterText(
      find.byType(TextField).first,
      '12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00',
    );
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

    await tester.enterText(
      find.byType(TextField).first,
      '12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00',
    );
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

    await tester.enterText(
      find.byType(TextField).first,
      '12/03/2026\tUber\t45,90\n13/03/2026\tPadaria\t12,00',
    );
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
}
