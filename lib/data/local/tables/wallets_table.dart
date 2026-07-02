import 'package:drift/drift.dart';

@DataClassName('Wallet')
class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // e.g. 'Dompet Utama', 'BCA', 'OVO'
  TextColumn get type => text()(); // e.g. 'CASH' or 'REKENING'
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
