import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';
import '../models/workout_plan.dart';
import '../models/exercise_log.dart';
import '../models/exercise_pr.dart';
import '../utils/workout_completion.dart';

final workoutPlanProvider = Provider<WorkoutPlan?>((ref) {
  final repo = ref.watch(workoutRepoProvider);
  final activePlanId = ref.watch(
    profileProvider.select((p) => p.activeWorkoutPlan),
  );
  return repo.getActivePlan(preferredKey: activePlanId ?? 'beginner_plan');
});

final workoutDayProvider = Provider.family<WorkoutDay?, String>((ref, dayId) {
  return ref.watch(workoutRepoProvider).getWorkoutDay(dayId);
});

final resolvedWorkoutDayProvider = Provider.family<WorkoutDay?, DateTime>((
  ref,
  date,
) {
  final plan = ref.watch(workoutPlanProvider);
  if (plan == null) return null;
  return WorkoutCompletion.resolveWorkoutDay(plan, date);
});

// Keep as StateProvider to avoid breaking UI code that uses .state++
final exerciseLogsUpdateProvider = StateProvider<int>((ref) => 0);

final exerciseHistoryProvider = Provider.family<List<ExerciseLog>, String>((
  ref,
  exerciseName,
) {
  ref.watch(exerciseLogsUpdateProvider);
  return ref.watch(exerciseLogRepoProvider).getLogsForExercise(exerciseName);
});

final exercisePrProvider = Provider.family<ExercisePr?, String>((
  ref,
  exerciseName,
) {
  ref.watch(exerciseLogsUpdateProvider);
  // Watch logRepo to rebuild when PR updates
  final repo = ref.watch(exerciseLogRepoProvider);
  return repo.getPr(exerciseName);
});
