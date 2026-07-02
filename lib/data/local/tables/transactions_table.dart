import 'package:drift/drift.dart';

@DataClassName('Transaction')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get rawText => text()();
  TextColumn get intent => text()();
  TextColumn get category => text().nullable()();
  IntColumn get amount => integer().nullable()();
  TextColumn get account => text().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  RealColumn get confidence => real()();

  TextColumn get accountType => text().nullable()();
  TextColumn get accountName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
