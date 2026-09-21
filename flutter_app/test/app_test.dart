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
}
