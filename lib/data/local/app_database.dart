import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables/transactions_table.dart';
import 'tables/goals_table.dart';
import 'tables/debts_table.dart';
import 'tables/wallets_table.dart';

part 'app_database.g.dart';

class WalletWithBalance {
  final Wallet wallet;
  final double balance;

  WalletWithBalance({required this.wallet, required this.balance});
}

@DriftDatabase(tables: [Transactions, Goals, Debts, Wallets])
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _instance;

  static AppDatabase get instance {
    return _instance ??= AppDatabase._internal();
  }

  factory AppDatabase() {
    return instance;
  }

  AppDatabase._internal() : super(_openConnection());
  AppDatabase.executor(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2 && to >= 2) {
            await m.createTable(goals);
          }
          if (from < 3 && to >= 3) {
            await m.createTable(debts);
          }
          if (from < 4 && to >= 4) {
            await m.addColumn(transactions, transactions.accountType);
            await m.addColumn(transactions, transactions.accountName);
            await m.createTable(wallets);
          }
        },
        beforeOpen: (details) async {
          // Pre-populate default wallets if none exist
          final allWallets = await select(wallets).get();
          if (allWallets.isEmpty) {
            await into(wallets).insert(
              WalletsCompanion.insert(
                id: 'wallet_cash',
                name: 'Dompet Utama',
                type: 'CASH',
                initialBalance: const Value(0),
                createdAt: DateTime.now(),
              ),
            );
            await into(wallets).insert(
              WalletsCompanion.insert(
                id: 'wallet_bca',
                name: 'BCA',
                type: 'REKENING',
                initialBalance: const Value(0),
                createdAt: DateTime.now(),
              ),
            );
            await into(wallets).insert(
              WalletsCompanion.insert(
                id: 'wallet_gopay',
                name: 'GoPay',
                type: 'REKENING',
                initialBalance: const Value(0),
                createdAt: DateTime.now(),
              ),
            );
          }
        },
      );

  // Queries
  Stream<List<Transaction>> watchCashTransactions() {
    return (select(transactions)
          ..where((t) => t.accountType.equals('CASH') | t.account.equals('cash'))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Stream<List<Transaction>> watchTransactionsByAccount(String accountName) {
    return (select(transactions)
          ..where((t) => t.accountName.equals(accountName) | t.account.equals(accountName.toLowerCase()))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<List<WalletWithBalance>> getAccountSummaries() async {
    final allWallets = await select(wallets).get();
    final allTxs = await select(transactions).get();
    final summaries = <WalletWithBalance>[];

    for (final wallet in allWallets) {
      double balance = wallet.initialBalance.toDouble();
      for (final tx in allTxs) {
        final amt = (tx.amount ?? 0).toDouble();
        final txAccName = tx.accountName ?? (tx.account == 'cash' ? 'Dompet Utama' : 'BCA');
        final txAccType = tx.accountType ?? (tx.account == 'cash' ? 'CASH' : 'REKENING');

        if (txAccName.toLowerCase() == wallet.name.toLowerCase()) {
          if (tx.intent == 'income') {
            balance += amt;
          } else if (tx.intent == 'expense') {
            balance -= amt;
          } else if (tx.intent == 'transfer') {
            balance += amt;
          }
        } else {
          if (tx.intent == 'transfer') {
            if (txAccType == 'CASH' && wallet.type == 'REKENING') {
              if (wallet.name.toLowerCase() == 'bca') {
                balance -= amt;
              }
            } else if (txAccType == 'REKENING' && wallet.type == 'CASH') {
              if (wallet.name.toLowerCase() == 'dompet utama') {
                balance -= amt;
              }
            }
          }
        }
      }
      summaries.add(WalletWithBalance(wallet: wallet, balance: balance));
    }
    return summaries;
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'dompetai.sqlite'));
    return NativeDatabase(file);
  });
}
