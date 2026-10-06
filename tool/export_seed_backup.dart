import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/data/backup.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/seed.dart';

const seedBackupPath = 'scripts/europa-backup.json';

void main() {
  test('export the Europa seed as an importable backup file', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await applySeed(db, jsonDecode(File('assets/europa.json').readAsStringSync()) as Map<String, dynamic>);
    final json = jsonDecode(await exportBackupJson(db)) as Map<String, dynamic>;
    File(seedBackupPath).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(json)}\n');
    await db.close();
  });
}
