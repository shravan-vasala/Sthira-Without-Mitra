import '../models/daily_log.dart';
import '../models/workout_plan.dart';
import '../models/exercise_log.dart';
import '../repositories/exercise_log_repository.dart';

/// Shared workout completion rules (Approach A):
/// - [ExerciseLog] is the source of truth for exercise/section completion.
/// - [DailyLog.workoutCompleted] is the day-level Finish flag (full or early).
/// - Planned rest days count as done for scoring / day-done checks.
class WorkoutCompletion {
  /// A day with no workout sections.
  static bool isRestDay(WorkoutDay day, DateTime date) {
    return day.sections.isEmpty;
  }

  /// Whether the logged work has non-zero positive effort.
  static bool hasMeaningfulWork(ExerciseLog log) {
    if (log.sets.isEmpty) return false;
    for (final s in log.sets) {
      if ((s.reps ?? 0) > 0 || (s.weight ?? 0.0) > 0) return true;
    }
    return false;
  }

  /// Resolves the scheduled [WorkoutDay] for [date] using stored schedule semantics.
  static WorkoutDay resolveWorkoutDay(WorkoutPlan plan, DateTime date) {
    // 1. Find a day matching the explicit weekday
    for (final day in plan.days) {
      if (day.weekday == date.weekday) {
        return day;
      }
    }

    // 2. If no weekday match, maybe fallback to 'Rest'
    for (final day in plan.days) {
      if (day.dayId?.toLowerCase() == 'rest') {
        return day;
      }
    }

    // 3. Last resort fallback
    return WorkoutDay(dayId: 'Rest', label: 'Rest Day', sections: []);
  }

  static bool isSectionComplete(
    String date,
    WorkoutSection section,
    bool Function(String date, String instanceId) hasLog,
  ) {
    return section.exercises.isNotEmpty &&
        section.exercises.every((ex) => hasLog(date, ex.instanceId ?? ''));
  }

  static bool isSectionCompleteWithRepo(
    String date,
    WorkoutSection section,
    ExerciseLogRepository repo,
  ) {
    return isSectionComplete(date, section, repo.hasLog);
  }

  /// True when every section on a training day has all exercises logged.
  static bool isTrainingDayComplete(
    String date,
    WorkoutDay day,
    bool Function(String date, String instanceId) hasLog,
  ) {
    if (day.sections.isEmpty) return false;
    return day.sections.every((sec) => isSectionComplete(date, sec, hasLog));
  }

  static bool isTrainingDayCompleteWithRepo(
    String date,
    WorkoutDay day,
    ExerciseLogRepository repo,
  ) {
    return isTrainingDayComplete(date, day, repo.hasLog);
  }

  /// Day-level "workout done" for score / summaries.
  /// Rest → always true (planned rest). Training → all logs or Finish flag.
  static bool isDayWorkoutDone({
    required String date,
    required WorkoutDay day,
    required DateTime dateTime,
    required bool Function(String date, String instanceId) hasLog,
    required DailyLog dailyLog,
  }) {
    if (isRestDay(day, dateTime)) return true;
    return isTrainingDayComplete(date, day, hasLog) ||
        dailyLog.workoutCompleted;
  }

  static bool isDayWorkoutDoneWithRepo({
    required String date,
    required WorkoutDay day,
    required DateTime dateTime,
    required ExerciseLogRepository repo,
    required DailyLog dailyLog,
  }) {
    return isDayWorkoutDone(
      date: date,
      day: day,
      dateTime: dateTime,
      hasLog: repo.hasLog,
      dailyLog: dailyLog,
    );
  }

  /// Count of fully logged sections on a training day.
  static int completedSectionCount(
    String date,
    WorkoutDay day,
    bool Function(String date, String instanceId) hasLog,
  ) {
    var count = 0;
    for (final sec in day.sections) {
      if (isSectionComplete(date, sec, hasLog)) count++;
    }
    return count;
  }
}
