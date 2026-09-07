import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import '../models/social_profile.dart';
import '../models/friend.dart';
import 'daily_log_notifier.dart';
import '../models/daily_log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/coach_note_repository.dart';
import '../repositories/workout_repository.dart';
import '../repositories/meal_repository.dart';
import '../repositories/daily_log_repository.dart';
import '../repositories/habit_repository.dart';
import '../repositories/body_stats_repository.dart';
import '../repositories/media_repository.dart';
import '../repositories/photo_meal_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/exercise_log_repository.dart';
import '../repositories/badge_repository.dart';
import '../repositories/friend_repository.dart';
import '../services/health_connect_service.dart';
import '../services/backup_service.dart';
import '../services/coach_service.dart';
import '../services/gemini_food_service.dart';
import '../services/csv_export_service.dart';
import '../services/ai_cache.dart';
import '../services/ai_client.dart';
import '../services/auth_service.dart';
import '../services/social_sync_service.dart';
import '../services/nutrition_lookup_service.dart';
import '../interfaces/i_ai_food_service.dart';
import '../utils/time_utils.dart';
import 'auth_provider.dart';
import 'profile_providers.dart';
import 'daily_score_provider.dart';

export 'rest_timer_provider.dart';
export 'phase_progress_provider.dart';
export 'theme_provider.dart';
export 'daily_score_provider.dart';
export 'yearly_heatmap_provider.dart';
export 'auth_provider.dart';
export 'habit_providers.dart';
export 'workout_providers.dart';
export 'meal_providers.dart';
export 'profile_providers.dart';
export 'daily_log_notifier.dart';
export 'coach_note_notifier.dart';
export 'sync_controller.dart';
import 'gamification_provider.dart';
export 'gamification_provider.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefs must be overridden in ProviderScope');
});

final onboardingCompletedProvider =
    NotifierProvider<OnboardingCompletedNotifier, bool>(() {
      return OnboardingCompletedNotifier();
    });

class OnboardingCompletedNotifier extends Notifier<bool> {
  static const String _onboardingKey = 'onboarding_completed';
  late SharedPreferences _prefs;

  @override
  bool build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return _prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_onboardingKey, true);
    state = true;
  }
}

// ── Date ──
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final dateStringProvider = Provider<String>((ref) {
  final date = ref.watch(selectedDateProvider);
  return todayKey(date);
});

final weekOffsetProvider = StateProvider<int>((ref) => 0);

// ── Repositories (singletons) ──
final workoutRepoProvider = Provider<WorkoutRepository>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final mealRepoProvider = Provider<MealRepository>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final dailyLogRepoProvider = Provider<DailyLogRepository>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final habitRepoProvider = Provider<HabitRepository>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final bodyStatsRepoProvider = Provider<BodyStatsRepository>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final mediaRepoProvider = Provider<MediaRepository>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final photoMealRepoProvider = Provider<PhotoMealRepository>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final profileRepoProvider = Provider<ProfileRepository>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final exerciseLogRepoProvider = Provider<ExerciseLogRepository>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final coachNoteRepoProvider = Provider<CoachNoteRepository>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final badgeRepoProvider = Provider<BadgeRepository>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final friendRepoProvider = Provider<FriendRepository>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final friendsListStreamProvider = StreamProvider<List<Friend>>((ref) {
  final repo = ref.watch(friendRepoProvider);
  return repo.isar.friends.where().sortByAddedAtDesc().watch(fireImmediately: true);
});
final healthConnectServiceProvider = Provider<HealthConnectService>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});
final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('Must be overridden in main');
});
final socialSyncServiceProvider = Provider<SocialSyncService>((ref) {
  return SocialSyncService(ref.watch(authServiceProvider));
});

final socialPushControllerProvider = Provider<void>((ref) {
  ref.listen(dailyLogProvider, (prev, next) {
    final todayStr = todayKey();
    if (next.date == todayStr) {
      _pushProfile(ref, next);
    }
  });
  ref.listen(profileProvider, (prev, next) {
    final todayStr = todayKey();
    final repo = ref.read(dailyLogRepoProvider);
    final todayLog = repo.getOrCreate(todayStr);
    _pushProfile(ref, todayLog);
  });

  // Start pending acceptances check
  Future.microtask(() async {
    final syncService = ref.read(socialSyncServiceProvider);
    final friendRepo = ref.read(friendRepoProvider);
    final pending = await syncService.getPendingAcceptances();
    for (final p in pending) {
      final fromUid = p['fromUid'] as String?;
      if (fromUid != null) {
        // We know they accepted our request, add them to our allowedReaders
        await syncService.acceptFriendRequest(
          fromUid,
        ); // Not quite, we just need to add to allowed readers
        // Actually, the sender side of acceptance:
        // When I send request, they accept -> they add me to their allowed readers, and create an acceptance marker for me.
        // I see the marker -> I add them to my allowed readers, local friend DB, and delete the marker.
        try {
          await syncService.fetchProfileOnce(fromUid).then((profile) {
            if (profile != null) {
              friendRepo.addFriend(
                fromUid,
                profile.name,
                avatarUrl: profile.avatarUrl,
              );
            }
          });
          // To add to my allowed readers, I can just call acceptFriendRequest which does it.
          // Wait, acceptFriendRequest deletes from my requests, adds to my allowed readers, creates a marker for them.
          // That's for the TARGET receiving a request.
          // For the SENDER receiving an acceptance marker:
          // The marker is in my requests but has accepted=true.
          // Let's just update my allowedReaders, and clear the marker.
          final db = FirebaseFirestore.instance;
          final currentUid = syncService.currentUid;
          if (currentUid != null) {
            await db.collection('social_profiles').doc(currentUid).update({
              'allowedReaders': FieldValue.arrayUnion([fromUid]),
            });
            await syncService.clearAcceptanceMarker(fromUid);
          }
        } catch (e) {
          debugPrint('Error processing pending acceptance: $e');
        }
      }
    }
  });
});

final friendProfileStreamProvider =
    StreamProvider.family<SocialProfile?, String>((ref, uid) {
      final syncService = ref.watch(socialSyncServiceProvider);
      return syncService.streamFriendProfile(uid);
    });

void _pushProfile(Ref ref, DailyLog todayLog) {
  final profile = ref.read(profileProvider);
  final syncService = ref.read(socialSyncServiceProvider);
  final authService = ref.read(authServiceProvider);

  if (authService.uid == null) return;

  // Calculate weekly stats
  final dailyLogRepo = ref.read(dailyLogRepoProvider);
  final now = DateTime.now();
  // Monday is 1, Sunday is 7
  final diff = now.weekday - 1;
  final monday = now.subtract(Duration(days: diff));

  int weeklySteps = 0;
  int weeklyWorkouts = 0;

  for (int i = 0; i <= diff; i++) {
    final d = monday.add(Duration(days: i));
    final dStr = todayKey(d);
    final log = dailyLogRepo.getLog(dStr);
    if (log != null) {
      weeklySteps += log.steps ?? 0;
      if (log.workoutCompleted) {
        weeklyWorkouts++;
      }
    }
  }

  final String? safeAvatarUrl =
      (profile.photoPath?.startsWith('assets/') ?? false)
      ? profile.photoPath
      : null;

  final dailyScore = ref.read(dailyScoreProvider);

  final profileData = SocialProfile(
    uid: authService.uid!,
    name: profile.name,
    avatarUrl: safeAvatarUrl,
    todaySteps: todayLog.steps ?? 0,
    todayWorkouts: todayLog.workoutCompleted ? 1 : 0,
    currentStreak: ref.read(stepsStreakProvider),
    weeklySteps: weeklySteps,
    weeklyWorkouts: weeklyWorkouts,
    latestBadge: null,
    lastUpdatedAt: DateTime.now(),
    todayScore: dailyScore.totalScore,
    weekScore: dailyScore.sevenDayAverage,
    // We do NOT overwrite allowedReaders here because pushProfile uses SetOptions(merge: true)
  );
  syncService.pushProfile(profileData);
}

final csvExportServiceProvider = Provider<CsvExportService>((ref) {
  return CsvExportService();
});

final aiCacheProvider = Provider<AiCache>((ref) {
  return AiCache();
});

final aiClientProvider = Provider<AiClient>((ref) {
  return AiClient(cache: ref.watch(aiCacheProvider));
});

final nutritionLookupServiceProvider = Provider<NutritionLookupService>((ref) {
  return NutritionLookupService();
});

final geminiFoodServiceProvider = Provider<IAiFoodService>((ref) {
  final profile = ref.watch(profileProvider);
  return GeminiFoodService(
    apiKey: profile.geminiApiKey,
    aiClient: ref.watch(aiClientProvider),
    nutritionLookup: ref.watch(nutritionLookupServiceProvider),
  );
});

final coachServiceProvider = Provider<CoachService>((ref) {
  final apiKey = ref.watch(profileProvider.select((p) => p.geminiApiKey));
  return CoachService(
    apiKey: apiKey,
    aiClient: ref.watch(aiClientProvider),
  );
});

final stepsSourceProvider = StateProvider<StepsSource>(
  (ref) => StepsSource.none,
);

// ── End of file ──

final friendRequestsCountProvider = StreamProvider<int>((ref) {
  final sync = ref.watch(socialSyncServiceProvider);
  return sync.streamFriendRequests().map((reqs) => reqs.length);
});

final syncPendingCountProvider = StreamProvider<int>((ref) {
  final sync = ref.watch(firestoreSyncServiceProvider);
  return sync.pendingCountStream;
});
