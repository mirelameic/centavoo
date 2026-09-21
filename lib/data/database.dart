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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(tripsTable, tripsTable.sortOrder);
            final rows = await (select(tripsTable)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
            for (var i = 0; i < rows.length; i++) {
              await (update(tripsTable)..where((t) => t.id.equals(rows[i].id)))
                  .write(TripsTableCompanion(sortOrder: Value(i)));
            }
          }
        },
      );
}
