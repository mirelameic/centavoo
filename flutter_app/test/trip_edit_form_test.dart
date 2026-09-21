import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/mappers.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/widgets/trip/trip_edit_form.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('pre-fills the name, destination and date range from the trip', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', destination: 'Tokyo', startDate: '2026-05-17', endDate: '2026-06-03');
    final tripRow = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingle();

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDialog(context: context, builder: (_) => TripEditForm(db: db, trip: tripFromRow(tripRow))),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Japan'), findsOneWidget);
    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('17 de mai. – 03 de jun.'), findsOneWidget);
    await db.close();
  });

  testWidgets('saving updates the trip fields', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    final tripRow = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingle();

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDialog(context: context, builder: (_) => TripEditForm(db: db, trip: tripFromRow(tripRow))),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Europa');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingle();
    expect(trip.name, 'Europa');
    await db.close();
  });

  testWidgets('deleting the trip removes it and navigates back to the trips list', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    final tripRow = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingle();

    final router = GoRouter(
      initialLocation: '/trip/$tripId',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('trips list'))),
        GoRoute(
          path: '/trip/:id',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showDialog(context: context, builder: (_) => TripEditForm(db: db, trip: tripFromRow(tripRow))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Excluir viagem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('trips list'), findsOneWidget);
    final trips = await db.select(db.tripsTable).get();
    expect(trips, isEmpty);
    await db.close();
  });
}
