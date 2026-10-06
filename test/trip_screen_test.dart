import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/screens/trip_screen.dart';

import 'helpers.dart';

Future<AppDatabase> pumpTrip(WidgetTester tester, String tripId) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await tester.pumpWidget(
    Provider<AppDatabase>.value(
      value: db,
      child: ptApp(
        home: Scaffold(body: TripScreen(tripId: tripId)),
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

  testWidgets('shows a not-found message for an unknown trip id', (tester) async {
    final db = await pumpTrip(tester, 'does-not-exist');
    expect(find.text('Viagem não encontrada.'), findsOneWidget);
    await db.close();
  });

  testWidgets('shows trip name, destination, dates and KPI values', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(
      db,
      name: 'Japan',
      destination: 'Tokyo',
      startDate: '2026-05-17',
      endDate: '2026-06-03',
    );
    await addTransaction(
      db,
      TransactionsTableCompanion.insert(
        id: '',
        tripId: tripId,
        period: 'DURING',
        description: 'Sushi',
        amount: 50,
        kind: 'EXPENSE',
        isIof: false,
        splitCount: 1,
        createdAt: '',
      ),
    );

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: ptApp(
          home: Scaffold(body: TripScreen(tripId: tripId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Japan'), findsOneWidget);
    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.textContaining('17 de mai.'), findsOneWidget);
    expect(find.text('LÍQUIDO'), findsOneWidget);
    expect(find.text('R\$ 50,00'), findsWidgets);

    await db.close();
  });

  testWidgets('a very long trip name does not overflow the header', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final longName = 'Viagem incrível de aniversário de trinta anos com a família toda em setembro';
    final tripId = await createTrip(db, name: longName, startDate: '2026-05-17', endDate: '2026-06-03');

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: ptApp(
          home: Scaffold(body: TripScreen(tripId: tripId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
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
      Provider<AppDatabase>.value(
        value: db,
        child: ptApp(
          home: Scaffold(body: TripScreen(tripId: tripId)),
        ),
      ),
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

  testWidgets('the system back gesture closes an open tab instead of leaving the trip screen', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', startDate: '2026-05-17', endDate: '2026-06-03');

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: ptApp(
          home: Scaffold(body: TripScreen(tripId: tripId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resumo'));
    await tester.pumpAndSettle();
    expect(find.text('LÍQUIDO'), findsNothing);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    final popped = await navigator.maybePop();
    await tester.pumpAndSettle();

    expect(popped, isTrue);
    expect(find.text('LÍQUIDO'), findsOneWidget);
    expect(find.byType(TripScreen), findsOneWidget);

    await db.close();
  });

  testWidgets('tapping each tab in the desktop tab row shows that tab\'s content', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', startDate: '2026-05-17', endDate: '2026-06-03');

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: ptApp(
          home: Scaffold(body: TripScreen(tripId: tripId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Ranking'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma transação ainda.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tempo'));
    await tester.pumpAndSettle();
    expect(find.text('Por dia'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Cidades'));
    await tester.pumpAndSettle();
    expect(find.text('Filtrar por categoria'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Categorias'));
    await tester.pumpAndSettle();
    expect(find.text('Resumo por categoria'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Transações'));
    await tester.pumpAndSettle();
    expect(find.text('Selecionar'), findsOneWidget);

    await db.close();
  });

  testWidgets('tapping the edit icon on the trip header opens the trip edit dialog', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', startDate: '2026-05-17', endDate: '2026-06-03');

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: ptApp(
          home: Scaffold(body: TripScreen(tripId: tripId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('edit-trip'));
    await tester.pumpAndSettle();

    expect(find.text('Editar viagem'), findsOneWidget);
    await db.close();
  });

  testWidgets('tapping "Nova transação" opens the transaction form for a new transaction', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', startDate: '2026-05-17', endDate: '2026-06-03');

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: ptApp(
          home: Scaffold(body: TripScreen(tripId: tripId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Nova transação'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Descrição'), findsOneWidget);
    await db.close();
  });

  testWidgets('tapping "Categorias" navigates to the categories route', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', startDate: '2026-05-17', endDate: '2026-06-03');

    final router = GoRouter(
      initialLocation: '/trip/$tripId',
      routes: [
        GoRoute(
          path: '/trip/:id',
          builder: (context, state) => Scaffold(body: TripScreen(tripId: tripId)),
        ),
        GoRoute(
          path: '/trip/:id/categories',
          builder: (context, state) => const Scaffold(body: Text('categories screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: ptRouterApp(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Categorias'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.matches.last.matchedLocation, '/trip/$tripId/categories');
    expect(router.canPop(), isTrue);
    await db.close();
  });

  testWidgets('tapping "← Viagens" pops back to the trips list instead of resetting the stack', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', startDate: '2026-05-17', endDate: '2026-06-03');

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('trips screen')),
        ),
        GoRoute(
          path: '/trip/:id',
          builder: (context, state) => Scaffold(body: TripScreen(tripId: tripId)),
        ),
      ],
    );

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: ptRouterApp(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/trip/$tripId');
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);

    await tester.tap(find.text('Viagens'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
    expect(router.canPop(), isFalse);
    await db.close();
  });

  testWidgets('uncategorized spend is labelled in the app language and avg/day spans the whole trip', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', startDate: '2026-05-17', endDate: '2026-05-26');
    await addTransaction(
      db,
      TransactionsTableCompanion.insert(
        id: '',
        tripId: tripId,
        period: 'DURING',
        date: const Value('2026-05-18'),
        description: 'Sushi',
        amount: 100,
        kind: 'EXPENSE',
        isIof: false,
        splitCount: 1,
        createdAt: '',
      ),
    );

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: ptApp(
          home: Scaffold(body: TripScreen(tripId: tripId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('R\$ 10,00'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Resumo'));
    await tester.pumpAndSettle();
    expect(find.text('Sem categoria'), findsOneWidget);
    expect(find.text('No category'), findsNothing);
    await db.close();
  });

  testWidgets('KPI values use the trip currency symbol', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Paris', currency: 'EUR');
    await addTransaction(
      db,
      TransactionsTableCompanion.insert(
        id: '',
        tripId: tripId,
        period: 'DURING',
        description: 'Croissant',
        amount: 4.5,
        kind: 'EXPENSE',
        isIof: false,
        splitCount: 1,
        createdAt: '',
      ),
    );

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: ptApp(
          home: Scaffold(body: TripScreen(tripId: tripId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('€ 4,50'), findsWidgets);
    await db.close();
  });

  testWidgets('shows IOF refunds in their own KPI card, without overflowing on a phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    await addTransaction(
      db,
      TransactionsTableCompanion.insert(
        id: '',
        tripId: tripId,
        period: 'DURING',
        description: 'Hotel',
        amount: 500,
        kind: 'EXPENSE',
        isIof: false,
        splitCount: 1,
        createdAt: '',
      ),
    );
    await addTransaction(
      db,
      TransactionsTableCompanion.insert(
        id: '',
        tripId: tripId,
        period: 'DURING',
        description: 'IOF Hotel',
        amount: -17.5,
        kind: 'REFUND',
        isIof: true,
        splitCount: 1,
        createdAt: '',
      ),
    );
    await addTransaction(
      db,
      TransactionsTableCompanion.insert(
        id: '',
        tripId: tripId,
        period: 'DURING',
        description: 'Estorno',
        amount: -40,
        kind: 'REFUND',
        isIof: false,
        splitCount: 1,
        createdAt: '',
      ),
    );

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: ptApp(
          home: Scaffold(body: TripScreen(tripId: tripId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('REEMBOLSOS DE IOF'), findsOneWidget);
    expect(find.text('-R\$ 17,50'), findsOneWidget);
    expect(find.text('-R\$ 57,50'), findsOneWidget);
    await db.close();
  });

  testWidgets('on a wide screen the KPI cards are laid out as a row of 4 values and a row of 3 time metrics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: ptApp(
          home: Scaffold(body: TripScreen(tripId: tripId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(top('BRUTO'), top('LÍQUIDO'));
    expect(top('REEMBOLSOS DE IOF'), top('LÍQUIDO'));
    expect(top('ANTES'), greaterThan(top('LÍQUIDO')));
    expect(top('MÉDIA/DIA'), top('ANTES'));
    await db.close();
  });
}
