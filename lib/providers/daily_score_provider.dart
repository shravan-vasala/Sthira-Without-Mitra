import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
    this.yesterdayScore,
    this.sevenDayAverage,
  });

  final int? yesterdayScore;
  final int? sevenDayAverage;

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
    required int targetCalories,
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

    // 3. Meals (Max 20 = 14 completion + 6 accuracy)
    double mealsScore = 0;
    final double mealsMax = 20;
    if (stats.mealsTotal > 0) {
      double completionScore = (stats.mealsLogged / stats.mealsTotal) * 14.0;
      double accuracyScore = 0;

      // Accuracy bonus only applies if they logged something
      if (stats.mealsLogged > 0 && targetCalories > 0) {
        final double consumed = mealLog.totalCalories.toDouble();
        final double variance =
            (consumed - targetCalories).abs() / targetCalories;

        if (variance <= 0.10) {
          accuracyScore = 6.0; // Perfect within 10%
        } else if (variance < 0.35) {
          // Linearly scale down from 6 to 0 between 10% and 35%
          final double ratio = (0.35 - variance) / (0.35 - 0.10);
          accuracyScore = 6.0 * ratio;
        }
      }

      mealsScore = completionScore + accuracyScore;
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

  DailyScore copyWithContext({int? yesterdayScore, int? sevenDayAverage}) {
    return DailyScore(
      totalScore: totalScore,
      isFutureDate: isFutureDate,
      habitsScore: habitsScore,
      habitsMax: habitsMax,
      workoutsScore: workoutsScore,
      workoutsMax: workoutsMax,
      mealsScore: mealsScore,
      mealsMax: mealsMax,
      yesterdayScore: yesterdayScore,
      sevenDayAverage: sevenDayAverage,
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
  final profile = ref.watch(profileProvider);
  final targetWeight = profile.targetWeight ?? 0.0;
  final targetCalories = profile.targetCalories;

  // To compute yesterday/7-day avg, we need past logs.
  final sevenDaysAgoStr = DateFormat(
    'yyyy-MM-dd',
  ).format(date.subtract(const Duration(days: 7)));
  final allDailyLogs = ref.watch(
    dailyLogsRangeProvider((sevenDaysAgoStr, dateStr)),
  );
  final allMealLogs = ref.watch(
    dailyMealLogsRangeProvider((sevenDaysAgoStr, dateStr)),
  );

  int? yesterdayScore;
  int? sevenDayAverage;

  if (!date.isAfter(DateTime.now())) {
    final yesterdayStr = DateFormat(
      'yyyy-MM-dd',
    ).format(date.subtract(const Duration(days: 1)));

    // Helper to calculate score for a specific date in the past
    int? calcScoreForDate(DateTime d) {
      final dStr = DateFormat('yyyy-MM-dd').format(d);
      // Skip if completely inactive (no daily log, no meal log, no habit completions)
      final hasDailyLog = allDailyLogs.any((l) => l.date == dStr);
      final hasMealLog = allMealLogs.any((l) => l.date == dStr);
      final completions = ref.read(habitRepoProvider).getCompletions(dStr);
      if (!hasDailyLog && !hasMealLog && completions.completions.isEmpty)
        return null;

      final log = allDailyLogs.firstWhere(
        (l) => l.date == dStr,
        orElse: () => DailyLog(date: dStr),
      );
      final mLog = allMealLogs.firstWhere(
        (l) => l.date == dStr,
        orElse: () => DailyMealLog(date: dStr),
      );

      return DailyScore.calculate(
        date: d,
        dateStr: dStr,
        habits: habits,
        habitCompletions: completions,
        dailyLog: log,
        workoutPlan: workoutPlan,
        logRepo: logRepo,
        mealPlan: mealPlan,
        mealLog: mLog,
        targetWeight: targetWeight,
        targetCalories: targetCalories,
        dailyLogRepo: dailyLogRepo,
      ).totalScore;
    }

    yesterdayScore = calcScoreForDate(date.subtract(const Duration(days: 1)));

    int sum = 0;
    int count = 0;
    for (int i = 1; i <= 7; i++) {
      final pastDate = date.subtract(Duration(days: i));
      final s = calcScoreForDate(pastDate);
      if (s != null) {
        sum += s;
        count++;
      }
    }
    if (count > 0) {
      sevenDayAverage = (sum / count).round();
    }
  }

  final todayScore = DailyScore.calculate(
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
    targetCalories: targetCalories,
    dailyLogRepo: dailyLogRepo,
  );

  return todayScore.copyWithContext(
    yesterdayScore: yesterdayScore,
    sevenDayAverage: sevenDayAverage,
  );
});

final todayScoreProvider = Provider<DailyScore>((ref) {
  final date = DateTime.now();
  final dateStr = DateFormat('yyyy-MM-dd').format(date);

  final habits = ref.watch(habitsProvider);
  final habitCompletions = ref.watch(habitCompletionsProvider);
  // Need to get today's daily log explicitly, instead of dailyLogProvider which tracks selectedDate
  final dailyLogRepo = ref.watch(dailyLogRepoProvider);
  final dailyLog = dailyLogRepo.getOrCreate(dateStr);

  final workoutPlan = ref.watch(workoutPlanProvider);
  final logRepo = ref.watch(exerciseLogRepoProvider);
  ref.watch(exerciseLogsUpdateProvider);

  final mealPlan = ref.watch(mealPlanProvider);
  // Need today's meal log explicitly
  final mealLogs = ref.watch(dailyMealLogsRangeProvider((dateStr, dateStr)));
  final mealLog = mealLogs.isNotEmpty ? mealLogs.first : DailyMealLog(date: dateStr);

  final profile = ref.watch(profileProvider);
  final targetWeight = profile.targetWeight ?? 0.0;
  final targetCalories = profile.targetCalories;

  final sevenDaysAgoStr = DateFormat('yyyy-MM-dd').format(date.subtract(const Duration(days: 7)));
  final allDailyLogs = ref.watch(dailyLogsRangeProvider((sevenDaysAgoStr, dateStr)));
  final allMealLogs = ref.watch(dailyMealLogsRangeProvider((sevenDaysAgoStr, dateStr)));

  int? sevenDayAverage;
  int sum = 0;
  int count = 0;
  for (int i = 1; i <= 7; i++) {
    final pastDate = date.subtract(Duration(days: i));
    final dStr = DateFormat('yyyy-MM-dd').format(pastDate);
    final hasDailyLog = allDailyLogs.any((l) => l.date == dStr);
    final hasMealLog = allMealLogs.any((l) => l.date == dStr);
    final completions = ref.read(habitRepoProvider).getCompletions(dStr);
    if (!hasDailyLog && !hasMealLog && completions.completions.isEmpty) continue;

    final log = allDailyLogs.firstWhere((l) => l.date == dStr, orElse: () => DailyLog(date: dStr));
    final mLog = allMealLogs.firstWhere((l) => l.date == dStr, orElse: () => DailyMealLog(date: dStr));

    final s = DailyScore.calculate(
      date: pastDate,
      dateStr: dStr,
      habits: habits,
      habitCompletions: completions,
      dailyLog: log,
      workoutPlan: workoutPlan,
      logRepo: logRepo,
      mealPlan: mealPlan,
      mealLog: mLog,
      targetWeight: targetWeight,
      targetCalories: targetCalories,
      dailyLogRepo: dailyLogRepo,
    ).totalScore;
    sum += s;
    count++;
  }
  if (count > 0) sevenDayAverage = (sum / count).round();

  final todayScore = DailyScore.calculate(
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
    targetCalories: targetCalories,
    dailyLogRepo: dailyLogRepo,
  );

  return todayScore.copyWithContext(sevenDayAverage: sevenDayAverage);
});

