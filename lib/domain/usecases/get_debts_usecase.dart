import '../entities/debt.dart';
import '../repositories/debt_repository.dart';

class GetDebtsUseCase {
  final DebtRepository repository;

  GetDebtsUseCase(this.repository);

  Stream<List<Debt>> call() {
    return repository.getDebtsStream();
  }
}
