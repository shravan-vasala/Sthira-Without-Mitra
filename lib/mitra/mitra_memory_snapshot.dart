import 'mitra_memory_event.dart';

class MitraMemorySnapshot {
  final bool hasRecentWorkout;
  final bool hasRecentMeaningfulEvent;
  final bool hasRecentUserReturn;
  final Duration? timeSinceLastInteraction;
  final Duration? timeSinceLastWorkout;
  final Duration? timeSinceLastMeaningfulEvent;
  final int recentAchievementCount;
  final int recentInteractionCount;
  final bool hasMilestone;
  final MitraMemoryEvent? latestMeaningfulMemory;
  final MitraMemoryEvent? latestMilestone;

  const MitraMemorySnapshot({
    required this.hasRecentWorkout,
    required this.hasRecentMeaningfulEvent,
    required this.hasRecentUserReturn,
    this.timeSinceLastInteraction,
    this.timeSinceLastWorkout,
    this.timeSinceLastMeaningfulEvent,
    required this.recentAchievementCount,
    required this.recentInteractionCount,
    required this.hasMilestone,
    this.latestMeaningfulMemory,
    this.latestMilestone,
  });
}
