import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('inserts and reads back a trip', () async {
    await db.into(db.tripsTable).insert(TripsTableCompanion.insert(
          id: 't1',
          name: 'Japan',
          currency: 'BRL',
          createdAt: '2026-01-01T00:00:00Z',
        ));
    final rows = await db.select(db.tripsTable).get();
    expect(rows, hasLength(1));
    expect(rows.first.name, 'Japan');
    expect(rows.first.citiesJson, '{}');
  });

  test('categories table enforces no uniqueness beyond primary key, so two trips can each have their own rows', () async {
    await db.into(db.categoriesTable).insert(CategoriesTableCompanion.insert(
          id: 'c1', tripId: 't1', name: 'Food', color: '#fff', sortOrder: 0,
        ));
    await db.into(db.categoriesTable).insert(CategoriesTableCompanion.insert(
          id: 'c2', tripId: 't2', name: 'Food', color: '#fff', sortOrder: 0,
        ));
    final rows = await db.select(db.categoriesTable).get();
    expect(rows, hasLength(2));
  });

  test('categoryRules id auto-increments', () async {
    final id1 = await db.into(db.categoryRulesTable).insert(
          CategoryRulesTableCompanion.insert(keyword: 'sushi', categoryId: 'c1', priority: 1),
        );
    final id2 = await db.into(db.categoryRulesTable).insert(
          CategoryRulesTableCompanion.insert(keyword: 'ramen', categoryId: 'c1', priority: 1),
        );
    expect(id2, greaterThan(id1));
  });
}
