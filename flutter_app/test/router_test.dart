import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/theme_controller.dart';
import 'package:centavoo/locale_controller.dart';
import 'package:centavoo/router.dart';

Future<AppDatabase> pumpAt(WidgetTester tester, String location, {AppDatabase? db}) async {
  db ??= AppDatabase.forTesting(NativeDatabase.memory());
  final router = buildRouter();
  router.go(location);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
        ChangeNotifierProvider<LocaleController>(create: (_) => LocaleController()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('/ shows the Trips screen inside the shared shell', (tester) async {
    final db = await pumpAt(tester, '/');
    expect(find.text('CENTAVOO'), findsOneWidget);
    expect(find.text('Minhas viagens'), findsOneWidget);
    await db.close();
  });

  testWidgets('/trip/:id shows the Trip screen for the tripId from the URL', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Europa 2025');
    await pumpAt(tester, '/trip/$tripId', db: db);
    expect(find.text('CENTAVOO'), findsOneWidget);
    expect(find.text('Europa 2025'), findsOneWidget);
    await db.close();
  });

  testWidgets('/trip/:id shows a not-found message for an unknown tripId', (tester) async {
    final db = await pumpAt(tester, '/trip/does-not-exist');
    expect(find.text('CENTAVOO'), findsOneWidget);
    expect(find.text('Viagem não encontrada.'), findsOneWidget);
    await db.close();
  });

  testWidgets('/trip/:id/categories shows the Categories screen for the tripId from the URL', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Europa 2025');
    await addCategory(db, tripId: tripId, name: 'Cinema', color: '#0E8C6B');
    await pumpAt(tester, '/trip/$tripId/categories', db: db);
    expect(find.text('CENTAVOO'), findsOneWidget);
    expect(find.text('Categorias'), findsOneWidget);
    expect(find.text('Cinema'), findsOneWidget);
    await db.close();
  });
}
