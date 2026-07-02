import '../repositories/debt_repository.dart';

class PayDebtUseCase {
  final DebtRepository repository;

  PayDebtUseCase(this.repository);

  Future<void> call(int id, double paymentAmount) async {
    if (paymentAmount < 0) {
      throw ArgumentError('Nominal pembayaran tidak boleh negatif');
    }
    if (paymentAmount == 0) {
      return; // No operation
    }

    final debt = await repository.getDebtById(id);
    if (debt == null) {
      throw StateError('Utang/Piutang tidak ditemukan');
    }

    if (debt.isPaid) {
      throw StateError('Utang/Piutang ini sudah lunas');
    }

    // Calculate new remaining amount with overpayment protection (caps at 0)
    double newRemaining = debt.remainingAmount - paymentAmount;
    if (newRemaining < 0) {
      newRemaining = 0;
    }

    final updatedDebt = debt.copyWith(
      remainingAmount: newRemaining,
      isPaid: newRemaining == 0,
      updatedAt: DateTime.now(),
    );

    await repository.updateDebt(updatedDebt);
  }
}
