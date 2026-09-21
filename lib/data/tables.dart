import 'package:drift/drift.dart';

@DataClassName('TripRow')
class TripsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get destination => text().nullable()();
  TextColumn get startDate => text().nullable()();
  TextColumn get endDate => text().nullable()();
  TextColumn get currency => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get citiesJson => text().withDefault(const Constant('{}'))();
  TextColumn get cityListJson => text().nullable()();
  TextColumn get createdAt => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryRow')
@TableIndex(name: 'idx_categories_trip_sort', columns: {#tripId, #sortOrder})
class CategoriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get name => text()();
  TextColumn get color => text()();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransactionRow')
@TableIndex(name: 'idx_transactions_trip_period', columns: {#tripId, #period})
class TransactionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get period => text()();
  TextColumn get date => text().nullable()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get kind => text()();
  BoolColumn get isIof => boolean()();
  IntColumn get splitCount => integer()();
  TextColumn get city => text().nullable()();
  TextColumn get rawText => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryRuleRow')
class CategoryRulesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get keyword => text()();
  TextColumn get categoryId => text()();
  IntColumn get priority => integer()();
}
