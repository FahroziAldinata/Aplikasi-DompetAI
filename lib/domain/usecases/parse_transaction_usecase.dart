import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class ParseTransactionUseCase {
  final TransactionRepository _repository;

  ParseTransactionUseCase(this._repository);

  Future<TransactionEntity> call(String rawText) {
    return _repository.parseTransaction(rawText);
  }
}
