import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';
import '../models/habit.dart';
import '../models/daily_log.dart';
import '../models/workout_plan.dart';
import '../models/meal_plan.dart';
import '../models/daily_meal_log.dart';
import '../repositories/exercise_log_repository.dart';
import '../repositories/daily_log_repository.dart';
import '../models/daily_stats_snapshot.dart';
class DailyScore {
  final int totalScore;
  final bool isFutureDate;
  final double habitsScore;
  final double habitsMax;
  final double workoutsScore;
  final double workoutsMax;
  final double mealsScore;
  final double mealsMax;

  DailyScore({
    required this.totalScore,
    required this.isFutureDate,
    required this.habitsScore,
    required this.habitsMax,
    required this.workoutsScore,
    required this.workoutsMax,
    required this.mealsScore,
    required this.mealsMax,
  });

  static bool _bucketFull(double score, double max) =>
      max <= 0 || score >= max - 0.01;

  /// Habits + meals + workouts fully earned.
  bool get isPrimaryComplete {
    if (isFutureDate) return false;
    return _bucketFull(habitsScore, habitsMax) &&
        _bucketFull(mealsScore, mealsMax) &&
        _bucketFull(workoutsScore, workoutsMax);
  }

  /// Compact labels for Home "still to do" cue.
  List<String> get remainingLabels {
    if (isFutureDate) return const [];
    final labels = <String>[];
    if (habitsMax > 0 && !_bucketFull(habitsScore, habitsMax)) {
      labels.add('habits');
    }
    if (mealsMax > 0 && !_bucketFull(mealsScore, mealsMax)) {
      labels.add('meals');
    }
    if (workoutsMax > 0 && !_bucketFull(workoutsScore, workoutsMax)) {
      labels.add('workout');
    }
    return labels;
  }
  static DailyScore calculate({
    required DateTime date,
    required String dateStr,
    required List<Habit> habits,
    required HabitCompletion habitCompletions,
    required DailyLog dailyLog,
    required WorkoutPlan? workoutPlan,
    required ExerciseLogRepository logRepo,
    required MealPlan? mealPlan,
    required DailyMealLog mealLog,
    required double targetWeight,
    required DailyLogRepository dailyLogRepo,
  }) {
    final today = DateTime.now();
    final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));

    if (isFuture) {
      return DailyScore(
        totalScore: 0,
        isFutureDate: true,
        habitsScore: 0,
        habitsMax: 0,
        workoutsScore: 0,
        workoutsMax: 0,
        mealsScore: 0,
        mealsMax: 0,
      );
    }

    final stats = DailyStatsSnapshot.compute(
      date: date,
      dateStr: dateStr,
      habits: habits,
      habitCompletions: habitCompletions,
      dailyLog: dailyLog,
      workoutPlan: workoutPlan,
      hasLog: logRepo.hasLog,
      mealPlan: mealPlan,
      mealLog: mealLog,
      targetWeight: targetWeight,
      dailyLogRepo: dailyLogRepo,
    );

    // 1. Habits (Max 50)
    double habitsScore = 0;
    final double habitsMax = 50;
    if (stats.habitsTotal > 0) {
      habitsScore = stats.habitRate * habitsMax;
    }

    // 2. Workouts (Max 30)
    double workoutsScore = 0;
    final double workoutsMax = 30;
    if (stats.isRestDay) {
      workoutsScore = workoutsMax;
    } else if (stats.workoutsTotal > 0) {
      workoutsScore = (stats.workoutsDone / stats.workoutsTotal) * workoutsMax;
    }

    // 3. Meals (Max 20)
    double mealsScore = 0;
    final double mealsMax = 20;
    if (stats.mealsTotal > 0) {
      mealsScore = (stats.mealsLogged / stats.mealsTotal) * mealsMax;
    }

    final totalEarned = habitsScore + workoutsScore + mealsScore;
    final totalPossible = habitsMax + workoutsMax + mealsMax;
    
    int finalScore = 0;
    if (totalPossible > 0) {
      finalScore = ((totalEarned / totalPossible) * 100).round();
    }

    return DailyScore(
      totalScore: finalScore,
      isFutureDate: false,
      habitsScore: habitsScore,
      habitsMax: habitsMax,
      workoutsScore: workoutsScore,
      workoutsMax: workoutsMax,
      mealsScore: mealsScore,
      mealsMax: mealsMax,
    );
  }
}

final dailyScoreProvider = Provider<DailyScore>((ref) {
  final dateStr = ref.watch(dateStringProvider);
  final date = DateTime.parse(dateStr);
  
  final habits = ref.watch(habitsProvider);
  final habitCompletions = ref.watch(habitCompletionsProvider);
  final dailyLog = ref.watch(dailyLogProvider);
  
  final workoutPlan = ref.watch(workoutPlanProvider);
  final logRepo = ref.watch(exerciseLogRepoProvider);
  ref.watch(exerciseLogsUpdateProvider);
  
  final mealPlan = ref.watch(mealPlanProvider);
  final mealLog = ref.watch(dailyMealLogProvider);

  final dailyLogRepo = ref.watch(dailyLogRepoProvider);
  final targetWeight = ref.watch(profileProvider.select((p) => p.targetWeight)) ?? 0.0;

  return DailyScore.calculate(
    date: date,
    dateStr: dateStr,
    habits: habits,
    habitCompletions: habitCompletions,
    dailyLog: dailyLog,
    workoutPlan: workoutPlan,
    logRepo: logRepo,
    mealPlan: mealPlan,
    mealLog: mealLog,
    targetWeight: targetWeight,
    dailyLogRepo: dailyLogRepo,
  );
});
