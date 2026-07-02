import 'package:drift/drift.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../ai/ner_parser.dart';
import '../local/app_database.dart';
import '../local/mappers/transaction_mapper.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final NERParser _nerParser;
  final AppDatabase _database;

  TransactionRepositoryImpl(this._nerParser, this._database);

  @override
  Future<TransactionEntity> parseTransaction(String rawText) {
    return _nerParser.parse(rawText);
  }

  @override
  Future<void> saveTransaction(TransactionEntity transaction) async {
    await _database.into(_database.transactions).insert(
      transaction.toCompanion(),
      mode: InsertMode.insertOrReplace,
    );
  }

  @override
  Future<List<TransactionEntity>> getAllTransactions() async {
    final rows = await _database.select(_database.transactions).get();
    return rows.map((row) => row.toEntity()).toList();
  }
}
