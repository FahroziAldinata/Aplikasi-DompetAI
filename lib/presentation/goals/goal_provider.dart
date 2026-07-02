import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../data/local/app_database.dart';
import '../../core/providers/providers.dart';

// Provider to stream all goals from the database
final goalsProvider = StreamProvider<List<Goal>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.goals)
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
      .watch();
});

class GoalOperations {
  final AppDatabase db;
  GoalOperations(this.db);

  // Add a new goal
  Future<void> addGoal({
    required String name,
    required double targetAmount,
    required DateTime deadline,
  }) async {
    final newGoal = Goal(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      targetAmount: targetAmount,
      currentAmount: 0.0,
      deadline: deadline,
      createdAt: DateTime.now(),
    );
    await db.into(db.goals).insert(newGoal);
  }

  // Update current amount progress
  Future<void> updateGoalAmount(String id, double currentAmount) async {
    await (db.update(db.goals)..where((t) => t.id.equals(id)))
        .write(GoalsCompanion(currentAmount: Value(currentAmount)));
  }

  // Delete a goal
  Future<void> deleteGoal(String id) async {
    await (db.delete(db.goals)..where((t) => t.id.equals(id))).go();
  }
}

// Provider for operations
final goalOperationsProvider = Provider<GoalOperations>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return GoalOperations(db);
});
