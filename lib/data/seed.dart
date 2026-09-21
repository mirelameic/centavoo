import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:centavoo/data/database.dart';

const _seedVersionKey = 'seedVersion';

Future<void> _applySeed(AppDatabase db, Map<String, dynamic> data) async {
  await db.transaction(() async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.categoriesTable, [
        for (final c in data['categories'] as List)
          CategoriesTableCompanion.insert(
            id: c['id'], tripId: c['tripId'], name: c['name'], color: c['color'],
            icon: Value(c['icon']), sortOrder: c['sortOrder'],
          ),
      ]);
      batch.insertAllOnConflictUpdate(db.tripsTable, [
        for (final t in data['trips'] as List)
          TripsTableCompanion.insert(
            id: t['id'], name: t['name'], destination: Value(t['destination']),
            startDate: Value(t['startDate']), endDate: Value(t['endDate']),
            currency: t['currency'],
            citiesJson: Value(jsonEncode(t['cities'] ?? {})),
            createdAt: t['createdAt'],
          ),
      ]);
      batch.insertAllOnConflictUpdate(db.transactionsTable, [
        for (final t in data['transactions'] as List)
          TransactionsTableCompanion.insert(
            id: t['id'], tripId: t['tripId'], period: t['period'],
            date: Value(t['date']), description: t['description'],
            amount: (t['amount'] as num).toDouble(), categoryId: Value(t['categoryId']),
            kind: t['kind'], isIof: t['isIof'], splitCount: t['splitCount'],
            createdAt: t['createdAt'],
          ),
      ]);
    });
    await db.delete(db.categoryRulesTable).go();
    await db.batch((batch) {
      batch.insertAll(db.categoryRulesTable, [
        for (final r in data['rules'] as List)
          CategoryRulesTableCompanion.insert(
            keyword: r['keyword'], categoryId: r['categoryId'], priority: r['priority'],
          ),
      ]);
    });
  });
}

Future<bool> ensureSeeded(AppDatabase db, {required Future<String> Function() loadJson}) async {
  final data = jsonDecode(await loadJson()) as Map<String, dynamic>;
  final prefs = await SharedPreferences.getInstance();
  final installed = prefs.getInt(_seedVersionKey) ?? 0;
  final tripCount = await db.select(db.tripsTable).get();
  final empty = tripCount.isEmpty;
  final version = data['version'] as int;
  if (empty || version > installed) {
    await _applySeed(db, data);
    await prefs.setInt(_seedVersionKey, version);
    return true;
  }
  return false;
}
