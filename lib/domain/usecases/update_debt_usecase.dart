import '../entities/debt.dart';
import '../repositories/debt_repository.dart';

class UpdateDebtUseCase {
  final DebtRepository repository;

  UpdateDebtUseCase(this.repository);

  Future<void> call(Debt debt) async {
    if (debt.id == null) {
      throw ArgumentError('ID utang tidak boleh null untuk pembaruan');
    }
    if (debt.title.trim().isEmpty) {
      throw ArgumentError('Judul tidak boleh kosong');
    }
    if (debt.totalAmount <= 0) {
      throw ArgumentError('Nominal harus lebih besar dari 0');
    }
    if (debt.remainingAmount > debt.totalAmount) {
      throw ArgumentError('Sisa pembayaran tidak boleh melebihi total nominal');
    }
    if (debt.remainingAmount < 0) {
      throw ArgumentError('Sisa pembayaran tidak boleh kurang dari 0');
    }

    final updatedDebt = debt.copyWith(
      isPaid: debt.remainingAmount == 0,
      updatedAt: DateTime.now(),
    );

    await repository.updateDebt(updatedDebt);
  }
}
