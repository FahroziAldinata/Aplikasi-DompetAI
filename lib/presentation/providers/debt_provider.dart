import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/providers.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/debt_filter.dart';
import '../../domain/entities/debt_type.dart';

// 1. StreamProvider to watch all debts from database
final debtsStreamProvider = StreamProvider<List<Debt>>((ref) {
  final getDebtsUseCase = ref.watch(getDebtsUseCaseProvider);
  return getDebtsUseCase();
});

// 2. StateProvider to hold current filter selection
final debtFilterProvider = StateProvider<DebtFilter>((ref) => DebtFilter.all);

// 3. Provider to return filtered debts list
final filteredDebtsProvider = Provider<AsyncValue<List<Debt>>>((ref) {
  final debtsAsync = ref.watch(debtsStreamProvider);
  final filter = ref.watch(debtFilterProvider);

  return debtsAsync.whenData((debts) {
    switch (filter) {
      case DebtFilter.all:
        return debts;
      case DebtFilter.active:
        return debts.where((d) => !d.isPaid).toList();
      case DebtFilter.paid:
        return debts.where((d) => d.isPaid).toList();
    }
  });
});

// 4. StateNotifier to handle actions
class DebtActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  DebtActionNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addDebt({
    required String title,
    required double totalAmount,
    required DebtType type,
    DateTime? dueDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      final addDebtUseCase = _ref.read(addDebtUseCaseProvider);
      final debt = Debt(
        title: title,
        totalAmount: totalAmount,
        remainingAmount: totalAmount,
        type: type,
        dueDate: dueDate,
        isPaid: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await addDebtUseCase(debt);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> payInstallment(int id, double amount) async {
    state = const AsyncValue.loading();
    try {
      final payDebtUseCase = _ref.read(payDebtUseCaseProvider);
      await payDebtUseCase(id, amount);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> markAsPaid(int id) async {
    state = const AsyncValue.loading();
    try {
      final markDebtPaidUseCase = _ref.read(markDebtPaidUseCaseProvider);
      await markDebtPaidUseCase(id);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteDebt(int id) async {
    state = const AsyncValue.loading();
    try {
      final deleteDebtUseCase = _ref.read(deleteDebtUseCaseProvider);
      await deleteDebtUseCase(id);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

// Provider for action notifier
final debtActionNotifierProvider = StateNotifierProvider<DebtActionNotifier, AsyncValue<void>>((ref) {
  return DebtActionNotifier(ref);
});
