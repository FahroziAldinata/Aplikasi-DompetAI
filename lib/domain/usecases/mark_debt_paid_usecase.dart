import '../repositories/debt_repository.dart';

class MarkDebtPaidUseCase {
  final DebtRepository repository;

  MarkDebtPaidUseCase(this.repository);

  Future<void> call(int id) async {
    final debt = await repository.getDebtById(id);
    if (debt == null) {
      throw StateError('Utang/Piutang tidak ditemukan');
    }

    final updatedDebt = debt.copyWith(
      remainingAmount: 0.0,
      isPaid: true,
      updatedAt: DateTime.now(),
    );

    await repository.updateDebt(updatedDebt);
  }
}
