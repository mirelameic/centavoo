import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
      child: const MaterialApp(locale: Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: TripsScreen()),
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
      Provider<AppDatabase>.value(value: db, child: const MaterialApp(locale: Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: TripsScreen())),
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

  testWidgets('creating a trip with a destination persists it', (tester) async {
    final db = await pump(tester);

    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'ex. Europa 2025'), 'Europa 2026');
    await tester.enterText(find.widgetWithText(TextField, 'ex. Espanha · Grécia'), 'Portugal');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Criar'));
    await tester.pumpAndSettle();

    final trips = await db.select(db.tripsTable).get();
    final created = trips.firstWhere((t) => t.name == 'Europa 2026');
    expect(created.destination, 'Portugal');
    await db.close();
  });

  testWidgets('the empty state button opens the new trip dialog', (tester) async {
    final db = await pump(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Criar a primeira'));
    await tester.pumpAndSettle();

    expect(find.text('Nova viagem'), findsOneWidget);
    await db.close();
  });

  testWidgets('tapping a trip card navigates to that trip', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', startDate: '2026-05-17', endDate: '2026-06-03');

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const TripsScreen()),
        GoRoute(path: '/trip/:id', builder: (context, state) => const Scaffold(body: Text('trip screen'))),
      ],
    );

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: MaterialApp.router(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Japan'));
    await tester.pump();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/trip/$tripId');
    await db.close();
  });

  testWidgets('long-pressing a trip card shows the actions menu', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await createTrip(db, name: 'Japan');

    await tester.pumpWidget(
      Provider<AppDatabase>.value(value: db, child: const MaterialApp(locale: Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: TripsScreen())),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Japan'));
    await tester.pumpAndSettle();

    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);
    expect(find.text('Mover para cima'), findsOneWidget);
    expect(find.text('Mover para baixo'), findsOneWidget);
    await db.close();
  });

  testWidgets('the move-up option is disabled for the first trip and move-down for the last', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await createTrip(db, name: 'Trip 1');
    await createTrip(db, name: 'Trip 2');
    // Displayed order is [Trip 2, Trip 1] (newest first).

    await tester.pumpWidget(
      Provider<AppDatabase>.value(value: db, child: const MaterialApp(locale: Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: TripsScreen())),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Trip 2'));
    await tester.pumpAndSettle();
    final moveUpTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Mover para cima'));
    expect(moveUpTile.enabled, isFalse);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Trip 1'));
    await tester.pumpAndSettle();
    final moveDownTile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Mover para baixo'));
    expect(moveDownTile.enabled, isFalse);
    await db.close();
  });

  testWidgets('moving a trip up reorders the list', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await createTrip(db, name: 'Trip 1');
    await createTrip(db, name: 'Trip 2');
    // Displayed order is [Trip 2, Trip 1] (newest first).

    await tester.pumpWidget(
      Provider<AppDatabase>.value(value: db, child: const MaterialApp(locale: Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: TripsScreen())),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Trip 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover para cima'));
    await tester.pumpAndSettle();

    final trips = await (db.select(db.tripsTable)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
    expect(trips.map((t) => t.name).toList(), ['Trip 1', 'Trip 2']);
    await db.close();
  });

  testWidgets('editing a trip from the actions menu opens the edit dialog', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await createTrip(db, name: 'Japan');

    await tester.pumpWidget(
      Provider<AppDatabase>.value(value: db, child: const MaterialApp(locale: Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: TripsScreen())),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Japan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Editar viagem'), findsOneWidget);
    await db.close();
  });

  testWidgets('deleting a trip from the actions menu removes it after confirmation', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await createTrip(db, name: 'Japan');

    await tester.pumpWidget(
      Provider<AppDatabase>.value(value: db, child: const MaterialApp(locale: Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: TripsScreen())),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Japan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Japan'), findsNothing);
    final trips = await db.select(db.tripsTable).get();
    expect(trips, isEmpty);
    await db.close();
  });
}
