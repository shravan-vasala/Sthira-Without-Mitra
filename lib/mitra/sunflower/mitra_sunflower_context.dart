import 'mitra_sunflower_progress.dart';
import 'mitra_sunflower.dart';

class MitraSunflowerContext {
  DateTime? currentDay;
  MitraSunflowerProgress progress = const MitraSunflowerProgress();
  DateTime? lastTransitionTime;
  String? lastTransitionReason;

  void updateProgress(MitraSunflowerProgress newProgress, DateTime now) {
    if (currentDay == null || _isNewDay(now)) {
      _resetForNewDay(now);
    }
    progress = newProgress;
  }

  void addContribution({
    int steps = 0,
    int water = 0,
    int sleep = 0,
    int workout = 0,
    int habit = 0,
    int nutrition = 0,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    if (currentDay == null || _isNewDay(t)) {
      _resetForNewDay(t);
    }

    final newTotal = progress.totalContribution + steps + water + sleep + workout + habit + nutrition;
    MitraDailyProgressCategory newCategory = progress.category;

    if (newTotal > 100) {
      newCategory = MitraDailyProgressCategory.exceptional;
    } else if (newTotal > 75) {
      newCategory = MitraDailyProgressCategory.strong;
    } else if (newTotal > 40) {
      newCategory = MitraDailyProgressCategory.meaningful;
    } else if (newTotal > 20) {
      newCategory = MitraDailyProgressCategory.steady;
    } else if (newTotal > 0) {
      newCategory = MitraDailyProgressCategory.small;
    }

    progress = progress.copyWith(
      stepsContribution: progress.stepsContribution + steps,
      waterContribution: progress.waterContribution + water,
      sleepContribution: progress.sleepContribution + sleep,
      workoutContribution: progress.workoutContribution + workout,
      habitContribution: progress.habitContribution + habit,
      nutritionContribution: progress.nutritionContribution + nutrition,
      category: newCategory,
    );
  }

  void setAbsoluteProgress(
    double coreProgress,
    SupportingWellnessContext supportingContext,
    DateTime now,
  ) {
    if (currentDay == null || _isNewDay(now)) {
      _resetForNewDay(now);
    }

    // Clamp core progress 0.0 to 1.0
    final double clampedCore = coreProgress.clamp(0.0, 1.0);

    // Phase 12 calculates its own category based on the exact same approved thresholds.
    // > 100/100 threshold is reserved, so it cannot be reached by core alone (which maxes at 1.0).
    // The prompt says: "DO NOT change the thresholds as part of Phase 14... 
    // coreProgress determines the main category. supportingContext enriches the input for future visual expression."
    // We will preserve the existing percentages: 1.0 is 100 points.
    final double virtualPoints = clampedCore * 100.0;
    MitraDailyProgressCategory newCategory = progress.category;

    if (virtualPoints > 100) { // Actually unreachable via core alone, preserving rarity
      newCategory = MitraDailyProgressCategory.exceptional;
    } else if (virtualPoints > 75) {
      newCategory = MitraDailyProgressCategory.strong;
    } else if (virtualPoints > 40) {
      newCategory = MitraDailyProgressCategory.meaningful;
    } else if (virtualPoints > 20) {
      newCategory = MitraDailyProgressCategory.steady;
    } else if (virtualPoints > 0) {
      newCategory = MitraDailyProgressCategory.small;
    }

    progress = progress.copyWith(
      coreProgress: clampedCore,
      supportingContext: supportingContext,
      category: newCategory,
    );
  }

  void recordTransition(DateTime time, String reason) {
    lastTransitionTime = time;
    lastTransitionReason = reason;
  }

  bool _isNewDay(DateTime now) {
    if (currentDay == null) return true;
    return now.year != currentDay!.year ||
           now.month != currentDay!.month ||
           now.day != currentDay!.day;
  }

  void _resetForNewDay(DateTime now) {
    currentDay = DateTime(now.year, now.month, now.day);
    progress = const MitraSunflowerProgress();
  }

  void simulateNewDay() {
    if (currentDay != null) {
      // Go back one day so the next event triggers a reset
      currentDay = currentDay!.subtract(const Duration(days: 1));
    }
  }

  void forceReset() {
    currentDay = null;
    progress = const MitraSunflowerProgress();
    lastTransitionTime = null;
    lastTransitionReason = null;
  }
}
