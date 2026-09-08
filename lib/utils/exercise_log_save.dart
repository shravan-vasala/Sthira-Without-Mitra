import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout_plan.dart';
import '../models/exercise_log.dart';
import '../models/exercise_pr.dart';
import '../providers/app_providers.dart';
import '../services/widget_update_service.dart';

Future<PrUpdateResult> saveExerciseAsPlanned({
  required WidgetRef ref,
  required Exercise exercise,
}) async {
  final dateStr = ref.read(dateStringProvider);
  final repo = ref.read(exerciseLogRepoProvider);
  // ignore: unused_local_variable
  final profile = ref.read(profileProvider);

  // Parse planned reps
  int reps = 0;
  final numMatch = RegExp(r'\d+').firstMatch(exercise.repsDisplay ?? '');
  if (numMatch != null) reps = int.parse(numMatch.group(0)!);

  // Build sets (copying weight from last log if needed)
  final lastLog = repo.getLastLog(exercise.name ?? '');
  final List<SetLog> sets = [];
  for (int i = 0; i < exercise.setCount; i++) {
    double weight = exercise.weightKg ?? 0.0;
    if (exercise.weightKg == null &&
        lastLog != null &&
        i < lastLog.sets.length) {
      weight = lastLog.sets[i].weight ?? 0.0;
    }
    sets.add(SetLog(setNumber: i + 1, reps: reps, weight: weight));
  }

  final newLog = ExerciseLog(
    date: dateStr,
    exerciseName: exercise.name ?? '',
    sets: sets,
  );

  await repo.saveLog(newLog);
  ref.read(exerciseLogsUpdateProvider.notifier).state++;
  WidgetUpdateService.pushWidgetState(ref);

  return await checkAndSavePr(ref: ref, exerciseName: exercise.name ?? '', sets: sets);
}

Future<PrUpdateResult> checkAndSavePr({
  required WidgetRef ref,
  required String exerciseName,
  required List<SetLog> sets,
}) async {
  final repo = ref.read(exerciseLogRepoProvider);
  final isCompletedSet = sets;
  if (isCompletedSet.isEmpty) {
    return PrUpdateResult(
      hasAnyNewPr: false,
      newPr: ExercisePr(exerciseName: exerciseName),
    );
  }

  final maxWeight = isCompletedSet
      .map((s) => s.weight ?? 0.0)
      .reduce((a, b) => a > b ? a : b);
  final maxReps = isCompletedSet
      .map((s) => s.reps ?? 0)
      .reduce((a, b) => a > b ? a : b);
  final totalVolume = isCompletedSet.fold(
    0.0,
    (sum, s) => sum + ((s.weight ?? 0.0) * (s.reps ?? 0)),
  );
  final oneRM = isCompletedSet
      .map((s) => (s.weight ?? 0.0) * (1 + ((s.reps ?? 0) / 30)))
      .reduce((a, b) => a > b ? a : b);

  final currentPr = repo.getPr(exerciseName);

  bool newW = false, newR = false, newV = false, new1RM = false;
  var updatedPr = currentPr ?? ExercisePr(exerciseName: exerciseName);

  if (maxWeight > updatedPr.maxWeight) {
    updatedPr = updatedPr.copyWith(maxWeight: maxWeight);
    newW = true;
  }
  if (maxReps > updatedPr.maxReps) {
    updatedPr = updatedPr.copyWith(maxReps: maxReps);
    newR = true;
  }
  if (totalVolume > updatedPr.maxVolume) {
    updatedPr = updatedPr.copyWith(maxVolume: totalVolume);
    newV = true;
  }
  if (oneRM > updatedPr.estimated1RM) {
    updatedPr = updatedPr.copyWith(estimated1RM: oneRM);
    new1RM = true;
  }

  final hasAnyNewPr = newW || newR || newV || new1RM;
  if (hasAnyNewPr) {
    await repo.savePr(updatedPr);
  }

  return PrUpdateResult(
    hasAnyNewPr: hasAnyNewPr,
    isNewMaxWeight: newW,
    isNewMaxReps: newR,
    isNewMaxVolume: newV,
    isNew1RM: new1RM,
    newPr: updatedPr,
  );
}

class PrUpdateResult {
  final bool hasAnyNewPr;
  final bool isNewMaxWeight;
  final bool isNewMaxReps;
  final bool isNewMaxVolume;
  final bool isNew1RM;
  final ExercisePr newPr;

  PrUpdateResult({
    this.hasAnyNewPr = false,
    this.isNewMaxWeight = false,
    this.isNewMaxReps = false,
    this.isNewMaxVolume = false,
    this.isNew1RM = false,
    required this.newPr,
  });
}

Map<String, dynamic> getExerciseChartData(WidgetRef ref, Exercise exercise) {
  final repo = ref.read(exerciseLogRepoProvider);
  return {
    'allLogs': repo.getLogsForExercise(exercise.name ?? ''),
    'pr': repo.getPr(exercise.name ?? ''),
  };
}
