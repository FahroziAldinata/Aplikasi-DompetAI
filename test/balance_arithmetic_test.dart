import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:dompetai/data/local/app_database.dart';
import 'package:dompetai/core/providers/providers.dart';
import 'package:dompetai/presentation/dashboard/dashboard_provider.dart';

void main() {
  group('Balance Arithmetic Unit Tests', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.executor(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('Scenario 1: Transfer Cash -> Rekening (rekening account, cash decreases, rekening increases)', () async {
      // Listen to keep providers active
      final cashListener = container.listen(cashBalanceProvider, (prev, next) {});
      final rekeningListener = container.listen(rekeningBalanceProvider, (prev, next) {});

      // Wait for initial values to load
      await container.read(cashBalanceProvider.future);
      await container.read(rekeningBalanceProvider.future);

      expect(container.read(cashBalanceProvider).requireValue, equals(0.0));
      expect(container.read(rekeningBalanceProvider).requireValue, equals(0.0));

      // 2. Insert base cash/income
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'income_cash',
          rawText: 'terima cash 1jt',
          intent: 'income',
          account: const Value('cash'),
          amount: const Value(1000000),
          createdAt: DateTime.now(),
          confidence: 1.0,
        ),
      );

      // Wait for streams to update
      await Future.delayed(const Duration(milliseconds: 50));

      expect(container.read(cashBalanceProvider).requireValue, equals(1000000.0));
      expect(container.read(rekeningBalanceProvider).requireValue, equals(0.0));

      // 3. Perform transfer: Cash -> Rekening (meaning account = 'rekening', intent = 'transfer')
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tf_cash_to_rek',
          rawText: 'transfer 200rb ke rekening',
          intent: 'transfer',
          account: const Value('rekening'),
          amount: const Value(200000),
          createdAt: DateTime.now(),
          confidence: 1.0,
        ),
      );

      // Wait for streams to update
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify final state: cash decreases by 200.000 (1.000.000 - 200.000 = 800.000)
      // Rekening increases by 200.000 (0 + 200.000 = 200.000)
      expect(container.read(cashBalanceProvider).requireValue, equals(800000.0));
      expect(container.read(rekeningBalanceProvider).requireValue, equals(200000.0));

      cashListener.close();
      rekeningListener.close();
    });

    test('Scenario 2: Transfer Rekening -> Cash (cash account, rekening decreases, cash increases)', () async {
      final cashListener = container.listen(cashBalanceProvider, (prev, next) {});
      final rekeningListener = container.listen(rekeningBalanceProvider, (prev, next) {});

      await container.read(cashBalanceProvider.future);
      await container.read(rekeningBalanceProvider.future);

      // 1. Insert base rekening income
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'income_rek',
          rawText: 'gaji masuk 1.5jt ke rekening',
          intent: 'income',
          account: const Value('rekening'),
          amount: const Value(1500000),
          createdAt: DateTime.now(),
          confidence: 1.0,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(container.read(cashBalanceProvider).requireValue, equals(0.0));
      expect(container.read(rekeningBalanceProvider).requireValue, equals(1500000.0));

      // 2. Perform transfer: Rekening -> Cash (meaning account = 'cash', intent = 'transfer')
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tf_rek_to_cash',
          rawText: 'tarik tunai 300rb dari bca',
          intent: 'transfer',
          account: const Value('cash'),
          amount: const Value(300000),
          createdAt: DateTime.now(),
          confidence: 1.0,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // Verify final state: rekening decreases by 300.000 (1.500.000 - 300.000 = 1.200.000)
      // Cash increases by 300.000 (0 + 300.000 = 300.000)
      expect(container.read(cashBalanceProvider).requireValue, equals(300000.0));
      expect(container.read(rekeningBalanceProvider).requireValue, equals(1200000.0));

      cashListener.close();
      rekeningListener.close();
    });

    test('Scenario 3: Transfer with unextracted/null amount (draft transaction, balances unchanged)', () async {
      final cashListener = container.listen(cashBalanceProvider, (prev, next) {});
      final rekeningListener = container.listen(rekeningBalanceProvider, (prev, next) {});

      await container.read(cashBalanceProvider.future);
      await container.read(rekeningBalanceProvider.future);

      // 1. Insert base balances
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'income_base',
          rawText: 'terima cash 500rb',
          intent: 'income',
          account: const Value('cash'),
          amount: const Value(500000),
          createdAt: DateTime.now(),
          confidence: 1.0,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(container.read(cashBalanceProvider).requireValue, equals(500000.0));
      expect(container.read(rekeningBalanceProvider).requireValue, equals(0.0));

      // 2. Insert transfer with null/0 amount
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tf_draft',
          rawText: 'transfer ke rekening tanpa nominal',
          intent: 'transfer',
          account: const Value('rekening'),
          amount: const Value(null),
          createdAt: DateTime.now(),
          confidence: 1.0,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // Verify balances are completely unchanged
      expect(container.read(cashBalanceProvider).requireValue, equals(500000.0));
      expect(container.read(rekeningBalanceProvider).requireValue, equals(0.0));

      cashListener.close();
      rekeningListener.close();
    });

    test('Scenario 4: Category Statistics aggregation, sorting, and period filtering', () async {
      // Listen to keep provider active
      final statsListener = container.listen(categoryExpensesProvider, (prev, next) {});

      // Wait for initial load (empty)
      final initialStats = container.read(categoryExpensesProvider);
      expect(initialStats, isEmpty);

      // Insert transactions
      final now = DateTime.now();

      // 1. Expense: makanan (50,000)
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_makanan_1',
          rawText: 'beli bakso 50k',
          intent: 'expense',
          category: const Value('makanan'),
          amount: const Value(50000),
          createdAt: now,
          confidence: 1.0,
        ),
      );

      // 2. Expense: makanan (25,000)
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_makanan_2',
          rawText: 'beli mie ayam 25k',
          intent: 'expense',
          category: const Value('makanan'),
          amount: const Value(25000),
          createdAt: now,
          confidence: 1.0,
        ),
      );

      // 3. Expense: transportasi (25,000)
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_trans_1',
          rawText: 'gojek ke kantor 25k',
          intent: 'expense',
          category: const Value('transportasi'),
          amount: const Value(25000),
          createdAt: now,
          confidence: 1.0,
        ),
      );

      // 4. Expense: null/empty category (20,000) -> should default to 'Lainnya'
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_lainnya_1',
          rawText: 'bayar sesuatu 20k',
          intent: 'expense',
          category: const Value(null),
          amount: const Value(20000),
          createdAt: now,
          confidence: 1.0,
        ),
      );

      // 5. Income: pemasukan (1,000,000) -> should be ignored (intent is income)
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_income_1',
          rawText: 'gajian 1jt',
          intent: 'income',
          category: const Value('pemasukan'),
          amount: const Value(1000000),
          createdAt: now,
          confidence: 1.0,
        ),
      );

      // 6. Expense: makanan (10,000) 10 days ago -> ignored in 'week' filter, included in 'month'
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx_old_makanan',
          rawText: 'beli kopi 10rb 10 hari lalu',
          intent: 'expense',
          category: const Value('makanan'),
          amount: const Value(10000),
          createdAt: now.subtract(const Duration(days: 10)),
          confidence: 1.0,
        ),
      );

      // Wait for streams to update
      await Future.delayed(const Duration(milliseconds: 50));

      // Retrieve weekly statistics (default filter is 'week')
      expect(container.read(chartFilterProvider), equals('week'));
      final weeklyStats = container.read(categoryExpensesProvider);
      
      // Expected breakdown in week:
      // total = 50k + 25k + 25k + 20k = 120,000
      // 1. makanan: 75,000 (62.5%)
      // 2. transportasi: 25,000 (20.83%)
      // 3. Lainnya: 20,000 (16.67%)
      expect(weeklyStats.length, equals(3));
      expect(weeklyStats[0].category, equals('makanan'));
      expect(weeklyStats[0].amount, equals(75000.0));
      expect(weeklyStats[0].percentage, closeTo(0.625, 0.001));

      expect(weeklyStats[1].category, equals('transportasi'));
      expect(weeklyStats[1].amount, equals(25000.0));
      expect(weeklyStats[1].percentage, closeTo(0.208, 0.001));

      expect(weeklyStats[2].category, equals('Lainnya'));
      expect(weeklyStats[2].amount, equals(20000.0));
      expect(weeklyStats[2].percentage, closeTo(0.167, 0.001));

      // Switch filter to 'month'
      container.read(chartFilterProvider.notifier).state = 'month';
      await Future.delayed(const Duration(milliseconds: 50));

      final monthlyStats = container.read(categoryExpensesProvider);
      
      // Expected breakdown in month:
      // total = 75k + 25k + 20k + 10k (old) = 130,000
      // 1. makanan: 85,000
      // 2. transportasi: 25,000
      // 3. Lainnya: 20,000
      expect(monthlyStats.length, equals(3));
      expect(monthlyStats[0].category, equals('makanan'));
      expect(monthlyStats[0].amount, equals(85000.0));

      statsListener.close();
    });
  });
}
