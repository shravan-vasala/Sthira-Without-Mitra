import 'mitra_context_types.dart';

class MitraContextSnapshot {
  final MitraAppScreen currentScreen;
  final MitraAppScreen previousScreen;
  final MitraUserActivity currentActivity;
  final MitraAppLifecycle lifecycleState;
  final DateTime sessionStartTime;
  final DateTime lastUserInteractionTime;
  final MitraTimeOfDay timeOfDay;
  final Duration timeSinceLastInteraction;
  final bool isRestTimerActive;

  const MitraContextSnapshot({
    required this.currentScreen,
    required this.previousScreen,
    required this.currentActivity,
    required this.lifecycleState,
    required this.sessionStartTime,
    required this.lastUserInteractionTime,
    required this.timeOfDay,
    required this.timeSinceLastInteraction,
    this.isRestTimerActive = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is MitraContextSnapshot &&
      other.currentScreen == currentScreen &&
      other.previousScreen == previousScreen &&
      other.currentActivity == currentActivity &&
      other.lifecycleState == lifecycleState &&
      other.sessionStartTime == sessionStartTime &&
      other.lastUserInteractionTime == lastUserInteractionTime &&
      other.timeOfDay == timeOfDay &&
      other.isRestTimerActive == isRestTimerActive;
      // timeSinceLastInteraction is derived dynamically and doesn't define logical equality of the snapshotted event 
  }

  @override
  int get hashCode {
    return currentScreen.hashCode ^
      previousScreen.hashCode ^
      currentActivity.hashCode ^
      lifecycleState.hashCode ^
      sessionStartTime.hashCode ^
      lastUserInteractionTime.hashCode ^
      timeOfDay.hashCode ^
      isRestTimerActive.hashCode;
  }
}
