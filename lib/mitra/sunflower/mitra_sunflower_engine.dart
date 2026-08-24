import 'mitra_sunflower.dart';
import 'mitra_sunflower_context.dart';
import 'mitra_sunflower_progress.dart';
import 'mitra_sunflower_snapshot.dart';
import 'mitra_sunflower_state.dart';

class MitraSunflowerEngine {
  final MitraSunflowerContext _context = MitraSunflowerContext();
  MitraSunflowerSnapshot? _lastSnapshot;

  MitraSunflowerContext get debugContext => _context;
  MitraSunflowerSnapshot? get currentSnapshot => _lastSnapshot;

  void addContribution({
    int steps = 0,
    int water = 0,
    int sleep = 0,
    int workout = 0,
    int habit = 0,
    int nutrition = 0,
    MitraSunflowerTimeOfDay? timeOfDayOverride,
  }) {
    final now = DateTime.now();
    _context.addContribution(
      steps: steps,
      water: water,
      sleep: sleep,
      workout: workout,
      habit: habit,
      nutrition: nutrition,
      now: now,
    );
    _evaluate(now, timeOfDayOverride);
  }

  void setAbsoluteProgress(
    double coreProgress,
    SupportingWellnessContext supportingContext, {
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    _context.setAbsoluteProgress(coreProgress, supportingContext, t);
    _evaluate(t);
  }

  void forceTimeOfDay(MitraSunflowerTimeOfDay timeOfDay) {
    _evaluate(DateTime.now(), timeOfDay);
  }

  void simulateNewDay() {
    _context.simulateNewDay();
    _evaluate(DateTime.now());
  }

  void resetDay() {
    _context.forceReset();
    _evaluate(DateTime.now());
  }

  void _evaluate(DateTime now, [MitraSunflowerTimeOfDay? timeOverride]) {
    final timeOfDay = timeOverride ?? _deriveTimeOfDay(now);
    final category = _context.progress.category;
    
    MitraSunflowerState nextState = _determineBaseState(category);
    
    // Apply time-of-day modulations (No aggressive regression, just resting/settling)
    if (timeOfDay == MitraSunflowerTimeOfDay.evening) {
      if (nextState == MitraSunflowerState.fullBloom || nextState == MitraSunflowerState.blooming) {
        nextState = MitraSunflowerState.resting;
      }
    } else if (timeOfDay == MitraSunflowerTimeOfDay.night) {
      nextState = MitraSunflowerState.resting;
    }
    
    // If it's a new day and no progress, it should be in seed/sprout
    if (category == MitraDailyProgressCategory.none && 
        timeOfDay != MitraSunflowerTimeOfDay.night && 
        timeOfDay != MitraSunflowerTimeOfDay.evening) {
      nextState = MitraSunflowerState.seed;
    }
    
    // Ensure we don't wildly thrash. 
    // We only transition if there's an actual change in the snapshot.
    final candidate = MitraSunflowerSnapshot(
      state: nextState,
      progress: _context.progress,
      timeOfDay: timeOfDay,
    );

    if (_lastSnapshot != candidate) {
      String reason = "Time of day: ${timeOfDay.name}, Category: ${category.name}";
      _context.recordTransition(now, reason);
      _lastSnapshot = candidate;
    }
  }

  MitraSunflowerState _determineBaseState(MitraDailyProgressCategory category) {
    switch (category) {
      case MitraDailyProgressCategory.none:
        return MitraSunflowerState.seed;
      case MitraDailyProgressCategory.small:
        return MitraSunflowerState.sprout;
      case MitraDailyProgressCategory.steady:
        return MitraSunflowerState.youngPlant;
      case MitraDailyProgressCategory.meaningful:
        return MitraSunflowerState.growing;
      case MitraDailyProgressCategory.strong:
        return MitraSunflowerState.blooming;
      case MitraDailyProgressCategory.exceptional:
        return MitraSunflowerState.fullBloom;
    }
  }

  MitraSunflowerTimeOfDay _deriveTimeOfDay(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) return MitraSunflowerTimeOfDay.morning;
    if (hour >= 12 && hour < 17) return MitraSunflowerTimeOfDay.afternoon;
    if (hour >= 17 && hour < 21) return MitraSunflowerTimeOfDay.evening;
    return MitraSunflowerTimeOfDay.night;
  }
}
