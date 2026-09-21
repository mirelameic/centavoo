import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/widgets/trip/city_editor.dart';

Future<AppDatabase> pump(
  WidgetTester tester, {
  required String tripId,
  required List<String> days,
  required Map<String, String> cities,
  List<String>? cityList,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CityEditor(db: db, tripId: tripId, days: days, cities: cities, cityList: cityList),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return db;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('shows the empty state and unassigned day count when no city is assigned', (tester) async {
    final tripId = 't1';
    final db = await pump(tester, tripId: tripId, days: ['2026-05-17', '2026-05-18'], cities: const {});
    expect(find.text('Nenhum período definido ainda.'), findsOneWidget);
    expect(find.text('2 dia(s) sem cidade'), findsOneWidget);
    await db.close();
  });

  testWidgets('shows city chips derived from assigned days when no cityList is stored', (tester) async {
    final db = await pump(
      tester,
      tripId: 't1',
      days: ['2026-05-17', '2026-05-18'],
      cities: {'2026-05-17': 'Lisboa', '2026-05-18': 'Porto'},
    );
    expect(find.text('Lisboa'), findsWidgets);
    expect(find.text('Porto'), findsWidgets);
    await db.close();
  });

  testWidgets('shows a block card with the date range and day count', (tester) async {
    final db = await pump(
      tester,
      tripId: 't1',
      days: ['2026-05-17', '2026-05-18', '2026-05-19'],
      cities: {'2026-05-17': 'Lisboa', '2026-05-18': 'Lisboa'},
    );
    expect(find.textContaining('17 de mai. – 18 de mai.'), findsOneWidget);
    expect(find.textContaining('2 dia(s)'), findsOneWidget);
    expect(find.text('1 dia(s) sem cidade'), findsOneWidget);
    await db.close();
  });

  testWidgets('typing and confirming a new city persists it via updateTripCityList', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CityEditor(db: db, tripId: tripId, days: const [], cities: const {}, cityList: const ['Lisboa']),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar cidade'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Porto');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingle();
    expect(jsonDecode(trip.cityListJson!), ['Lisboa', 'Porto']);
    await db.close();
  });

  testWidgets('removing a city with no assigned days updates the list without a confirm dialog', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await updateTripCityList(db, tripId, ['Lisboa', 'Porto']);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CityEditor(db: db, tripId: tripId, days: const [], cities: const {}, cityList: const ['Lisboa', 'Porto']),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remover Porto'));
    await tester.pumpAndSettle();

    final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingle();
    expect(jsonDecode(trip.cityListJson!), ['Lisboa']);
    await db.close();
  });

  testWidgets('editing an existing block pre-fills the form and saving moves the range', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await setTripCityRange(db, tripId, ['2026-05-17', '2026-05-18'], 'Lisboa');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CityEditor(
            db: db,
            tripId: tripId,
            days: const ['2026-05-17', '2026-05-18'],
            cities: const {'2026-05-17': 'Lisboa', '2026-05-18': 'Lisboa'},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('edit-city-block'));
    await tester.pumpAndSettle();

    expect(find.text('Salvar'), findsOneWidget);
    expect(find.text('17 de mai. – 18 de mai.'), findsWidgets);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingle();
    expect(jsonDecode(trip.citiesJson), {'2026-05-17': 'Lisboa', '2026-05-18': 'Lisboa'});
    await db.close();
  });

  testWidgets('deleting a block clears its days after confirmation', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await setTripCityRange(db, tripId, ['2026-05-17'], 'Lisboa');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CityEditor(
          db: db,
          tripId: tripId,
          days: const ['2026-05-17'],
          cities: const {'2026-05-17': 'Lisboa'},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('delete-city-block'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingle();
    expect(jsonDecode(trip.citiesJson), {});
    await db.close();
  });
}
