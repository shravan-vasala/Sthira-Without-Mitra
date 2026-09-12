import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../models/daily_log.dart';
import '../models/habit.dart';
import '../utils/workout_completion.dart';
import '../utils/time_utils.dart';
import '../utils/format_units.dart';

final widgetCoordinatorProvider = Provider<WidgetCoordinator>((ref) {
  final coordinator = WidgetCoordinator(ref);
  ref.onDispose(() => coordinator.dispose());
  return coordinator;
});

class WidgetCoordinator {
  final Ref _ref;
  Timer? _debounceTimer;
  final List<StreamSubscription> _subs = [];

  WidgetCoordinator(this._ref) {
    _initListeners();
    // Schedule an initial update on boot
    _scheduleUpdate();
  }

  void _initListeners() {
    final dailyLogRepo = _ref.read(dailyLogRepoProvider);
    final mealRepo = _ref.read(mealRepoProvider);
    final habitRepo = _ref.read(habitRepoProvider);
    final exerciseLogRepo = _ref.read(exerciseLogRepoProvider);

    _subs.add(dailyLogRepo.watchUpdates.listen((_) => _scheduleUpdate()));
    _subs.add(mealRepo.watchUpdates.listen((_) => _scheduleUpdate()));
    _subs.add(habitRepo.watchUpdates.listen((_) => _scheduleUpdate()));
    _subs.add(exerciseLogRepo.watchUpdates.listen((_) => _scheduleUpdate()));
  }

  void _scheduleUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), _pushSnapshot);
  }

  Future<void> _pushSnapshot() async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      
      final profile = _ref.read(profileProvider);
      final dailyLogRepo = _ref.read(dailyLogRepoProvider);
      final mealRepo = _ref.read(mealRepoProvider);
      final habitRepo = _ref.read(habitRepoProvider);
      final workoutRepo = _ref.read(workoutRepoProvider);
      final exerciseLogRepo = _ref.read(exerciseLogRepoProvider);

      final log = dailyLogRepo.getLog(todayStr);

      // --- 1. Steps ---
      final steps = log?.steps;
      
      // Real step goal derived from habit configuration
      final habits = habitRepo.getHabits();
      final stepHabit = habits.cast<Habit?>().firstWhere(
            (h) => h?.type == HabitType.step,
            orElse: () => null,
          );
      final stepGoal = stepHabit?.targetValue.toInt() ?? 0;

      // --- 2. Meals ---
      final mealPlan = mealRepo.getMealPlan(
        profile.activeMealPlan ?? 'Daily Nutrition Plan',
      );
      final mealLog = mealRepo.getDailyLog(todayStr);

      // Count only slots with actual items or photos
      int mealsLogged = mealLog.customSlots.values
          .where((slot) => slot.items.isNotEmpty || slot.photoPath != null)
          .length;
      
      int totalMeals = mealPlan?.meals.length ?? 4;
      // Add extra custom slots to the total if the user added more today
      int extraSlots = mealLog.customSlots.keys.where((id) {
        return mealPlan?.meals.every((m) => m.id != id) ?? true;
      }).length;
      totalMeals += extraSlots;

      // Nutrition totals
      double totalCal = 0;
      double totalProtein = 0;
      for (final slot in mealLog.customSlots.values) {
        if (slot.calories != null) totalCal += slot.calories!;
        if (slot.protein != null) totalProtein += slot.protein!;
      }

      // --- 3. Habits ---
      // We only care about habits scheduled for today
      final dayOfWeek = now.weekday; // 1=Mon, 7=Sun
      final activeHabitsForToday = habits.where((h) {
        if (h.createdAt.isAfter(now) && DateFormat('yyyy-MM-dd').format(h.createdAt) != todayStr) {
          return false;
        }
        return h.scheduledDays.contains(dayOfWeek);
      }).toList();

      final completions = habitRepo.getCompletions(todayStr);
      int habitsDone = activeHabitsForToday.where((h) {
        return isHabitCompleted(h, completions, log ?? DailyLog(date: todayStr));
      }).length;
      int totalHabits = activeHabitsForToday.length;

      // --- 4. Workout ---
      final activePlan = workoutRepo.getActivePlan(
        preferredKey: profile.activeWorkoutPlan,
      );
      
      bool isRest = false;
      String workoutTitle = "No Plan";
      String workoutStatus = "Tap to view";
      
      if (log?.workoutCompleted == true) {
        workoutTitle = "Workout Done";
        workoutStatus = "Great job!";
      } else if (activePlan != null) {
        final workoutDay = WorkoutCompletion.resolveWorkoutDay(activePlan, now);
        isRest = WorkoutCompletion.isRestDay(workoutDay, now);
        
        if (isRest) {
          workoutTitle = "Rest Day";
          workoutStatus = "Recovery";
        } else {
          final isDone = WorkoutCompletion.isTrainingDayCompleteWithRepo(
            todayStr,
            workoutDay,
            exerciseLogRepo,
          );
          if (isDone) {
            workoutTitle = "Workout Done";
            workoutStatus = "Great job!";
          } else {
            workoutTitle = workoutDay.label ?? 'Workout';
            workoutStatus = "Pending";
          }
        }
      }

      // Build JSON Snapshot
      final snapshot = {
        'date': todayStr,
        'updatedAt': DateFormat('HH:mm').format(now),
        
        'steps': steps,
        'stepGoal': stepGoal > 0 ? stepGoal : null,
        
        'mealsLogged': mealsLogged,
        'totalMeals': totalMeals > 0 ? totalMeals : 0,
        
        'habitsDone': habitsDone,
        'totalHabits': totalHabits,
        
        'energy': totalCal > 0 ? totalCal : null,
        'protein': totalProtein > 0 ? totalProtein : null,
        
        'isRest': isRest,
        'workoutTitle': workoutTitle,
        'workoutStatus': workoutStatus,
      };

      await HomeWidget.saveWidgetData<String>('widget_data', jsonEncode(snapshot));
      await HomeWidget.updateWidget(
        androidName: 'TrufitWidgetProvider',
      );
    } catch (e) {
      debugPrint('WidgetCoordinator error: $e');
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    for (var sub in _subs) {
      sub.cancel();
    }
  }
}
