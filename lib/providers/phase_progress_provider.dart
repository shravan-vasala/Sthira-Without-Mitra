import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'app_providers.dart';
import '../models/daily_log.dart';
import '../utils/workout_completion.dart';
import '../models/workout_plan.dart';

class PhaseProgress {
  final int currentWeek;
  final int totalWeeks;
  final int completedDaysThisWeek;
  final int requiredDaysPerWeek;
  final bool isPhaseActive;
  final bool isPhaseComplete;

  PhaseProgress({
    required this.currentWeek,
    required this.totalWeeks,
    required this.completedDaysThisWeek,
    required this.requiredDaysPerWeek,
    required this.isPhaseActive,
    required this.isPhaseComplete,
  });

  bool get isWeekComplete => completedDaysThisWeek >= requiredDaysPerWeek;
}

final phaseProgressProvider = Provider<PhaseProgress>((ref) {
  final profile = ref.watch(profileProvider);
  final dateStr = ref.watch(dateStringProvider);
  final dailyLogRepo = ref.watch(dailyLogRepoProvider);

  // Rebuild if logs change
  ref.watch(dailyLogProvider);

  final workoutPlan = ref.watch(workoutPlanProvider);
  
  int totalWeeks = 1;
  bool isPhaseActive = false;

  if (workoutPlan != null) {
    if (workoutPlan.weeks != null && workoutPlan.weeks!.isNotEmpty) {
      totalWeeks = workoutPlan.weeks!.length;
      isPhaseActive = true;
    } else if (workoutPlan.durationWeeks != null) {
      totalWeeks = workoutPlan.durationWeeks!;
      isPhaseActive = true;
    }
  }

  if (profile.planStartDate == null) {
    return PhaseProgress(
      currentWeek: 1,
      totalWeeks: totalWeeks,
      completedDaysThisWeek: 0,
      requiredDaysPerWeek: 4, // Will be computed correctly below if active
      isPhaseActive: false,
      isPhaseComplete: false,
    );
  }

  final today = DateTime.parse(dateStr);

  // Strip time from start date just in case
  final startDate = DateTime(
    profile.planStartDate!.year,
    profile.planStartDate!.month,
    profile.planStartDate!.day,
  );

  final daysSinceStart = today.difference(startDate).inDays;

  // If today is before start date (shouldn't happen, but just in case)
  if (daysSinceStart < 0) {
    return PhaseProgress(
      currentWeek: 1,
      totalWeeks: totalWeeks,
      completedDaysThisWeek: 0,
      requiredDaysPerWeek: 4, // default
      isPhaseActive: true,
      isPhaseComplete: false,
    );
  }

  int calculatedWeek = (daysSinceStart ~/ 7) + 1;
  final currentWeek = calculatedWeek > totalWeeks ? totalWeeks : calculatedWeek;
  final weekStartDate = startDate.add(Duration(days: (calculatedWeek - 1) * 7));

  final exerciseLogRepo = ref.watch(exerciseLogRepoProvider);
  ref.watch(exerciseLogsUpdateProvider); // rebuild on log changes

  int completedDaysThisWeek = 0;
  int requiredDaysPerWeek = 4; // Default fallback

  if (workoutPlan != null && workoutPlan.days.isNotEmpty) {
    // Determine the days to use for calculating required days
    List<WorkoutDay> weekDays = workoutPlan.days;
    if (workoutPlan.weeks != null && workoutPlan.weeks!.isNotEmpty) {
      final weekIndex = currentWeek > 0 && currentWeek <= workoutPlan.weeks!.length 
          ? currentWeek - 1 
          : workoutPlan.weeks!.length - 1;
      weekDays = workoutPlan.weeks![weekIndex].days;
    }
    
    // Count non-rest days
    requiredDaysPerWeek = 0;
    for (final d in weekDays) {
      if (!WorkoutCompletion.isRestDay(d, today)) {
        requiredDaysPerWeek++;
      }
    }
    // Prevent zero required days if plan is weird
    if (requiredDaysPerWeek == 0) requiredDaysPerWeek = 1;
  }

  for (int i = 0; i < 7; i++) {
    final checkDate = weekStartDate.add(Duration(days: i));
    if (checkDate.isAfter(today)) break; // Don't check future days

    final checkStr = DateFormat('yyyy-MM-dd').format(checkDate);
    final log = dailyLogRepo.getLog(checkStr) ?? DailyLog(date: checkStr);

    if (workoutPlan != null && workoutPlan.days.isNotEmpty) {
      final day = WorkoutCompletion.resolveWorkoutDay(
        workoutPlan, 
        checkDate,
        currentWeek: currentWeek,
      );
      if (WorkoutCompletion.isDayWorkoutDoneWithRepo(
        date: checkStr,
        day: day,
        dateTime: checkDate,
        repo: exerciseLogRepo,
        dailyLog: log,
      )) {
        completedDaysThisWeek++;
      }
    } else {
      if (log.workoutCompleted) {
        completedDaysThisWeek++;
      }
    }
  }

  return PhaseProgress(
    currentWeek: currentWeek,
    totalWeeks: totalWeeks,
    completedDaysThisWeek: completedDaysThisWeek,
    requiredDaysPerWeek: requiredDaysPerWeek,
    isPhaseActive: true,
    isPhaseComplete: calculatedWeek > totalWeeks,
  );
});
