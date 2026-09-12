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
    instanceId: exercise.instanceId ?? exercise.name ?? '',
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
  final allLogs = repo.getLogsForExercise(exerciseName);

  var calcMaxWeight = 0.0;
  var calcMaxReps = 0;
  var calcMaxVolume = 0.0;
  var calcEstimated1RM = 0.0;

  for (final log in allLogs) {
    var logVolume = 0.0;
    for (final s in log.sets) {
      final w = s.weight ?? 0.0;
      final r = s.reps ?? 0;
      if (w > calcMaxWeight) calcMaxWeight = w;
      if (r > calcMaxReps) calcMaxReps = r;
      logVolume += (w * r);
      final oneRM = w * (1 + (r / 30));
      if (oneRM > calcEstimated1RM) calcEstimated1RM = oneRM;
    }
    if (logVolume > calcMaxVolume) calcMaxVolume = logVolume;
  }

  final currentPr = repo.getPr(exerciseName);
  final oldW = currentPr?.maxWeight ?? 0.0;
  final oldR = currentPr?.maxReps ?? 0;
  final oldV = currentPr?.maxVolume ?? 0.0;
  final old1RM = currentPr?.estimated1RM ?? 0.0;

  final updatedPr = ExercisePr(
    exerciseName: exerciseName,
    maxWeight: calcMaxWeight,
    maxReps: calcMaxReps,
    maxVolume: calcMaxVolume,
    estimated1RM: calcEstimated1RM,
  );

  await repo.savePr(updatedPr);

  final newW = calcMaxWeight > oldW && calcMaxWeight > 0;
  final newR = calcMaxReps > oldR && calcMaxReps > 0;
  final newV = calcMaxVolume > oldV && calcMaxVolume > 0;
  final new1RM = calcEstimated1RM > old1RM && calcEstimated1RM > 0;
  final hasAnyNewPr = newW || newR || newV || new1RM;

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
