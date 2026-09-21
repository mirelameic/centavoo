import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:centavoo/data/database.dart';

class ImportResult {
  final int trips;
  final int categories;
  final int transactions;
  final int rules;

  const ImportResult({
    required this.trips,
    required this.categories,
    required this.transactions,
    required this.rules,
  });
}

Future<String> exportBackupJson(AppDatabase db) async {
  final trips = await db.select(db.tripsTable).get();
  final categories = await db.select(db.categoriesTable).get();
  final transactions = await db.select(db.transactionsTable).get();
  final rules = await db.select(db.categoryRulesTable).get();

  return jsonEncode({
    'app': 'centavoo',
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'trips': trips.map((t) => t.toJson()).toList(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'transactions': transactions.map((t) => t.toJson()).toList(),
    'rules': rules.map((r) => r.toJson()).toList(),
  });
}

Future<ImportResult> importBackupJson(AppDatabase db, String jsonStr) async {
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonStr);
  } on FormatException {
    throw const FormatException('Invalid backup file');
  }
  if (decoded is! Map || decoded['transactions'] is! List) {
    throw const FormatException('Invalid backup file');
  }

  final tripsJson = decoded['trips'];
  final categoriesJson = decoded['categories'];
  final rulesJson = decoded['rules'];

  final trips = tripsJson is List
      ? tripsJson.map((j) => TripRow.fromJson(Map<String, dynamic>.from(j as Map))).toList()
      : const <TripRow>[];
  final categories = categoriesJson is List
      ? categoriesJson.map((j) => CategoryRow.fromJson(Map<String, dynamic>.from(j as Map))).toList()
      : const <CategoryRow>[];
  final transactions = (decoded['transactions'] as List)
      .map((j) => TransactionRow.fromJson(Map<String, dynamic>.from(j as Map)))
      .toList();
  final rules = rulesJson is List
      ? rulesJson.map((j) => CategoryRuleRow.fromJson(Map<String, dynamic>.from(j as Map))).toList()
      : const <CategoryRuleRow>[];

  await db.transaction(() async {
    if (categories.isNotEmpty) {
      await db.batch((b) => b.insertAll(db.categoriesTable, categories, mode: InsertMode.insertOrReplace));
    }
    if (trips.isNotEmpty) {
      await db.batch((b) => b.insertAll(db.tripsTable, trips, mode: InsertMode.insertOrReplace));
    }
    if (transactions.isNotEmpty) {
      await db.batch((b) => b.insertAll(db.transactionsTable, transactions, mode: InsertMode.insertOrReplace));
    }
    if (rules.isNotEmpty) {
      await db.batch((b) => b.insertAll(db.categoryRulesTable, rules, mode: InsertMode.insertOrReplace));
    }
  });

  return ImportResult(
    trips: trips.length,
    categories: categories.length,
    transactions: transactions.length,
    rules: rules.length,
  );
}
