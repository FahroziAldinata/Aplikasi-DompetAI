import '../repositories/debt_repository.dart';

class DeleteDebtUseCase {
  final DebtRepository repository;

  DeleteDebtUseCase(this.repository);

  Future<void> call(int id) async {
    await repository.deleteDebt(id);
  }
}
