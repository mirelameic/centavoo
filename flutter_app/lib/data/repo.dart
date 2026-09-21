import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/models/transaction.dart' show periodBefore, periodDuring;

class DefaultCategory {
  final String name;
  final String color;
  final String icon;
  const DefaultCategory(this.name, this.color, this.icon);
}

const defaultCategories = [
  DefaultCategory('Hospedagem', '#0E8C6B', 'bed'),
  DefaultCategory('Passagem', '#B8860B', 'plane'),
  DefaultCategory('Transporte', '#C2540D', 'car'),
  DefaultCategory('Alimentação', '#C1352E', 'food'),
  DefaultCategory('Compras', '#B23368', 'shopping'),
  DefaultCategory('Brindes', '#7D1F44', 'gift'),
  DefaultCategory('Turismo', '#8A7220', 'ticket'),
  DefaultCategory('Genéricos de viagem', '#7A4A2A', 'luggage'),
  DefaultCategory('Outros', '#5C5650', 'bookmark'),
];

String _newId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(Object())}';

Future<String> createTrip(
  AppDatabase db, {
  required String name,
  String? destination,
  String? startDate,
  String? endDate,
  String currency = 'BRL',
  String? notes,
}) async {
  final id = _newId('trip');
  await db.into(db.tripsTable).insert(TripsTableCompanion.insert(
        id: id,
        name: name,
        destination: Value(destination),
        startDate: Value(startDate),
        endDate: Value(endDate),
        currency: currency,
        notes: Value(notes),
        createdAt: DateTime.now().toIso8601String(),
      ));
  await db.batch((batch) {
    batch.insertAll(db.categoriesTable, [
      for (var i = 0; i < defaultCategories.length; i++)
        CategoriesTableCompanion.insert(
          id: _newId('cat_$i'),
          tripId: id,
          name: defaultCategories[i].name,
          color: defaultCategories[i].color,
          icon: Value(defaultCategories[i].icon),
          sortOrder: i,
        ),
    ]);
  });
  return id;
}

Future<void> deleteTrip(AppDatabase db, String id) async {
  await db.transaction(() async {
    final catIds = await (db.selectOnly(db.categoriesTable)
          ..addColumns([db.categoriesTable.id])
          ..where(db.categoriesTable.tripId.equals(id)))
        .map((row) => row.read(db.categoriesTable.id)!)
        .get();
    if (catIds.isNotEmpty) {
      await (db.delete(db.categoryRulesTable)..where((r) => r.categoryId.isIn(catIds))).go();
    }
    await (db.delete(db.transactionsTable)..where((t) => t.tripId.equals(id))).go();
    await (db.delete(db.categoriesTable)..where((c) => c.tripId.equals(id))).go();
    await (db.delete(db.tripsTable)..where((t) => t.id.equals(id))).go();
  });
}

Future<void> setTripCityRange(AppDatabase db, String tripId, List<String> days, String city) async {
  final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingleOrNull();
  if (trip == null) return;
  final cities = Map<String, String>.from(jsonDecode(trip.citiesJson) as Map);
  final v = city.trim();
  for (final d in days) {
    if (v.isNotEmpty) {
      cities[d] = v;
    } else {
      cities.remove(d);
    }
  }
  await (db.update(db.tripsTable)..where((t) => t.id.equals(tripId)))
      .write(TripsTableCompanion(citiesJson: Value(jsonEncode(cities))));
}

Future<void> updateTripDetails(
  AppDatabase db,
  String tripId, {
  required String name,
  String? destination,
  String? startDate,
  String? endDate,
}) async {
  await (db.update(db.tripsTable)..where((t) => t.id.equals(tripId))).write(
    TripsTableCompanion(
      name: Value(name),
      destination: Value(destination),
      startDate: Value(startDate),
      endDate: Value(endDate),
    ),
  );
}

Future<void> updateTransaction(AppDatabase db, String id, TransactionsTableCompanion patch) async {
  await (db.update(db.transactionsTable)..where((t) => t.id.equals(id))).write(patch);
}

Future<void> updateTripCityList(AppDatabase db, String tripId, List<String> cityList) async {
  await (db.update(db.tripsTable)..where((t) => t.id.equals(tripId)))
      .write(TripsTableCompanion(cityListJson: Value(jsonEncode(cityList))));
}

Future<String> addTransaction(AppDatabase db, TransactionsTableCompanion data) async {
  final id = _newId('tx');
  await db.into(db.transactionsTable).insert(
        data.copyWith(id: Value(id), createdAt: Value(DateTime.now().toIso8601String())),
      );
  return id;
}

Future<List<String>> bulkAddTransactions(AppDatabase db, List<TransactionsTableCompanion> rows) async {
  final createdAt = DateTime.now().toIso8601String();
  final ids = [for (var i = 0; i < rows.length; i++) _newId('tx_$i')];
  await db.batch((batch) {
    batch.insertAll(db.transactionsTable, [
      for (var i = 0; i < rows.length; i++)
        rows[i].copyWith(id: Value(ids[i]), createdAt: Value(createdAt)),
    ]);
  });
  return ids;
}

Future<void> deleteTransaction(AppDatabase db, String id) async {
  await (db.delete(db.transactionsTable)..where((t) => t.id.equals(id))).go();
}

Future<void> deleteTransactions(AppDatabase db, List<String> ids) async {
  await (db.delete(db.transactionsTable)..where((t) => t.id.isIn(ids))).go();
}

String? _periodForDate(String? date, String startDate) {
  if (date == null) return null;
  return date.compareTo(startDate) < 0 ? periodBefore : periodDuring;
}

Future<void> reassignTransactionPeriods(AppDatabase db, String tripId, String? startDate) async {
  if (startDate == null) return;
  final rows = await (db.select(db.transactionsTable)..where((t) => t.tripId.equals(tripId))).get();
  await db.transaction(() async {
    for (final row in rows) {
      final period = _periodForDate(row.date, startDate);
      if (period != null && period != row.period) {
        await (db.update(db.transactionsTable)..where((t) => t.id.equals(row.id)))
            .write(TransactionsTableCompanion(period: Value(period)));
      }
    }
  });
}

Future<String> addCategory(
  AppDatabase db, {
  required String tripId,
  required String name,
  required String color,
  String? icon,
  int? sortOrder,
}) async {
  final id = _newId('cat');
  final existing = await (db.select(db.categoriesTable)..where((c) => c.tripId.equals(tripId))).get();
  final maxOrder = existing.fold<int>(-1, (m, c) => c.sortOrder > m ? c.sortOrder : m);
  await db.into(db.categoriesTable).insert(CategoriesTableCompanion.insert(
        id: id,
        tripId: tripId,
        name: name,
        color: color,
        icon: Value(icon),
        sortOrder: sortOrder ?? maxOrder + 1,
      ));
  return id;
}

Future<void> updateCategory(AppDatabase db, String id, CategoriesTableCompanion patch) async {
  await (db.update(db.categoriesTable)..where((c) => c.id.equals(id))).write(patch);
}

Future<void> deleteCategory(AppDatabase db, String id) async {
  await db.transaction(() async {
    await (db.update(db.transactionsTable)..where((t) => t.categoryId.equals(id)))
        .write(const TransactionsTableCompanion(categoryId: Value(null)));
    await (db.delete(db.categoryRulesTable)..where((r) => r.categoryId.equals(id))).go();
    await (db.delete(db.categoriesTable)..where((c) => c.id.equals(id))).go();
  });
}
