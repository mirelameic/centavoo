import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:centavoo/data/tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [TripsTable, CategoriesTable, TransactionsTable, CategoryRulesTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'centavoo',
              web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js')),
            ),
      );
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  Future<void> backfillRuleCategoryNames() async {
    await customUpdate(
      'UPDATE category_rules_table SET category_name = '
      '(SELECT name FROM categories_table WHERE categories_table.id = category_rules_table.category_id) '
      'WHERE category_name IS NULL',
      updates: {categoryRulesTable},
    );
  }
}
