import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/seed.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> loadRealEuropaJson() => File('assets/europa.json').readAsString();

  test('seeds an empty database on first run', () async {
    final seeded = await ensureSeeded(db, loadJson: loadRealEuropaJson);
    expect(seeded, true);
    final trips = await db.select(db.tripsTable).get();
    expect(trips, hasLength(1));
    final transactions = await db.select(db.transactionsTable).get();
    expect(transactions, hasLength(217));
  });

  test('does not reseed on a second call at the same version', () async {
    await ensureSeeded(db, loadJson: loadRealEuropaJson);
    final seededAgain = await ensureSeeded(db, loadJson: loadRealEuropaJson);
    expect(seededAgain, false);
    final transactions = await db.select(db.transactionsTable).get();
    expect(transactions, hasLength(217));
  });

  test('reseeds when the bundled version number increases', () async {
    await ensureSeeded(db, loadJson: loadRealEuropaJson);
    Future<String> loadBumpedVersion() async {
      final raw = jsonDecode(await loadRealEuropaJson()) as Map<String, dynamic>;
      raw['version'] = (raw['version'] as int) + 1;
      return jsonEncode(raw);
    }
    final seededAgain = await ensureSeeded(db, loadJson: loadBumpedVersion);
    expect(seededAgain, true);
  });
}
