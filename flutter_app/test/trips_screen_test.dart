import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/screens/trips_screen.dart';

Future<AppDatabase> pump(WidgetTester tester) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await tester.pumpWidget(
    Provider<AppDatabase>.value(
      value: db,
      child: const MaterialApp(home: TripsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('shows the empty state when there are no trips', (tester) async {
    final db = await pump(tester);
    expect(find.text('Minhas viagens'), findsOneWidget);
    expect(find.text('Nenhuma viagem ainda.'), findsOneWidget);
    expect(find.text('Criar a primeira'), findsOneWidget);
    await db.close();
  });

  testWidgets('shows a trip card with name, destination, dates and net spend', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', destination: 'Tokyo', startDate: '2026-05-17', endDate: '2026-06-03');
    await addTransaction(db, TransactionsTableCompanion.insert(
      id: '', tripId: tripId, period: 'DURING', description: 'Sushi', amount: 50,
      kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: '',
    ));

    await tester.pumpWidget(
      Provider<AppDatabase>.value(value: db, child: const MaterialApp(home: TripsScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Japan'), findsOneWidget);
    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.textContaining('17 de mai.'), findsOneWidget);
    expect(find.text('GASTO LÍQUIDO'), findsOneWidget);
    expect(find.text('R\$ 50,00'), findsOneWidget);

    await db.close();
  });

  testWidgets('creating a trip through the dialog adds it to the list', (tester) async {
    final db = await pump(tester);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('Nova viagem'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'ex. Europa 2025'), 'Europa 2026');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Criar'));
    await tester.pumpAndSettle();

    expect(find.text('Europa 2026'), findsOneWidget);
    await db.close();
  });
}
