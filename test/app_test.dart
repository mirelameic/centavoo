import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:centavoo/app.dart';
import 'package:centavoo/data/database.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows a loading indicator, then the router content once seeding finishes', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(CentavooApp(
      database: db,
      loadSeedJson: () async => '{"version":1,"categories":[],"rules":[],"trips":[],"transactions":[]}',
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Minhas viagens'), findsOneWidget);

    await db.close();
  });

  testWidgets('shows an error message when seeding fails', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(CentavooApp(
      database: db,
      loadSeedJson: () async => throw Exception('boom'),
    ));

    await tester.pumpAndSettle();

    expect(find.textContaining('boom'), findsOneWidget);

    await db.close();
  });

  testWidgets('loads a previously saved language preference on startup', (tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(CentavooApp(
      database: db,
      loadSeedJson: () async => '{"version":1,"categories":[],"rules":[],"trips":[],"transactions":[]}',
    ));

    await tester.pumpAndSettle();

    expect(find.text('My trips'), findsOneWidget);
    expect(find.text('Minhas viagens'), findsNothing);

    await db.close();
  });

  testWidgets('loads a previously saved theme mode on startup', (tester) async {
    SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(CentavooApp(
      database: db,
      loadSeedJson: () async => '{"version":1,"categories":[],"rules":[],"trips":[],"transactions":[]}',
    ));

    await tester.pumpAndSettle();

    final context = tester.element(find.text('Minhas viagens'));
    expect(Theme.of(context).brightness, Brightness.dark);

    await db.close();
  });
}
