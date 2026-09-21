import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/data/backup.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';

void main() {
  test('exportBackupJson includes every table with the right envelope', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final tripId = await createTrip(db, name: 'Japan', destination: 'Tokyo');
    final catId = await addCategory(db, tripId: tripId, name: 'Comida', color: '#0E8C6B');
    await addTransaction(db, TransactionsTableCompanion.insert(
      id: '', tripId: tripId, period: 'DURING', description: 'Sushi', amount: 50,
      categoryId: Value(catId), kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: '',
    ));

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
    await addTransaction(source, TransactionsTableCompanion.insert(
      id: '', tripId: tripId, period: 'DURING', description: 'Sushi', amount: 50,
      categoryId: Value(catId), kind: 'EXPENSE', isIof: false, splitCount: 1, createdAt: '',
    ));
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
    expect(
      () => importBackupJson(db, jsonEncode({'app': 'centavoo'})),
      throwsFormatException,
    );
    await db.close();
  });

  test('importBackupJson throws on invalid JSON text', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(() => importBackupJson(db, 'not json'), throwsFormatException);
    await db.close();
  });
}
