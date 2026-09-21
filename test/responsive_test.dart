import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/trip.dart' as model;
import 'package:centavoo/screens/categories_screen.dart';
import 'package:centavoo/screens/trip/transactions_tab.dart';
import 'package:centavoo/screens/trips_screen.dart';
import 'package:centavoo/widgets/category_form.dart';
import 'package:centavoo/widgets/trip/trip_edit_form.dart';
import 'package:centavoo/widgets/trip/transaction_form.dart';

import 'transactions_tab_test.dart' show tx, cat;

const _narrowWidth = 360.0;

void _useNarrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(_narrowWidth, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('pt', 'BR'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('fits a 360px-wide phone screen without overflowing', () {
    testWidgets('Trips screen, empty state', (tester) async {
      _useNarrowPhone(tester);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await tester.pumpWidget(Provider<AppDatabase>.value(value: db, child: _wrap(const TripsScreen())));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await db.close();
    });

    testWidgets('Trips screen, with a trip card (long name, destination and amount)', (tester) async {
      _useNarrowPhone(tester);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final tripId = await createTrip(
        db,
        name: 'Viagem incrível de aniversário de trinta anos',
        destination: 'Rio de Janeiro, Brasil',
        startDate: '2026-05-17',
        endDate: '2026-06-03',
      );
      await addTransaction(db, TransactionsTableCompanion.insert(
        id: '', tripId: tripId, period: 'DURING', description: 'Hotel', amount: 123456.78,
        kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: '',
      ));

      await tester.pumpWidget(Provider<AppDatabase>.value(value: db, child: _wrap(const TripsScreen())));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await db.close();
    });

    testWidgets('New trip dialog opens and its add button is reachable', (tester) async {
      _useNarrowPhone(tester);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await tester.pumpWidget(Provider<AppDatabase>.value(value: db, child: _wrap(const TripsScreen())));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      await db.close();
    });

    testWidgets('Categories screen header with title and add button', (tester) async {
      _useNarrowPhone(tester);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final tripId = await createTrip(db, name: 'Japan');

      await tester.pumpWidget(Provider<AppDatabase>.value(value: db, child: _wrap(CategoriesScreen(tripId: tripId))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await db.close();
    });

    testWidgets('Categories screen list row with a very long category name', (tester) async {
      _useNarrowPhone(tester);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final tripId = await createTrip(db, name: 'Japan');
      await addCategory(db, tripId: tripId, name: 'Uma categoria com um nome extremamente longo e detalhado', color: '#0E8C6B');

      await tester.pumpWidget(Provider<AppDatabase>.value(value: db, child: _wrap(CategoriesScreen(tripId: tripId))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await db.close();
    });

    testWidgets('Trip edit dialog', (tester) async {
      _useNarrowPhone(tester);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final trip = model.Trip(
        id: 't1', name: 'Japan', destination: null, startDate: null, endDate: null,
        currency: 'BRL', cities: const {}, createdAt: '2026-01-01T00:00:00Z',
      );

      await tester.pumpWidget(_wrap(TripEditForm(db: db, trip: trip)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await db.close();
    });

    testWidgets('Category form dialog', (tester) async {
      _useNarrowPhone(tester);
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      await tester.pumpWidget(_wrap(CategoryForm(db: db, tripId: 't1')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await db.close();
    });

    testWidgets('Transaction form dialog with several categories', (tester) async {
      _useNarrowPhone(tester);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final trip = model.Trip(
        id: 't1', name: 'Japan', destination: null, startDate: '2026-01-01', endDate: '2026-01-10',
        currency: 'BRL', cities: const {}, createdAt: '2026-01-01T00:00:00Z',
      );
      final categories = [
        Category(id: 'c1', tripId: 't1', name: 'Transporte', color: '#0E8C6B', sortOrder: 0),
        Category(id: 'c2', tripId: 't1', name: 'Alimentação', color: '#C2540D', sortOrder: 1),
      ];

      await tester.pumpWidget(_wrap(TransactionForm(db: db, trip: trip, categories: categories, rules: const [])));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await db.close();
    });

    testWidgets('Transactions tab sort row and select-mode row', (tester) async {
      _useNarrowPhone(tester);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final txs = [
        tx(id: '1', description: 'Jantar', amount: 100, date: '2026-01-01'),
        tx(id: '2', description: 'Hotel', amount: 200, date: '2026-01-02'),
      ];
      final cats = [cat('c1', 'Transporte')];

      await tester.pumpWidget(_wrap(CustomScrollView(slivers: [
        TransactionsTab(db: db, txs: txs, catById: {'c1': cats[0]}, cats: cats, cities: const {}, currency: 'BRL'),
      ])));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Selecionar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(Checkbox).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await db.close();
    });
  });
}
