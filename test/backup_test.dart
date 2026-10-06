import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/data/backup.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/data/seed.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('exportBackupJson includes every table with the right envelope', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', destination: 'Tokyo');
    final catId = await addCategory(db, tripId: tripId, name: 'Comida', color: '#0E8C6B');
    await addTransaction(
      db,
      TransactionsTableCompanion.insert(
        id: '',
        tripId: tripId,
        period: 'DURING',
        description: 'Sushi',
        amount: 50,
        categoryId: Value(catId),
        kind: 'EXPENSE',
        isIof: false,
        splitCount: 1,
        createdAt: '',
      ),
    );

    final json = await exportBackupJson(db);
    final decoded = jsonDecode(json) as Map<String, dynamic>;

    expect(decoded['app'], 'centavoo');
    expect(decoded['version'], 1);
    expect(decoded['exportedAt'], isNotNull);
    expect((decoded['trips'] as List), hasLength(1));
    expect((decoded['categories'] as List), contains(containsPair('name', 'Comida')));
    expect((decoded['transactions'] as List), hasLength(1));
    expect(decoded['trips'][0]['name'], 'Japan');
    await db.close();
  });

  test('importBackupJson restores every table into an empty database', () async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(source, name: 'Japan', destination: 'Tokyo');
    final catId = await addCategory(source, tripId: tripId, name: 'Comida', color: '#0E8C6B');
    await addTransaction(
      source,
      TransactionsTableCompanion.insert(
        id: '',
        tripId: tripId,
        period: 'DURING',
        description: 'Sushi',
        amount: 50,
        categoryId: Value(catId),
        kind: 'EXPENSE',
        isIof: false,
        splitCount: 1,
        createdAt: '',
      ),
    );
    final categoryCount = (await source.select(source.categoriesTable).get()).length;
    final json = await exportBackupJson(source);
    await source.close();

    final target = AppDatabase.forTesting(NativeDatabase.memory());
    final result = await importBackupJson(target, json);

    expect(result.trips, 1);
    expect(result.categories, categoryCount);
    expect(result.transactions, 1);

    final trips = await target.select(target.tripsTable).get();
    expect(trips, hasLength(1));
    expect(trips.first.name, 'Japan');
    final txs = await target.select(target.transactionsTable).get();
    expect(txs, hasLength(1));
    expect(txs.first.description, 'Sushi');
    await target.close();
  });

  test('importBackupJson overwrites existing rows with the same id', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan');
    final json = await exportBackupJson(db);

    await updateTripDetails(db, tripId, name: 'Renamed locally');

    await importBackupJson(db, json);

    final trip = await (db.select(db.tripsTable)..where((t) => t.id.equals(tripId))).getSingle();
    expect(trip.name, 'Japan');
    await db.close();
  });

  test('importBackupJson throws on a file with no transactions field', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(() => importBackupJson(db, jsonEncode({'app': 'centavoo'})), throwsFormatException);
    await db.close();
  });

  test('importBackupJson throws on invalid JSON text', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(() => importBackupJson(db, 'not json'), throwsFormatException);
    await db.close();
  });

  test('importBackupJson accepts an older backup with dropped columns and rules without a category name', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final legacy = jsonEncode({
      'app': 'centavoo',
      'version': 1,
      'trips': [
        {
          'id': 't1',
          'name': 'Europa',
          'destination': null,
          'startDate': '2026-05-17',
          'endDate': '2026-06-03',
          'currency': 'BRL',
          'notes': 'old',
          'citiesJson': '{}',
          'cityListJson': null,
          'createdAt': '2026-01-01',
          'sortOrder': 0,
        },
      ],
      'categories': [
        {'id': 'c1', 'tripId': 't1', 'name': 'Alimentação', 'color': '#C1352E', 'icon': 'food', 'sortOrder': 0},
      ],
      'transactions': [
        {
          'id': 'x1',
          'tripId': 't1',
          'period': 'DURING',
          'date': '2026-05-17',
          'description': 'Café',
          'amount': 12.5,
          'categoryId': 'c1',
          'kind': 'EXPENSE',
          'isIof': false,
          'splitCount': 1,
          'city': 'SP',
          'rawText': 'Café',
          'createdAt': '2026-01-01',
        },
      ],
      'rules': [
        {'id': 1, 'keyword': 'café', 'categoryId': 'c1', 'priority': 10},
      ],
    });

    final result = await importBackupJson(db, legacy);

    expect(result.transactions, 1);
    final rule = await db.select(db.categoryRulesTable).getSingle();
    expect(rule.categoryName, 'Alimentação');
    await db.close();
  });

  test('scripts/europa-backup.json restores exactly what the bundled Europa seed produces', () async {
    SharedPreferences.setMockInitialValues({});
    final seeded = AppDatabase.forTesting(NativeDatabase.memory());
    await ensureSeeded(seeded, loadJson: () => File('assets/europa.json').readAsString());

    final imported = AppDatabase.forTesting(NativeDatabase.memory());
    final result = await importBackupJson(imported, File('scripts/europa-backup.json').readAsStringSync());
    expect(result.trips, 1);
    expect(result.categories, 10);
    expect(result.transactions, 217);
    expect(result.rules, 68);

    Future<Map<String, List<Map<String, dynamic>>>> dump(AppDatabase db) async {
      List<Map<String, dynamic>> sorted(List<Map<String, dynamic>> rows) =>
          rows..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
      return {
        'trips': sorted((await db.select(db.tripsTable).get()).map((r) => r.toJson()).toList()),
        'categories': sorted((await db.select(db.categoriesTable).get()).map((r) => r.toJson()).toList()),
        'transactions': sorted((await db.select(db.transactionsTable).get()).map((r) => r.toJson()).toList()),
        'rules': sorted((await db.select(db.categoryRulesTable).get()).map((r) => r.toJson()).toList()),
      };
    }

    expect(await dump(imported), await dump(seeded));
    await seeded.close();
    await imported.close();
  });
}
