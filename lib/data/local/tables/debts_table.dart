import 'package:drift/drift.dart';

@DataClassName('DebtData')
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  RealColumn get totalAmount => real()();
  RealColumn get remainingAmount => real().customConstraint('CHECK (remaining_amount >= 0) NOT NULL')();
  TextColumn get type => text()(); // Mapped to DebtType: 'debt' or 'receivable'
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isPaid => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// FUTURE NOTE:
// To support a history of payments on a specific debt/receivable in the future,
// we can introduce a 'DebtPayments' table:
// 
// class DebtPayments extends Table {
//   IntColumn get id => integer().autoIncrement()();
//   IntColumn get debtId => integer().references(Debts, #id, onDelete: KeyAction.cascade)();
//   RealColumn get amountPaid => real()();
//   DateTimeColumn get paidAt => dateTime()();
//   TextColumn get notes => text().nullable()();
// }
