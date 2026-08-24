import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'app_providers.dart';
import '../models/daily_log.dart';
import '../models/daily_meal_log.dart';

final yearlyActivityHeatmapProvider = FutureProvider<Map<DateTime, int>>((ref) async {
  final result = <DateTime, int>{};
  
  // Get repositories and global plans
  final habitRepo = ref.watch(habitRepoProvider);
  final dailyLogRepo = ref.watch(dailyLogRepoProvider);
  final workoutRepo = ref.watch(workoutRepoProvider);
  final mealRepo = ref.watch(mealRepoProvider);
  final logRepo = ref.watch(exerciseLogRepoProvider);
  final profile = ref.watch(profileProvider);
  
  final habits = habitRepo.getHabits();
  final workoutPlan = workoutRepo.getActivePlan(preferredKey: profile.activeWorkoutPlan ?? 'beginner_plan');
  final mealPlan = mealRepo.getMealPlan(profile.activeMealPlan ?? 'standard_plan');

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  
  // Calculate for the past 365 days
  for (int i = 0; i < 365; i++) {
    // Yield to the event loop every 30 days to prevent main-thread jank
    if (i > 0 && i % 30 == 0) {
      await Future.delayed(Duration.zero);
    }

    final date = today.subtract(Duration(days: i));
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    final completions = habitRepo.getCompletions(dateStr);
    final dailyLog = dailyLogRepo.getLog(dateStr) ?? DailyLog(date: dateStr);
    final mealLog = mealRepo.getDailyLog(dateStr);
    
    final score = DailyScore.calculate(
      date: date,
      dateStr: dateStr,
      habits: habits,
      habitCompletions: completions,
      dailyLog: dailyLog,
      workoutPlan: workoutPlan,
      logRepo: logRepo,
      mealPlan: mealPlan,
      mealLog: mealLog,
      targetWeight: profile.targetWeight ?? 0.0,
      dailyLogRepo: dailyLogRepo,
    );
    
    result[date] = score.totalScore;
  }
  
  return result;
});
