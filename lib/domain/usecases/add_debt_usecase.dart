import '../entities/debt.dart';
import '../repositories/debt_repository.dart';

class AddDebtUseCase {
  final DebtRepository repository;

  AddDebtUseCase(this.repository);

  Future<void> call(Debt debt) async {
    if (debt.title.trim().isEmpty) {
      throw ArgumentError('Judul tidak boleh kosong');
    }
    if (debt.totalAmount <= 0) {
      throw ArgumentError('Nominal harus lebih besar dari 0');
    }

    final newDebt = debt.copyWith(
      remainingAmount: debt.totalAmount,
      isPaid: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repository.addDebt(newDebt);
  }
}
