import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/screens/trip_screen.dart';

Future<AppDatabase> pumpTrip(WidgetTester tester, String tripId) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await tester.pumpWidget(
    Provider<AppDatabase>.value(
      value: db,
      child: MaterialApp(home: Scaffold(body: TripScreen(tripId: tripId))),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('shows a not-found message for an unknown trip id', (tester) async {
    final db = await pumpTrip(tester, 'does-not-exist');
    expect(find.text('Viagem não encontrada.'), findsOneWidget);
    await db.close();
  });

  testWidgets('shows trip name, destination, dates and KPI values', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', destination: 'Tokyo', startDate: '2026-05-17', endDate: '2026-06-03');
    await addTransaction(db, TransactionsTableCompanion.insert(
      id: '', tripId: tripId, period: 'DURING', description: 'Sushi', amount: 50,
      kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: '',
    ));

    await tester.pumpWidget(
      Provider<AppDatabase>.value(value: db, child: MaterialApp(home: Scaffold(body: TripScreen(tripId: tripId)))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Japan'), findsOneWidget);
    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.textContaining('17 de mai.'), findsOneWidget);
    expect(find.text('LÍQUIDO'), findsOneWidget);
    expect(find.text('R\$ 50,00'), findsWidgets);

    await db.close();
  });

  testWidgets('tapping a tab hides the KPI grid and shows the tab content on a phone-sized screen', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', startDate: '2026-05-17', endDate: '2026-06-03');

    await tester.pumpWidget(
      Provider<AppDatabase>.value(value: db, child: MaterialApp(home: Scaffold(body: TripScreen(tripId: tripId)))),
    );
    await tester.pumpAndSettle();

    expect(find.text('LÍQUIDO'), findsOneWidget);

    await tester.tap(find.text('Resumo'));
    await tester.pumpAndSettle();

    expect(find.text('LÍQUIDO'), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('LÍQUIDO'), findsOneWidget);

    await db.close();
  });
}
