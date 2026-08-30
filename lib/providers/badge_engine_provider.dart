import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/badge.dart';
import 'app_providers.dart';

// Provides access to the list of badges for the UI
final badgesProvider = Provider<List<Badge>>((ref) {
  final repo = ref.watch(badgeRepoProvider);
  return repo.getAllBadges();
});

// Provides access exactly when the engine fires an unlock
final badgeUnlockEventProvider = StateProvider<Badge?>((ref) => null);

final badgeEngineProvider = Provider<BadgeEngine>((ref) {
  return BadgeEngine(ref);
});

class BadgeEngine {
  final Ref ref;

  BadgeEngine(this.ref) {
    // Listen to changes in logs to fire background evaluations
    ref.listen(dailyLogProvider, (previous, next) {
      _evaluateBadges();
    });
  }

  Future<void> _evaluateBadges() async {
    final badgeRepo = ref.read(badgeRepoProvider);
    final workoutRepo = ref.read(workoutRepoProvider);
    final dailyLogRepo = ref.read(dailyLogRepoProvider);
    
    final allLogs = dailyLogRepo.getAllLogs();
    
    // Count workouts
    final int totalWorkouts = allLogs.where((l) => l.workoutCompleted).length;

    // Calculate Streak
    int currentStreak = 0;
    for (int i = allLogs.length - 1; i >= 0; i--) {
      if (allLogs[i].hasAnyActivity) {
        currentStreak++;
      } else {
        break; // streak broken
      }
    }

    final allBadges = badgeRepo.getAllBadges();

    for (var badge in allBadges) {
      if (badge.isUnlocked) continue; // Already unlocked

      int currentProgress = 0;
      bool shouldUnlock = false;

      if (badge.category == 'workout') {
        currentProgress = totalWorkouts;
        if (currentProgress >= badge.requiredProgress) shouldUnlock = true;
      } else if (badge.category == 'streak') {
        currentProgress = currentStreak;
        if (currentProgress >= badge.requiredProgress) shouldUnlock = true;
      }

      // If we made progress, save the new progress
      if (currentProgress > badge.currentProgress && !shouldUnlock) {
        await badgeRepo.saveBadge(badge.copyWith(currentProgress: currentProgress));
      }

      // If we just unlocked it
      if (shouldUnlock) {
        final unlockedBadge = badge.copyWith(
          currentProgress: currentProgress,
          unlockedAt: DateTime.now(),
        );
        await badgeRepo.saveBadge(unlockedBadge);
        
        // Fire event to UI
        ref.read(badgeUnlockEventProvider.notifier).state = unlockedBadge;
      }
    }
  }
}
