import 'package:drift/drift.dart';
import '../../../domain/entities/debt.dart';
import '../../../domain/entities/debt_type.dart';
import '../app_database.dart';

extension DebtMapper on DebtData {
  Debt toEntity() {
    return Debt(
      id: id,
      title: title,
      totalAmount: totalAmount,
      remainingAmount: remainingAmount,
      type: type == 'receivable' ? DebtType.receivable : DebtType.debt,
      dueDate: dueDate,
      isPaid: isPaid,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension DebtEntityMapper on Debt {
  DebtsCompanion toCompanion() {
    return DebtsCompanion(
      id: id == null ? const Value.absent() : Value(id!),
      title: Value(title),
      totalAmount: Value(totalAmount),
      remainingAmount: Value(remainingAmount),
      type: Value(type == DebtType.receivable ? 'receivable' : 'debt'),
      dueDate: Value(dueDate),
      isPaid: Value(isPaid),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}
