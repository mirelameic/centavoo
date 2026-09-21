import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('createTrip', () {
    test('creates the trip and seeds it with the default categories', () async {
      final id = await createTrip(db, name: 'Japan');
      final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(id))).getSingle();
      expect(trip.name, 'Japan');
      expect(trip.currency, 'BRL');
      expect(trip.citiesJson, '{}');

      final cats = await (db.select(db.categoriesTable)..where((c) => c.tripId.equals(id))).get();
      expect(cats, hasLength(defaultCategories.length));
      final byOrder = [...cats]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      expect(byOrder.map((c) => c.name).toList(), defaultCategories.map((c) => c.name).toList());
    });

    test('scopes seeded categories to this trip only', () async {
      final id1 = await createTrip(db, name: 'Trip 1');
      final id2 = await createTrip(db, name: 'Trip 2');
      final cats1 = await (db.select(db.categoriesTable)..where((c) => c.tripId.equals(id1))).get();
      final cats2 = await (db.select(db.categoriesTable)..where((c) => c.tripId.equals(id2))).get();
      expect(cats1.every((c) => c.tripId == id1), true);
      expect(cats2.every((c) => c.tripId == id2), true);
    });

    test('each new trip sorts before every existing one', () async {
      final id1 = await createTrip(db, name: 'Trip 1');
      final id2 = await createTrip(db, name: 'Trip 2');
      final id3 = await createTrip(db, name: 'Trip 3');

      final trips = await (db.select(db.tripsTable)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      expect(trips.map((t) => t.id).toList(), [id3, id2, id1]);
    });
  });

  group('reordering trips', () {
    test('moveTripUp swaps a trip with the one right before it', () async {
      final id1 = await createTrip(db, name: 'Trip 1');
      final id2 = await createTrip(db, name: 'Trip 2');
      final id3 = await createTrip(db, name: 'Trip 3');
      // Displayed order is [id3, id2, id1] (newest first).

      await moveTripUp(db, id2);

      final trips = await (db.select(db.tripsTable)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      expect(trips.map((t) => t.id).toList(), [id2, id3, id1]);
    });

    test('moveTripDown swaps a trip with the one right after it', () async {
      final id1 = await createTrip(db, name: 'Trip 1');
      final id2 = await createTrip(db, name: 'Trip 2');
      final id3 = await createTrip(db, name: 'Trip 3');
      // Displayed order is [id3, id2, id1] (newest first).

      await moveTripDown(db, id3);

      final trips = await (db.select(db.tripsTable)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      expect(trips.map((t) => t.id).toList(), [id2, id3, id1]);
    });

    test('moveTripUp on the first trip does nothing', () async {
      final id1 = await createTrip(db, name: 'Trip 1');
      final id2 = await createTrip(db, name: 'Trip 2');

      await moveTripUp(db, id2);

      final trips = await (db.select(db.tripsTable)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      expect(trips.map((t) => t.id).toList(), [id2, id1]);
    });

    test('moveTripDown on the last trip does nothing', () async {
      final id1 = await createTrip(db, name: 'Trip 1');
      final id2 = await createTrip(db, name: 'Trip 2');

      await moveTripDown(db, id1);

      final trips = await (db.select(db.tripsTable)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
      expect(trips.map((t) => t.id).toList(), [id2, id1]);
    });
  });

  group('deleteTrip', () {
    test('cascades: removes the trip, its categories, its transactions, and rules pointing at them', () async {
      final id = await createTrip(db, name: 'Japan');
      final cats = await (db.select(db.categoriesTable)..where((c) => c.tripId.equals(id))).get();
      final catId = cats.first.id;
      await db.into(db.transactionsTable).insert(TransactionsTableCompanion.insert(
            id: 'tx1', tripId: id, period: 'DURING', description: 'Sushi', amount: 50,
            categoryId: Value(catId), kind: 'EXPENSE', isIof: false, splitCount: 1,
            createdAt: '2026-01-01T00:00:00Z', date: const Value('2026-01-01'),
          ));
      await db.into(db.categoryRulesTable).insert(
            CategoryRulesTableCompanion.insert(keyword: 'sushi', categoryId: catId, priority: 1),
          );

      await deleteTrip(db, id);

      expect(await (db.select(db.tripsTable)..where((t) => t.id.equals(id))).getSingleOrNull(), isNull);
      expect(await (db.select(db.categoriesTable)..where((c) => c.tripId.equals(id))).get(), isEmpty);
      expect(await (db.select(db.transactionsTable)..where((t) => t.tripId.equals(id))).get(), isEmpty);
      expect(await (db.select(db.categoryRulesTable)..where((r) => r.categoryId.equals(catId))).get(), isEmpty);
    });

    test('leaves a different trip untouched', () async {
      final keepId = await createTrip(db, name: 'Keep me');
      final deleteId = await createTrip(db, name: 'Delete me');
      await deleteTrip(db, deleteId);
      expect(await (db.select(db.tripsTable)..where((t) => t.id.equals(keepId))).getSingleOrNull(), isNotNull);
      expect(await (db.select(db.categoriesTable)..where((c) => c.tripId.equals(keepId))).get(), hasLength(defaultCategories.length));
    });
  });

  group('setTripCityRange', () {
    test('sets the city for every day in the range at once', () async {
      final id = await createTrip(db, name: 'Japan');
      await setTripCityRange(db, id, ['2026-01-01', '2026-01-02', '2026-01-03'], 'Tokyo');
      final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(id))).getSingle();
      expect(jsonDecode(trip.citiesJson), {
        '2026-01-01': 'Tokyo',
        '2026-01-02': 'Tokyo',
        '2026-01-03': 'Tokyo',
      });
    });

    test('clears days when the city is an empty string', () async {
      final id = await createTrip(db, name: 'Japan');
      await setTripCityRange(db, id, ['2026-01-01', '2026-01-02'], 'Tokyo');
      await setTripCityRange(db, id, ['2026-01-01'], '');
      final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(id))).getSingle();
      expect(jsonDecode(trip.citiesJson), {'2026-01-02': 'Tokyo'});
    });

    test('does nothing when the trip does not exist', () async {
      await setTripCityRange(db, 'missing', ['2026-01-01'], 'Tokyo');
    });
  });

  group('updateCategory', () {
    test('updates the given fields on the category', () async {
      final tripId = await createTrip(db, name: 'Japan');
      final catId = await addCategory(db, tripId: tripId, name: 'Comida', color: '#000');
      await updateCategory(db, catId, CategoriesTableCompanion(name: const Value('Restaurante'), icon: const Value('food')));
      final cat = await (db.select(db.categoriesTable)..where((c) => c.id.equals(catId))).getSingle();
      expect(cat.name, 'Restaurante');
      expect(cat.icon, 'food');
      expect(cat.color, '#000');
    });
  });

  group('updateTripDetails', () {
    test('updates name, destination, and dates', () async {
      final id = await createTrip(db, name: 'Japan');
      await updateTripDetails(db, id, name: 'Europa', destination: 'Lisboa', startDate: '2026-05-17', endDate: '2026-06-03');
      final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(id))).getSingle();
      expect(trip.name, 'Europa');
      expect(trip.destination, 'Lisboa');
      expect(trip.startDate, '2026-05-17');
      expect(trip.endDate, '2026-06-03');
    });

    test('clears destination and dates when passed null', () async {
      final id = await createTrip(db, name: 'Japan', destination: 'Tokyo', startDate: '2026-01-01', endDate: '2026-01-10');
      await updateTripDetails(db, id, name: 'Japan');
      final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(id))).getSingle();
      expect(trip.destination, isNull);
      expect(trip.startDate, isNull);
      expect(trip.endDate, isNull);
    });
  });

  group('updateTransaction', () {
    test('updates the given fields on the transaction', () async {
      final tripId = await createTrip(db, name: 'Japan');
      final id = await addTransaction(db, TransactionsTableCompanion.insert(
        id: '', tripId: tripId, period: 'DURING', description: 'Ramen', amount: 20,
        kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: '',
      ));
      await updateTransaction(db, id, TransactionsTableCompanion(description: const Value('Sushi'), amount: const Value(30)));
      final tx = await (db.select(db.transactionsTable)..where((t) => t.id.equals(id))).getSingle();
      expect(tx.description, 'Sushi');
      expect(tx.amount, 30);
    });
  });

  group('updateTripCityList', () {
    test('stores the city list as JSON on the trip', () async {
      final id = await createTrip(db, name: 'Japan');
      await updateTripCityList(db, id, ['Tokyo', 'Kyoto']);
      final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(id))).getSingle();
      expect(jsonDecode(trip.cityListJson!), ['Tokyo', 'Kyoto']);
    });

    test('overwrites a previously stored city list', () async {
      final id = await createTrip(db, name: 'Japan');
      await updateTripCityList(db, id, ['Tokyo']);
      await updateTripCityList(db, id, ['Osaka', 'Nara']);
      final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(id))).getSingle();
      expect(jsonDecode(trip.cityListJson!), ['Osaka', 'Nara']);
    });
  });

  group('transactions', () {
    test('addTransaction assigns an id and createdAt', () async {
      final tripId = await createTrip(db, name: 'Japan');
      final id = await addTransaction(db, TransactionsTableCompanion.insert(
        id: '',
        tripId: tripId,
        period: 'DURING',
        date: const Value('2026-01-01'),
        description: 'Ramen',
        amount: 20,
        kind: 'EXPENSE',
        isIof: false,
        splitCount: 1,
        createdAt: '',
      ));
      final txRow = await (db.select(db.transactionsTable)..where((t) => t.id.equals(id))).getSingle();
      expect(txRow.description, 'Ramen');
      expect(txRow.createdAt, isNotEmpty);
    });

    test('bulkAddTransactions inserts every row and returns ids in the same order', () async {
      final tripId = await createTrip(db, name: 'Japan');
      final ids = await bulkAddTransactions(db, [
        TransactionsTableCompanion.insert(id: '', tripId: tripId, period: 'DURING', date: const Value('2026-01-01'), description: 'A', amount: 10, kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: ''),
        TransactionsTableCompanion.insert(id: '', tripId: tripId, period: 'DURING', date: const Value('2026-01-02'), description: 'B', amount: 20, kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: ''),
      ]);
      expect(ids, hasLength(2));
      final rows = await Future.wait(ids.map((id) => (db.select(db.transactionsTable)..where((t) => t.id.equals(id))).getSingle()));
      expect(rows.map((r) => r.description).toList(), ['A', 'B']);
    });

    test('deleteTransaction removes a single row', () async {
      final tripId = await createTrip(db, name: 'Japan');
      final id = await addTransaction(db, TransactionsTableCompanion.insert(id: '', tripId: tripId, period: 'DURING', date: const Value('2026-01-01'), description: 'A', amount: 10, kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: ''));
      await deleteTransaction(db, id);
      expect(await (db.select(db.transactionsTable)..where((t) => t.id.equals(id))).getSingleOrNull(), isNull);
    });

    test('deleteTransactions removes every listed row', () async {
      final tripId = await createTrip(db, name: 'Japan');
      final ids = await bulkAddTransactions(db, [
        TransactionsTableCompanion.insert(id: '', tripId: tripId, period: 'DURING', date: const Value('2026-01-01'), description: 'A', amount: 10, kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: ''),
        TransactionsTableCompanion.insert(id: '', tripId: tripId, period: 'DURING', date: const Value('2026-01-02'), description: 'B', amount: 20, kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: ''),
      ]);
      await deleteTransactions(db, ids);
      expect(await db.select(db.transactionsTable).get(), isEmpty);
    });
  });

  group('reassignTransactionPeriods', () {
    test('flips a transaction from during to before when the new start date moves past it', () async {
      final tripId = await createTrip(db, name: 'Japan', startDate: '2026-05-17', endDate: '2026-06-03');
      final duringId = await addTransaction(db, TransactionsTableCompanion.insert(id: '', tripId: tripId, period: 'DURING', date: const Value('2026-05-20'), description: 'A', amount: 10, kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: ''));
      final beforeId = await addTransaction(db, TransactionsTableCompanion.insert(id: '', tripId: tripId, period: 'BEFORE', date: const Value('2026-05-10'), description: 'B', amount: 20, kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: ''));
      final noDateId = await addTransaction(db, TransactionsTableCompanion.insert(id: '', tripId: tripId, period: 'DURING', description: 'C', amount: 5, kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: ''));

      await reassignTransactionPeriods(db, tripId, '2026-05-25');

      Future<String> periodOf(String id) async => (await (db.select(db.transactionsTable)..where((t) => t.id.equals(id))).getSingle()).period;
      expect(await periodOf(duringId), 'BEFORE');
      expect(await periodOf(beforeId), 'BEFORE');
      expect(await periodOf(noDateId), 'DURING');
    });

    test('does nothing when the new start date is null', () async {
      final tripId = await createTrip(db, name: 'Japan');
      final id = await addTransaction(db, TransactionsTableCompanion.insert(id: '', tripId: tripId, period: 'DURING', date: const Value('2026-05-20'), description: 'A', amount: 10, kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: ''));

      await reassignTransactionPeriods(db, tripId, null);

      final row = await (db.select(db.transactionsTable)..where((t) => t.id.equals(id))).getSingle();
      expect(row.period, 'DURING');
    });
  });

  group('addCategory', () {
    test('assigns the next sortOrder scoped to the trip, not globally', () async {
      final tripA = await createTrip(db, name: 'A');
      final tripB = await createTrip(db, name: 'B');
      final idA = await addCategory(db, tripId: tripA, name: 'Extra A', color: '#fff');
      final idB = await addCategory(db, tripId: tripB, name: 'Extra B', color: '#fff');
      final catA = await (db.select(db.categoriesTable)..where((c) => c.id.equals(idA))).getSingle();
      final catB = await (db.select(db.categoriesTable)..where((c) => c.id.equals(idB))).getSingle();
      expect(catA.sortOrder, defaultCategories.length);
      expect(catB.sortOrder, defaultCategories.length);
    });
  });

  group('deleteCategory', () {
    test('clears the reference on any transaction that used it, without deleting the transaction', () async {
      final tripId = await createTrip(db, name: 'Japan');
      final cats = await (db.select(db.categoriesTable)..where((c) => c.tripId.equals(tripId))).get();
      final catId = cats.first.id;
      final txId = await addTransaction(db, TransactionsTableCompanion.insert(id: '', tripId: tripId, period: 'DURING', date: const Value('2026-01-01'), description: 'A', amount: 10, categoryId: Value(catId), kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: ''));

      await deleteCategory(db, catId);

      expect(await (db.select(db.categoriesTable)..where((c) => c.id.equals(catId))).getSingleOrNull(), isNull);
      final txRow = await (db.select(db.transactionsTable)..where((t) => t.id.equals(txId))).getSingle();
      expect(txRow.categoryId, isNull);
    });

    test('removes any keyword rule pointing at the deleted category', () async {
      final tripId = await createTrip(db, name: 'Japan');
      final cats = await (db.select(db.categoriesTable)..where((c) => c.tripId.equals(tripId))).get();
      final catId = cats.first.id;
      await db.into(db.categoryRulesTable).insert(CategoryRulesTableCompanion.insert(keyword: 'ramen', categoryId: catId, priority: 1));

      await deleteCategory(db, catId);

      expect(await (db.select(db.categoryRulesTable)..where((r) => r.categoryId.equals(catId))).get(), isEmpty);
    });
  });
}
