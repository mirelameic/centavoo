import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:centavoo/data/tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [TripsTable, CategoriesTable, TransactionsTable, CategoryRulesTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(driftDatabase(
          name: 'centavoo',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}
