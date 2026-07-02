import '../entities/transaction_entity.dart';

abstract class TransactionRepository {
  Future<TransactionEntity> parseTransaction(String rawText);
  Future<void> saveTransaction(TransactionEntity transaction);
  Future<List<TransactionEntity>> getAllTransactions();
}
