import '../entities/debt.dart';

abstract class DebtRepository {
  Stream<List<Debt>> getDebtsStream();
  Future<void> addDebt(Debt debt);
  Future<void> updateDebt(Debt debt);
  Future<void> deleteDebt(int id);
  Future<Debt?> getDebtById(int id);
}
