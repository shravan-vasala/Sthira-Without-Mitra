import '../mitra_sunflower_engine.dart';
import 'mitra_daily_progress_snapshot.dart';

class MitraSunflowerIntegrationEngine {
  final MitraSunflowerEngine _sunflowerEngine;
  MitraDailyProgressSnapshot? _lastSnapshot;

  MitraSunflowerIntegrationEngine(this._sunflowerEngine);

  void processSnapshot(MitraDailyProgressSnapshot snapshot, DateTime now) {
    if (_lastSnapshot == snapshot) {
      return; // Deduplicate identical snapshots to preserve anti-thrashing
    }

    _lastSnapshot = snapshot;
    
    _sunflowerEngine.setAbsoluteProgress(
      snapshot.coreDailyProgress,
      snapshot.supportingContext,
      now: now,
    );
  }
}
