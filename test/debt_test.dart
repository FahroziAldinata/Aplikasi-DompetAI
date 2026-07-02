import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:dompetai/data/local/app_database.dart';
import 'package:dompetai/data/repositories/debt_repository_impl.dart';
import 'package:dompetai/domain/usecases/add_debt_usecase.dart';
import 'package:dompetai/domain/usecases/get_debts_usecase.dart';
import 'package:dompetai/core/providers/providers.dart';
import 'package:dompetai/domain/entities/debt.dart';
import 'package:dompetai/domain/entities/debt_type.dart';
import 'package:dompetai/domain/entities/debt_filter.dart';
import 'package:dompetai/presentation/providers/debt_provider.dart';
import 'package:dompetai/presentation/debt/debt_date_helper.dart';
import 'package:dompetai/presentation/debt/debt_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('Debt Management Unit Tests', () {
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

    test('AddDebtUseCase inserts debt correctly', () async {
      final addDebt = container.read(addDebtUseCaseProvider);
      final getDebts = container.read(getDebtsUseCaseProvider);

      final debt = Debt(
        title: 'Utang Budi',
        totalAmount: 100000,
        remainingAmount: 100000,
        type: DebtType.debt,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        isPaid: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await addDebt(debt);

      final list = await getDebts().first;
      expect(list.length, 1);
      expect(list.first.title, 'Utang Budi');
      expect(list.first.totalAmount, 100000.0);
      expect(list.first.remainingAmount, 100000.0);
      expect(list.first.type, DebtType.debt);
      expect(list.first.isPaid, false);
    });

    test('PayDebtUseCase decreases remainingAmount and sets isPaid when fully paid', () async {
      final addDebt = container.read(addDebtUseCaseProvider);
      final payDebt = container.read(payDebtUseCaseProvider);
      final getDebts = container.read(getDebtsUseCaseProvider);

      final debt = Debt(
        title: 'Piutang Andi',
        totalAmount: 200000,
        remainingAmount: 200000,
        type: DebtType.receivable,
        isPaid: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await addDebt(debt);
      var list = await getDebts().first;
      final insertedId = list.first.id!;

      // Pay installment of 50,000
      await payDebt(insertedId, 50000);
      list = await getDebts().first;
      expect(list.first.remainingAmount, 150000.0);
      expect(list.first.isPaid, false);

      // Pay remaining 150,000
      await payDebt(insertedId, 150000);
      list = await getDebts().first;
      expect(list.first.remainingAmount, 0.0);
      expect(list.first.isPaid, true);
    });

    test('PayDebtUseCase caps remainingAmount at 0 on overpayment', () async {
      final addDebt = container.read(addDebtUseCaseProvider);
      final payDebt = container.read(payDebtUseCaseProvider);
      final getDebts = container.read(getDebtsUseCaseProvider);

      final debt = Debt(
        title: 'Utang Bank',
        totalAmount: 150000,
        remainingAmount: 150000,
        type: DebtType.debt,
        isPaid: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await addDebt(debt);
      var list = await getDebts().first;
      final insertedId = list.first.id!;

      // Try paying 200,000 (overpayment)
      await payDebt(insertedId, 200000);
      list = await getDebts().first;
      expect(list.first.remainingAmount, 0.0);
      expect(list.first.isPaid, true);
    });

    test('MarkDebtPaidUseCase sets remainingAmount to 0 and isPaid to true instantly', () async {
      final addDebt = container.read(addDebtUseCaseProvider);
      final markPaid = container.read(markDebtPaidUseCaseProvider);
      final getDebts = container.read(getDebtsUseCaseProvider);

      final debt = Debt(
        title: 'Utang Makan',
        totalAmount: 50000,
        remainingAmount: 50000,
        type: DebtType.debt,
        isPaid: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await addDebt(debt);
      var list = await getDebts().first;
      final insertedId = list.first.id!;

      await markPaid(insertedId);
      list = await getDebts().first;
      expect(list.first.remainingAmount, 0.0);
      expect(list.first.isPaid, true);
    });

    test('DeleteDebtUseCase deletes a debt correctly', () async {
      final addDebt = container.read(addDebtUseCaseProvider);
      final deleteDebt = container.read(deleteDebtUseCaseProvider);
      final getDebts = container.read(getDebtsUseCaseProvider);

      final debt = Debt(
        title: 'Utang Teman',
        totalAmount: 30000,
        remainingAmount: 30000,
        type: DebtType.debt,
        isPaid: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await addDebt(debt);
      var list = await getDebts().first;
      expect(list.length, 1);
      final insertedId = list.first.id!;

      await deleteDebt(insertedId);
      list = await getDebts().first;
      expect(list.isEmpty, true);
    });

    test('State Management filteredDebtsProvider works correctly', () async {
      final addDebt = container.read(addDebtUseCaseProvider);
      final markPaid = container.read(markDebtPaidUseCaseProvider);
      final getDebts = container.read(getDebtsUseCaseProvider);

      final debtActive = Debt(
        title: 'Utang Aktif',
        totalAmount: 10000,
        remainingAmount: 10000,
        type: DebtType.debt,
        isPaid: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      final debtPaid = Debt(
        title: 'Utang Lunas',
        totalAmount: 20000,
        remainingAmount: 20000,
        type: DebtType.debt,
        isPaid: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await addDebt(debtActive);
      await addDebt(debtPaid);

      // Mark the second one as paid
      final list = await getDebts().first;
      final paidDebtId = list.first.title == 'Utang Lunas' ? list.first.id! : list.last.id!;
      await markPaid(paidDebtId);

      // Listen to keep provider active
      final listener = container.listen(filteredDebtsProvider, (prev, next) {});

      // 1. Filter: all
      container.read(debtFilterProvider.notifier).state = DebtFilter.all;
      await Future.delayed(const Duration(milliseconds: 50));
      var filteredList = container.read(filteredDebtsProvider).value;
      expect(filteredList?.length, 2);

      // 2. Filter: active
      container.read(debtFilterProvider.notifier).state = DebtFilter.active;
      await Future.delayed(const Duration(milliseconds: 50));
      filteredList = container.read(filteredDebtsProvider).value;
      expect(filteredList?.length, 1);
      expect(filteredList?.first.title, 'Utang Aktif');

      // 3. Filter: paid
      container.read(debtFilterProvider.notifier).state = DebtFilter.paid;
      await Future.delayed(const Duration(milliseconds: 50));
      filteredList = container.read(filteredDebtsProvider).value;
      expect(filteredList?.length, 1);
      expect(filteredList?.first.title, 'Utang Lunas');

      listener.close();
    });

    test('Drift migration v2 to v3 creates debts table without losing data', () async {
      final database = AppDatabase.executor(NativeDatabase.memory());
      final migrator = database.createMigrator();
      
      final strategy = database.migration;
      await strategy.onUpgrade(migrator, 2, 3);
      
      final addDebt = AddDebtUseCase(DebtRepositoryImpl(database));
      final debt = Debt(
        title: 'Migration Test Debt',
        totalAmount: 10000,
        remainingAmount: 10000,
        type: DebtType.debt,
        isPaid: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await addDebt(debt);
      
      final getDebts = GetDebtsUseCase(DebtRepositoryImpl(database));
      final list = await getDebts().first;
      expect(list.length, 1);
      expect(list.first.title, 'Migration Test Debt');
      
      await database.close();
    });

    test('Repository sorting orders overdue first, then due date closest, then newest', () async {
      final repository = DebtRepositoryImpl(db);
      final getDebts = GetDebtsUseCase(repository);

      final now = DateTime.now();

      // 1. Unpaid, due 5 days from now
      final debtNormalFuture = Debt(
        title: 'Due Future',
        totalAmount: 100000,
        remainingAmount: 100000,
        type: DebtType.debt,
        dueDate: now.add(const Duration(days: 5)),
        isPaid: false,
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      );

      // 2. Unpaid, due 2 days ago (Overdue)
      final debtOverdue = Debt(
        title: 'Overdue Debt',
        totalAmount: 50000,
        remainingAmount: 50000,
        type: DebtType.debt,
        dueDate: now.subtract(const Duration(days: 2)),
        isPaid: false,
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      );

      // 3. Unpaid, due 1 day from now (Closest future due date)
      final debtClosestFuture = Debt(
        title: 'Closest Future',
        totalAmount: 70000,
        remainingAmount: 70000,
        type: DebtType.debt,
        dueDate: now.add(const Duration(days: 1)),
        isPaid: false,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      );

      // 4. Unpaid, no due date (should sort last, ordered by newest first)
      final debtNoDueDateOld = Debt(
        title: 'No Due Date Old',
        totalAmount: 80000,
        remainingAmount: 80000,
        type: DebtType.debt,
        isPaid: false,
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now.subtract(const Duration(hours: 5)),
      );

      final debtNoDueDateNew = Debt(
        title: 'No Due Date New',
        totalAmount: 90000,
        remainingAmount: 90000,
        type: DebtType.debt,
        isPaid: false,
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      );

      // Add to DB in different order using repository directly (preserves createdAt)
      await repository.addDebt(debtNormalFuture);
      await repository.addDebt(debtOverdue);
      await repository.addDebt(debtClosestFuture);
      await repository.addDebt(debtNoDueDateOld);
      await repository.addDebt(debtNoDueDateNew);

      final sortedList = await getDebts().first;

      // Expected order:
      // Index 0: Overdue Debt (Overdue)
      // Index 1: Closest Future (Due 1 day)
      // Index 2: Due Future (Due 5 days)
      // Index 3: No Due Date New (Newer)
      // Index 4: No Due Date Old (Older)
      expect(sortedList.length, 5);
      expect(sortedList[0].title, 'Overdue Debt');
      expect(sortedList[1].title, 'Closest Future');
      expect(sortedList[2].title, 'Due Future');
      expect(sortedList[3].title, 'No Due Date New');
      expect(sortedList[4].title, 'No Due Date Old');
    });

    test('DebtDateHelper friendly due date calculations', () {
      final today = DateTime(2026, 6, 30);

      // No due date
      expect(DebtDateHelper.formatFriendlyDueDate(null, today, false), 'Tanpa jatuh tempo');

      // Paid (should just display formatted date)
      expect(
        DebtDateHelper.formatFriendlyDueDate(DateTime(2026, 7, 5), today, true),
        '5 Jul 2026',
      );

      // Due today
      expect(
        DebtDateHelper.formatFriendlyDueDate(DateTime(2026, 6, 30), today, false),
        'Hari ini (30 Jun 2026)',
      );

      // Due tomorrow
      expect(
        DebtDateHelper.formatFriendlyDueDate(DateTime(2026, 7, 1), today, false),
        'Besok (1 Jul 2026)',
      );

      // Due in 5 days
      expect(
        DebtDateHelper.formatFriendlyDueDate(DateTime(2026, 7, 5), today, false),
        '5 hari lagi (5 Jul 2026)',
      );

      // Overdue by 1 day
      expect(
        DebtDateHelper.formatFriendlyDueDate(DateTime(2026, 6, 29), today, false),
        'Terlambat 1 hari (29 Jun 2026)',
      );

      // Overdue by 5 days
      expect(
        DebtDateHelper.formatFriendlyDueDate(DateTime(2026, 6, 25), today, false),
        'Terlambat 5 hari (25 Jun 2026)',
      );

      // Color tests
      expect(DebtDateHelper.getDueDateColor(null, today, false), Colors.grey);
      expect(DebtDateHelper.getDueDateColor(DateTime(2026, 6, 25), today, true), Colors.grey);
      expect(DebtDateHelper.getDueDateColor(DateTime(2026, 6, 25), today, false), Colors.redAccent);
      expect(DebtDateHelper.getDueDateColor(DateTime(2026, 7, 2), today, false), Colors.amber);
      expect(DebtDateHelper.getDueDateColor(DateTime(2026, 7, 10), today, false), Colors.green);
    });

    testWidgets('Widget Flow: Add Debt via Bottom Sheet', (WidgetTester tester) async {
      final memoryDb = AppDatabase.executor(NativeDatabase.memory());
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(memoryDb),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            home: Scaffold(
              body: DebtScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify empty state is displayed initially
      expect(find.text('Belum ada utang'), findsOneWidget);

      // Tap on "+ Tambah Catatan Utang" card button to add debt
      final addBtn = find.text("+ Tambah Catatan Utang");
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Bottom sheet should be visible
      expect(find.text('Tambah Utang/Piutang'), findsOneWidget);

      // Enter title
      await tester.enterText(find.widgetWithText(TextField, 'Nama Orang'), 'Pinjaman Bank Mandiri');

      // Enter amount
      await tester.enterText(find.widgetWithText(TextField, 'Nominal'), '5000000');

      // Tap Simpan Catatan
      final saveBtn = find.widgetWithText(ElevatedButton, 'Simpan Catatan');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      
      // Let it settle (async DB insert + state updates)
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Bottom sheet should close, and the list should now show the new debt card
      expect(find.text('Tambah Utang/Piutang'), findsNothing);
      expect(find.text('Pinjaman Bank Mandiri'), findsOneWidget);
      // It should display sisa and total progress
      expect(find.text('Sisa: Rp 5.000.000'), findsOneWidget);

      await memoryDb.close();
    });
  });
}
