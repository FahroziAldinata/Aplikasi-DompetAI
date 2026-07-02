import 'package:drift/drift.dart';
import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';
import '../local/app_database.dart';
import '../local/mappers/debt_mapper.dart';

class DebtRepositoryImpl implements DebtRepository {
  final AppDatabase _database;

  DebtRepositoryImpl(this._database);

  @override
  Stream<List<Debt>> getDebtsStream() {
    final now = DateTime.now();
    return (_database.select(_database.debts)
          ..orderBy([
            (t) {
              final isOverdue = t.isPaid.equals(false) &
                  t.dueDate.isNotNull() &
                  t.dueDate.isSmallerThan(Variable(now));
              return OrderingTerm(expression: isOverdue, mode: OrderingMode.desc);
            },
            (t) => OrderingTerm(expression: t.dueDate.isNull(), mode: OrderingMode.asc),
            (t) => OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc),
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .map((rows) => rows.map((row) => row.toEntity()).toList());
  }

  @override
  Future<void> addDebt(Debt debt) async {
    final companion = debt.toCompanion();
    await _database.into(_database.debts).insert(companion);
  }

  @override
  Future<void> updateDebt(Debt debt) async {
    if (debt.id == null) return;
    final companion = debt.toCompanion();
    await (_database.update(_database.debts)..where((t) => t.id.equals(debt.id!)))
        .write(companion);
  }

  @override
  Future<void> deleteDebt(int id) async {
    await (_database.delete(_database.debts)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<Debt?> getDebtById(int id) async {
    final row = await (_database.select(_database.debts)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }
}
