import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/achievement_badge.dart';
import '../providers/app_providers.dart';

final badgeProvider = Provider<List<AchievementBadge>>((ref) {
  final dailyLogRepo = ref.watch(dailyLogRepoProvider);
  final logs = dailyLogRepo.getAllLogs();
  
  if (logs.isEmpty) return [];

  int workoutCount = logs.where((l) => l.workoutCompleted).length;
  // A simplistic streak for demo purposes
  int currentStreak = 0;
  for (final log in logs.reversed) {
    if (log.workoutCompleted || (log.steps ?? 0) >= 5000) {
      currentStreak++;
    } else {
      break;
    }
  }

  return [
    AchievementBadge(
      id: 'first_workout',
      name: 'First Blood',
      description: 'Log your first workout.',
      emoji: '🔥',
      category: BadgeCategory.milestones,
      progress: workoutCount,
      maxProgress: 1,
      isUnlocked: workoutCount >= 1,
      unlockedAt: workoutCount >= 1 ? DateTime.now() : null,
    ),
    AchievementBadge(
      id: 'streak_3',
      name: 'On a Roll',
      description: 'Achieve a 3-day activity streak.',
      emoji: '⚡',
      category: BadgeCategory.streaks,
      progress: currentStreak,
      maxProgress: 3,
      isUnlocked: currentStreak >= 3,
      unlockedAt: currentStreak >= 3 ? DateTime.now() : null,
    ),
    AchievementBadge(
      id: 'century_steps',
      name: 'Step Centurion',
      description: 'Log 100 days of steps over 10k.',
      emoji: '👟',
      category: BadgeCategory.milestones,
      progress: logs.where((l) => (l.steps ?? 0) >= 10000).length,
      maxProgress: 100,
      isUnlocked: logs.where((l) => (l.steps ?? 0) >= 10000).length >= 100,
    ),
  ];
});
