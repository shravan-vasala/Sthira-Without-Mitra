import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/daily_score_provider.dart';
import '../../../../providers/profile_providers.dart';
import 'mitra_daily_progress_snapshot.dart';
import '../mitra_sunflower_progress.dart';
import '../mitra_sunflower_state.dart';
import '../mitra_sunflower_engine.dart';
import 'mitra_sunflower_integration_engine.dart';

final sunflowerIntegrationProvider = Provider<MitraDailyProgressSnapshot>((ref) {
  final dateStr = ref.watch(dateStringProvider);
  final date = DateTime.parse(dateStr);
  
  final dailyScore = ref.watch(dailyScoreProvider);
  final dailyLog = ref.watch(dailyLogProvider);
  final profile = ref.watch(profileProvider);

  // 1. Core Score Normalization (0.0 - 1.0)
  final double coreDailyProgress = (dailyScore.totalScore / 100.0).clamp(0.0, 1.0);

  // 2. Supporting Metrics Normalization
  // Use existing targets if they were to exist in profile, otherwise defaults
  final double stepGoal = 10000.0;
  final double waterGoal = 2500.0;
  final double sleepGoal = 8.0;

  final int? steps = dailyLog.steps;
  final int? water = dailyLog.waterMl;
  final double? sleep = dailyLog.sleepHours;

  DataAvailability availability = DataAvailability.complete;
  if (steps == null && water == null && sleep == null) {
    availability = DataAvailability.unknown;
  } else if (steps == null || water == null || sleep == null) {
    availability = DataAvailability.partial;
  }

  double normalizedSteps = 0.0;
  double normalizedWater = 0.0;
  double normalizedSleep = 0.0;
  
  int knownMetricsCount = 0;
  double totalSupportingRatio = 0.0;

  if (steps != null) {
    normalizedSteps = (steps / stepGoal).clamp(0.0, 1.0);
    totalSupportingRatio += normalizedSteps;
    knownMetricsCount++;
  }

  if (water != null) {
    normalizedWater = (water / waterGoal).clamp(0.0, 1.0);
    totalSupportingRatio += normalizedWater;
    knownMetricsCount++;
  }

  if (sleep != null) {
    normalizedSleep = (sleep / sleepGoal).clamp(0.0, 1.0);
    totalSupportingRatio += normalizedSleep;
    knownMetricsCount++;
  }

  // Determine SupportingWellnessContext
  SupportingWellnessContext supportingContext = SupportingWellnessContext.neutral;
  if (knownMetricsCount > 0) {
    final double averageSupport = totalSupportingRatio / knownMetricsCount;
    if (averageSupport >= 0.75) {
      supportingContext = SupportingWellnessContext.strong;
    } else if (averageSupport >= 0.4) {
      supportingContext = SupportingWellnessContext.supportive;
    }
  }

  return MitraDailyProgressSnapshot(
    date: date,
    coreDailyProgress: coreDailyProgress,
    supportingContext: supportingContext,
    normalizedSteps: normalizedSteps,
    normalizedWater: normalizedWater,
    normalizedSleep: normalizedSleep,
    availability: availability,
  );
});

class CanonicalSunflowerStateNotifier extends Notifier<MitraSunflowerState> {
  late final MitraSunflowerEngine _engine;
  late final MitraSunflowerIntegrationEngine _integrationEngine;

  @override
  MitraSunflowerState build() {
    _engine = MitraSunflowerEngine();
    _integrationEngine = MitraSunflowerIntegrationEngine(_engine);
    
    // Listen to changes in the integration snapshot
    ref.listen(sunflowerIntegrationProvider, (previous, next) {
      _integrationEngine.processSnapshot(next, DateTime.now());
      state = _engine.currentSnapshot?.state ?? MitraSunflowerState.seed;
    });
    
    // Initial evaluation
    final initialSnapshot = ref.read(sunflowerIntegrationProvider);
    _integrationEngine.processSnapshot(initialSnapshot, DateTime.now());
    
    return _engine.currentSnapshot?.state ?? MitraSunflowerState.seed;
  }
}

final canonicalSunflowerStateProvider = NotifierProvider<CanonicalSunflowerStateNotifier, MitraSunflowerState>(() {
  return CanonicalSunflowerStateNotifier();
});

final canonicalSunflowerAssetProvider = Provider<String>((ref) {
  final state = ref.watch(canonicalSunflowerStateProvider);
  return state.canonicalAssetPath;
});
