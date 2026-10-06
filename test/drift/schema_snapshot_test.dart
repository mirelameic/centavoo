import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/data/database.dart';

const _snapshotDir = 'drift_schemas/app_database';

int _latestSnapshotVersion() {
  final versions =
      Directory(_snapshotDir)
          .listSync()
          .map((f) => RegExp(r'drift_schema_v(\d+)\.json$').firstMatch(f.path)?.group(1))
          .whereType<String>()
          .map(int.parse)
          .toList()
        ..sort();
  return versions.last;
}

Future<List<String>> _schemaSql(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY name")
      .get();
  return rows.map((r) => r.read<String>('sql')).toList();
}

void main() {
  test('schemaVersion matches the newest saved schema snapshot', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, _latestSnapshotVersion());
    await db.close();
  });

  test('the newest schema snapshot matches the tables defined in code', () async {
    final version = _latestSnapshotVersion();
    final snapshot =
        jsonDecode(File('$_snapshotDir/drift_schema_v$version.json').readAsStringSync()) as Map<String, dynamic>;
    final statements = [
      for (final entity in snapshot['fixed_sql'] as List)
        for (final sql in entity['sql'] as List)
          if (sql['dialect'] == 'sqlite') sql['sql'] as String,
    ];

    final fromSnapshot = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          for (final sql in statements) {
            raw.execute(sql);
          }
          raw.execute('PRAGMA user_version = $version');
        },
      ),
    );
    final fromCode = AppDatabase(NativeDatabase.memory());

    expect(await _schemaSql(fromCode), await _schemaSql(fromSnapshot));
    await fromSnapshot.close();
    await fromCode.close();
  });
}
