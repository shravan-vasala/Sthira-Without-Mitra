// ignore_for_file: avoid_dynamic_calls
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../models/daily_log.dart';
import '../providers/meal_providers.dart';
import '../models/habit.dart';
import '../utils/workout_completion.dart';

class WidgetUpdateService {
  static Timer? _debounceTimer;

  static void pushWidgetState(dynamic ref) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      try {
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        final dailyLogRepo = ref.read(dailyLogRepoProvider);
        final log = dailyLogRepo.getLog(todayStr);

        final steps = log?.steps ?? 0;
        final stepsProgress = steps > 0
            ? ((steps / 10000.0) * 100).clamp(0, 100).toInt()
            : 0;
        final stepsStr = steps >= 1000
            ? '${(steps / 1000.0).toStringAsFixed(1)}k'
            : steps.toString();

        final workoutRepo = ref.read(workoutRepoProvider);
        final profile = ref.read(profileProvider);
        final activePlan = workoutRepo.getActivePlan(
          preferredKey: profile.activeWorkoutPlan,
        );

        String workoutText = "Workout";
        String workoutSubText = "Pending";

        if (log?.workoutCompleted == true) {
          workoutText = "Done";
          workoutSubText = "Great job!";
        } else if (activePlan != null) {
          final workoutDay = WorkoutCompletion.resolveWorkoutDay(
            activePlan,
            now,
          );
          final isRest = WorkoutCompletion.isRestDay(workoutDay, now);

          if (isRest) {
            workoutText = "Rest";
            workoutSubText = "Recovery";
          } else {
            final eLogRepo = ref.read(exerciseLogRepoProvider);
            final isDone = WorkoutCompletion.isTrainingDayCompleteWithRepo(
              todayStr,
              workoutDay,
              eLogRepo,
            );
            if (isDone) {
              workoutText = "Done";
              workoutSubText = "Great job!";
            } else {
              workoutText = workoutDay.label ?? '';
              workoutSubText = "Tap to start";
            }
          }
        }

        final mealRepo = ref.read(mealRepoProvider);
        final mealPlan = mealRepo.getMealPlan(
          profile.activeMealPlan ?? 'Daily Nutrition Plan',
        );
        final mealLog = mealRepo.getDailyLog(todayStr);

        int mealsLogged = mealLog.customSlots.values
            .where((slot) => slot.foods.isNotEmpty)
            .length;
        int totalMeals = mealPlan?.meals.length ?? 4;
        String mealsText = "$mealsLogged/$totalMeals";

        final habitRepo = ref.read(habitRepoProvider);
        final activeHabits = habitRepo.getHabits();
        final completions = habitRepo.getCompletions(todayStr);

        int habitsDone = activeHabits
            .where(
              (h) => isHabitCompleted(
                h,
                completions,
                log ?? DailyLog(date: todayStr),
              ),
            )
            .length;
        int totalHabits = activeHabits.length;
        String habitsText = "$habitsDone/$totalHabits";

        await HomeWidget.saveWidgetData<String>('date', todayStr);
        await HomeWidget.saveWidgetData<String>('stepsStr', stepsStr);
        await HomeWidget.saveWidgetData<int>('stepsProgress', stepsProgress);
        await HomeWidget.saveWidgetData<String>('workoutText', workoutText);
        await HomeWidget.saveWidgetData<String>(
          'workoutSubText',
          workoutSubText,
        );
        await HomeWidget.saveWidgetData<String>('mealsText', mealsText);
        await HomeWidget.saveWidgetData<String>('habitsText', habitsText);

        await HomeWidget.updateWidget(
          androidName: 'TrufitWidgetProvider',
          iOSName: 'TrufitWidget',
        );
      } catch (e) {
        debugPrint('WidgetUpdateService error: $e');
      }
    });
  }
}
