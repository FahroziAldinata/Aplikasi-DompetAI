import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/ai/ner_parser.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/parse_transaction_usecase.dart';
import '../../data/repositories/debt_repository_impl.dart';
import '../../domain/repositories/debt_repository.dart';
import '../../domain/usecases/get_debts_usecase.dart';
import '../../domain/usecases/add_debt_usecase.dart';
import '../../domain/usecases/update_debt_usecase.dart';
import '../../domain/usecases/delete_debt_usecase.dart';
import '../../domain/usecases/pay_debt_usecase.dart';
import '../../domain/usecases/mark_debt_paid_usecase.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final nerParserProvider = FutureProvider<NERParser>((ref) async {
  final parser = NERParser();
  await parser.init();
  return parser;
});

final transactionRepositoryProvider = FutureProvider<TransactionRepository>((ref) async {
  final nerParser = await ref.watch(nerParserProvider.future);
  final database = ref.watch(appDatabaseProvider);
  return TransactionRepositoryImpl(nerParser, database);
});

final parseTransactionUseCaseProvider = FutureProvider<ParseTransactionUseCase>((ref) async {
  final repository = await ref.watch(transactionRepositoryProvider.future);
  return ParseTransactionUseCase(repository);
});

// Debt Providers
final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return DebtRepositoryImpl(database);
});

final getDebtsUseCaseProvider = Provider<GetDebtsUseCase>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  return GetDebtsUseCase(repository);
});

final addDebtUseCaseProvider = Provider<AddDebtUseCase>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  return AddDebtUseCase(repository);
});

final updateDebtUseCaseProvider = Provider<UpdateDebtUseCase>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  return UpdateDebtUseCase(repository);
});

final deleteDebtUseCaseProvider = Provider<DeleteDebtUseCase>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  return DeleteDebtUseCase(repository);
});

final payDebtUseCaseProvider = Provider<PayDebtUseCase>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  return PayDebtUseCase(repository);
});

final markDebtPaidUseCaseProvider = Provider<MarkDebtPaidUseCase>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  return MarkDebtPaidUseCase(repository);
});

