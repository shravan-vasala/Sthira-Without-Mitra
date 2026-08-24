import 'mitra_behaviour.dart';

class MitraContext {
  MitraBehaviourCategory? lastBehaviour;
  Map<MitraBehaviourCategory, DateTime> lastExecutionTimes = {};
  final List<MitraBehaviourCategory> recentBehaviours = [];

  void recordBehaviour(MitraBehaviourCategory behaviour) {
    if (behaviour == MitraBehaviourCategory.idle) return;
    lastBehaviour = behaviour;
    lastExecutionTimes[behaviour] = DateTime.now();
    recentBehaviours.add(behaviour);
    // Keep last 5 behaviours
    if (recentBehaviours.length > 5) {
      recentBehaviours.removeAt(0);
    }
  }

  bool usedRecently(MitraBehaviourCategory behaviour, {int limit = 2}) {
    int count = 0;
    for (var b in recentBehaviours) {
      if (b == behaviour) count++;
    }
    return count >= limit;
  }

  void resetAllCooldowns() {
    lastExecutionTimes.clear();
    recentBehaviours.clear();
  }
}
