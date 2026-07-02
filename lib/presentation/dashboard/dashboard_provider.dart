import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:drift/drift.dart';
import '../../data/local/app_database.dart';
import '../../data/local/mappers/transaction_mapper.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/wallet.dart';
import '../../core/providers/providers.dart';
import '../goals/goal_provider.dart';

// Heuristic helper to categorize an entity as cash or rekening
bool isCash(TransactionEntity tx) {
  if (tx.accountType != null) {
    return tx.accountType == 'CASH';
  }
  final acc = (tx.account ?? 'cash').toLowerCase().trim();
  return acc == 'cash';
}

// Wallet Account Notifier using AsyncNotifier
class WalletAccountNotifier extends AsyncNotifier<List<WalletSummary>> {
  @override
  Future<List<WalletSummary>> build() async {
    final db = ref.watch(appDatabaseProvider);
    
    // Rebuild summaries when transactions stream changes
    ref.watch(allTransactionsProvider);
    
    final dbSummaries = await db.getAccountSummaries();
    return dbSummaries.map((s) => WalletSummary(
      wallet: WalletEntity(
        id: s.wallet.id,
        name: s.wallet.name,
        type: s.wallet.type,
        initialBalance: s.wallet.initialBalance,
        createdAt: s.wallet.createdAt,
      ),
      balance: s.balance,
    )).toList();
  }

  Future<void> addWallet(String name, String type, int initialBalance) async {
    state = const AsyncValue.loading();
    final db = ref.read(appDatabaseProvider);
    await db.into(db.wallets).insert(
      WalletsCompanion.insert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        type: type,
        initialBalance: Value(initialBalance),
        createdAt: DateTime.now(),
      ),
    );
    ref.invalidateSelf();
  }
}

final walletAccountProvider = AsyncNotifierProvider<WalletAccountNotifier, List<WalletSummary>>(() {
  return WalletAccountNotifier();
});

// Cash specific transactions provider
final cashTransactionProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchCashTransactions().map((rows) => rows.map((r) => r.toEntity()).toList());
});

// Bank/rekening specific transactions provider
final bankTransactionProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.transactions).watch().map((rows) {
    return rows
        .map((r) => r.toEntity())
        .where((tx) => tx.accountType != 'CASH' && tx.account != 'cash')
        .toList();
  });
});

// Dynamic single account transactions provider
final transactionsByAccountProvider = StreamProvider.family<List<TransactionEntity>, String>((ref, accountName) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchTransactionsByAccount(accountName).map((rows) => rows.map((r) => r.toEntity()).toList());
});

// Cash Balance Provider
final cashBalanceProvider = StreamProvider<double>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.transactions).watch().map((rows) {
    double balance = 0.0;
    for (final r in rows) {
      final tx = r.toEntity();
      final amt = (tx.amount ?? 0).toDouble();
      if (isCash(tx)) {
        if (tx.intent == 'income') {
          balance += amt;
        } else if (tx.intent == 'expense') {
          balance -= amt;
        } else if (tx.intent == 'transfer') {
          balance += amt;
        }
      } else {
        if (tx.intent == 'transfer') {
          balance -= amt;
        }
      }
    }
    return balance;
  });
});

// Rekening Balance Provider
final rekeningBalanceProvider = StreamProvider<double>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.transactions).watch().map((rows) {
    double balance = 0.0;
    for (final r in rows) {
      final tx = r.toEntity();
      final amt = (tx.amount ?? 0).toDouble();
      if (!isCash(tx)) {
        if (tx.intent == 'income') {
          balance += amt;
        } else if (tx.intent == 'expense') {
          balance -= amt;
        } else if (tx.intent == 'transfer') {
          balance += amt;
        }
      } else {
        if (tx.intent == 'transfer') {
          balance -= amt;
        }
      }
    }
    return balance;
  });
});

// Recent Transactions Provider (Last 5 transactions)
final recentTransactionsProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.transactions)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
        ..limit(5))
      .watch()
      .map((rows) => rows.map((r) => r.toEntity()).toList());
});

// Stream of all transactions for chart aggregation
final allTransactionsProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.transactions).watch().map((rows) => rows.map((r) => r.toEntity()).toList());
});

// Filter for chart (week / month)
final chartFilterProvider = StateProvider<String>((ref) => 'week');

// Aggregates expenses for the last 7 or 30 days
final chartDataProvider = Provider<List<FlSpot>>((ref) {
  final filter = ref.watch(chartFilterProvider);
  final txsAsync = ref.watch(allTransactionsProvider);

  return txsAsync.maybeWhen(
    data: (txs) {
      final now = DateTime.now();
      final daysCount = filter == 'week' ? 7 : 30;
      final Map<int, double> dailyExpenses = {};

      // Initialize days with 0
      for (int i = 0; i < daysCount; i++) {
        final date = now.subtract(Duration(days: i));
        final key = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
        dailyExpenses[key] = 0.0;
      }

      // Populate sums
      for (final tx in txs) {
        if (tx.intent == 'expense' && tx.amount != null) {
          final dateKey = DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day).millisecondsSinceEpoch;
          if (dailyExpenses.containsKey(dateKey)) {
            dailyExpenses[dateKey] = dailyExpenses[dateKey]! + tx.amount!.toDouble();
          }
        }
      }

      // Convert to sorted spots (oldest to newest day)
      final sortedKeys = dailyExpenses.keys.toList()..sort();
      final List<FlSpot> spots = [];
      for (int i = 0; i < sortedKeys.length; i++) {
        final key = sortedKeys[i];
        spots.add(FlSpot(i.toDouble(), dailyExpenses[key]!));
      }
      return spots;
    },
    orElse: () => List<FlSpot>.generate(filter == 'week' ? 7 : 30, (i) => FlSpot(i.toDouble(), 0.0)),
  );
});

// Saving Goals Provider (Take max 2 goals for preview)
final savingGoalsProvider = Provider<List<Goal>>((ref) {
  final goalsAsync = ref.watch(goalsProvider);
  return goalsAsync.maybeWhen(
    data: (goals) => goals.take(2).toList(),
    orElse: () => [],
  );
});

// Chart View Type ('trend' or 'category')
final chartTypeProvider = StateProvider<String>((ref) => 'trend');

// Category Expense Model
class CategoryExpense {
  final String category;
  final double amount;
  final double percentage;

  CategoryExpense({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}

// Category-wise Expense Provider
final categoryExpensesProvider = Provider<List<CategoryExpense>>((ref) {
  final filter = ref.watch(chartFilterProvider);
  final txsAsync = ref.watch(allTransactionsProvider);

  return txsAsync.maybeWhen(
    data: (txs) {
      final now = DateTime.now();
      final daysLimit = filter == 'week' ? 7 : 30;
      final startDate = now.subtract(Duration(days: daysLimit));

      final Map<String, double> categorySums = {};
      double totalExpense = 0.0;

      for (final tx in txs) {
        if (tx.intent == 'expense' && tx.amount != null) {
          // Normalize transaction date to compare days correctly
          final txDate = DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day);
          final limitDate = DateTime(startDate.year, startDate.month, startDate.day);
          if (txDate.isAfter(limitDate) || txDate.isAtSameMomentAs(limitDate)) {
            final cat = tx.category ?? 'Lainnya';
            categorySums[cat] = (categorySums[cat] ?? 0.0) + tx.amount!.toDouble();
            totalExpense += tx.amount!.toDouble();
          }
        }
      }

      if (totalExpense == 0) return [];

      final List<CategoryExpense> list = [];
      categorySums.forEach((category, amount) {
        list.add(CategoryExpense(
          category: category,
          amount: amount,
          percentage: amount / totalExpense,
        ));
      });

      // Sort by amount descending
      list.sort((a, b) => b.amount.compareTo(a.amount));
      return list;
    },
    orElse: () => [],
  );
});

final categoryExpenseProvider = StreamProvider<Map<String, double>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.transactions).watch().map((rows) {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 30));
    final limitDate = DateTime(startDate.year, startDate.month, startDate.day);
    
    final Map<String, double> categorySums = {};
    double totalExpense = 0.0;

    for (final r in rows) {
      final tx = r.toEntity();
      if (tx.intent == 'expense' && tx.amount != null) {
        final txDate = DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day);
        if (txDate.isAfter(limitDate) || txDate.isAtSameMomentAs(limitDate)) {
          final cat = tx.category ?? 'Lainnya';
          categorySums[cat] = (categorySums[cat] ?? 0.0) + tx.amount!.toDouble();
          totalExpense += tx.amount!.toDouble();
        }
      }
    }

    if (totalExpense == 0.0) return <String, double>{};

    return categorySums.map((key, value) => MapEntry(key, value / totalExpense));
  });
});

final cashHistoryProvider = StreamProvider.family<List<TransactionEntity>, String>((ref, paramString) {
  final parts = paramString.split(':');
  final accountFilter = parts[0];
  final period = parts.length > 1 ? parts[1] : 'all';

  final db = ref.watch(appDatabaseProvider);
  return db.select(db.transactions).watch().map((rows) {
    final list = rows.map((r) => r.toEntity()).toList();
    
    // Filter by accountFilter
    final filteredByAccount = list.where((tx) {
      final acc = (tx.account ?? '').toLowerCase().trim();
      if (accountFilter.toLowerCase().trim() == 'cash') {
        return acc == 'cash' || acc == 'tunai';
      } else {
        return acc == accountFilter.toLowerCase().trim();
      }
    }).toList();

    if (period == 'all') {
      return filteredByAccount;
    }
    
    final now = DateTime.now();
    if (period == 'week') {
      final limitDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      return filteredByAccount.where((tx) => tx.createdAt.isAfter(limitDate) || tx.createdAt.isAtSameMomentAs(limitDate)).toList();
    } else if (period == 'month') {
      final limitDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      return filteredByAccount.where((tx) => tx.createdAt.isAfter(limitDate) || tx.createdAt.isAtSameMomentAs(limitDate)).toList();
    } else if (period.startsWith('custom:')) {
      final pParts = period.split(':');
      if (pParts.length >= 3) {
        final start = DateTime.tryParse(pParts[1]);
        final end = DateTime.tryParse(pParts[2]);
        if (start != null && end != null) {
          final normalizedStart = DateTime(start.year, start.month, start.day);
          final normalizedEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
          return filteredByAccount.where((tx) {
            return (tx.createdAt.isAfter(normalizedStart) || tx.createdAt.isAtSameMomentAs(normalizedStart)) &&
                   (tx.createdAt.isBefore(normalizedEnd) || tx.createdAt.isAtSameMomentAs(normalizedEnd));
          }).toList();
        }
      }
    }
    return filteredByAccount;
  });
});

final accountListProvider = StreamProvider<List<String>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.transactions).watch().map((rows) {
    final list = rows
        .map((r) => r.account?.trim() ?? '')
        .where((acc) => acc.isNotEmpty)
        .toSet()
        .toList();
    list.sort((a, b) => a.compareTo(b));
    return list;
  });
});

final accountBalanceProvider = StreamProvider.family<double, String>((ref, account) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.transactions).watch().map((rows) {
    double balance = 0.0;
    final target = account.toLowerCase().trim();
    for (final r in rows) {
      final tx = r.toEntity();
      final txAcc = (tx.account ?? '').toLowerCase().trim();
      final amt = (tx.amount ?? 0).toDouble();
      if (txAcc == target) {
        if (tx.intent == 'income') {
          balance += amt;
        } else if (tx.intent == 'expense') {
          balance -= amt;
        }
      }
    }
    return balance;
  });
});

final allTransactionsFilteredProvider = StreamProvider.family<List<TransactionEntity>, String>((ref, filter) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.transactions).watch().map((rows) {
    final list = rows.map((r) => r.toEntity()).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (filter.toLowerCase() == 'all') {
      return list;
    }
    // Handle plural 'expenses' in request
    final targetFilter = filter.toLowerCase().startsWith('expense') ? 'expense' : filter.toLowerCase();
    return list.where((tx) => tx.intent.toLowerCase() == targetFilter).toList();
  });
});

final accountHistoryProvider = StreamProvider.family<List<TransactionEntity>, String>((ref, paramString) {
  final parts = paramString.split(':');
  final account = parts[0];
  final period = parts.sublist(1).join(':');
  
  final db = ref.watch(appDatabaseProvider);
  final stream = (account.toLowerCase() == 'cash') 
      ? db.watchCashTransactions() 
      : db.watchTransactionsByAccount(account);
      
  return stream.map((rows) {
    final list = rows.map((r) => r.toEntity()).toList();
    if (period == 'all') {
      return list;
    }
    
    final now = DateTime.now();
    if (period == 'week') {
      final limitDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      return list.where((tx) => tx.createdAt.isAfter(limitDate) || tx.createdAt.isAtSameMomentAs(limitDate)).toList();
    } else if (period == 'month') {
      final limitDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      return list.where((tx) => tx.createdAt.isAfter(limitDate) || tx.createdAt.isAtSameMomentAs(limitDate)).toList();
    } else if (period.startsWith('custom:')) {
      final pParts = period.split(':');
      if (pParts.length >= 3) {
        final start = DateTime.tryParse(pParts[1]);
        final end = DateTime.tryParse(pParts[2]);
        if (start != null && end != null) {
          final normalizedStart = DateTime(start.year, start.month, start.day);
          final normalizedEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
          return list.where((tx) {
            return (tx.createdAt.isAfter(normalizedStart) || tx.createdAt.isAtSameMomentAs(normalizedStart)) &&
                   (tx.createdAt.isBefore(normalizedEnd) || tx.createdAt.isAtSameMomentAs(normalizedEnd));
          }).toList();
        }
      }
    }
    return list;
  });
});



