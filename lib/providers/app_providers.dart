import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/app_database_manager.dart';
export '../services/widget_coordinator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import '../models/social_profile.dart';
import '../models/friend.dart';
import '../models/progress_photo.dart';
import 'daily_log_notifier.dart';
import 'meal_providers.dart';
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
import '../services/firestore_sync_service.dart';
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
import 'credential_provider.dart';
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

final clockProvider = Provider<DateTime>((ref) => DateTime.now());

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

  Future<void> commitLocalSetup() async {
    await _prefs.setBool(_onboardingKey, true);
  }

  void completeRoute() {
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
final dailyLogsUpdateProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(dailyLogRepoProvider);
  return repo.watchUpdates;
});

final dailyMealLogsUpdateProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(mealRepoProvider);
  return repo.watchUpdates;
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
final progressPhotosStreamProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(mediaRepoProvider);
  // We only care about changes to progress photos to trigger reminder updates
  return repo.isar.progressPhotos.watchLazy(fireImmediately: true);
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
  return BackupService(ref.watch(authServiceProvider));
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
          // We know they accepted our request, add them to our allowedReaders
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
          
          await syncService.processPendingAcceptance(fromUid);
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

  final dailyScore = ref.read(todayScoreProvider);

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
  final client = AiClient(cache: ref.watch(aiCacheProvider));
  ref.onDispose(() => client.dispose());
  return client;
});

final nutritionLookupServiceProvider = Provider<NutritionLookupService>((ref) {
  return NutritionLookupService();
});


enum CloudSyncState { idle, syncing, success, error }

final cloudSyncControllerProvider =
    NotifierProvider<CloudSyncController, CloudSyncState>(
  CloudSyncController.new,
);

class CloudSyncController extends Notifier<CloudSyncState> {
  String? errorMessage;

  @override
  CloudSyncState build() {
    return CloudSyncState.idle;
  }

  Future<void> signInAndSync() async {
    state = CloudSyncState.syncing;
    errorMessage = null;
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.signInWithGoogle();
      if (user == null) {
        state = CloudSyncState.idle;
        return;
      }

      final syncService = ref.read(firestoreSyncServiceProvider);
      
      // Detach all before transition
      await ref.read(workoutRepoProvider).detachSync();
      await ref.read(mealRepoProvider).detachSync();
      await ref.read(dailyLogRepoProvider).detachSync();
      await ref.read(habitRepoProvider).detachSync();
      await ref.read(bodyStatsRepoProvider).detachSync();
      await ref.read(profileRepoProvider).detachSync();
      await ref.read(exerciseLogRepoProvider).detachSync();
      await ref.read(coachNoteRepoProvider).detachSync();
      await ref.read(badgeRepoProvider).detachSync();

      // Switch scope
      final newIsar = await AppDatabaseManager.openDatabaseForUser(user.uid);
      
      // Re-initialize
      await Future.wait([
        ref.read(workoutRepoProvider).init(newIsar),
        ref.read(mealRepoProvider).init(newIsar),
        ref.read(photoMealRepoProvider).init(newIsar),
        ref.read(dailyLogRepoProvider).init(newIsar),
        ref.read(habitRepoProvider).init(newIsar),
        ref.read(bodyStatsRepoProvider).init(newIsar),
        ref.read(mediaRepoProvider).init(newIsar),
        ref.read(profileRepoProvider).init(newIsar),
        ref.read(exerciseLogRepoProvider).init(newIsar),
        ref.read(coachNoteRepoProvider).init(newIsar),
        ref.read(badgeRepoProvider).init(newIsar),
        ref.read(friendRepoProvider).init(newIsar),
      ]);

      // Re-attach sync subscriptions NOW that we are logged in, so they get their cloud listeners.
      ref.read(workoutRepoProvider).attachSync(syncService);
      await ref.read(mealRepoProvider).attachSync(syncService);
      await ref.read(dailyLogRepoProvider).attachSync(syncService);
      ref.read(habitRepoProvider).attachSync(syncService);
      ref.read(bodyStatsRepoProvider).attachSync(syncService);
      ref.read(profileRepoProvider).attachSync(syncService);
      ref.read(exerciseLogRepoProvider).attachSync(syncService);
      ref.read(coachNoteRepoProvider).attachSync(syncService);
      await ref.read(badgeRepoProvider).attachSync(syncService);

      final hasCloudData = await syncService.hasCloudData();

      if (hasCloudData) {
        final profile = await syncService.pullProfile();
        if (profile != null) {
          await ref.read(profileRepoProvider).importProfileFromCloud(profile);
        }

        final dailyLogs = await syncService.pullCollection('daily_logs');
        await ref.read(dailyLogRepoProvider).importFromCloud(dailyLogs);

        final mealLogs = await syncService.pullCollection('meal_logs');
        await ref.read(mealRepoProvider).importLogsFromCloud(mealLogs);

        final stats = await syncService.pullCollection('body_stats');
        await ref.read(bodyStatsRepoProvider).importStatsFromCloud(stats);

        final workoutPlans = await syncService.pullCollection('workout_plans');
        await ref.read(workoutRepoProvider).importPlansFromCloud(workoutPlans);

        final mealPlans = await syncService.pullCollection('meal_plans');
        await ref.read(mealRepoProvider).importPlansFromCloud(mealPlans);

        ref.invalidate(profileProvider);
        ref.invalidate(dailyLogProvider);
        ref.invalidate(dailyMealLogProvider);
        ref.invalidate(latestBodyStatsProvider);
        ref.invalidate(friendsListStreamProvider);
      } else {
        syncService.syncProfile(
          ref.read(profileRepoProvider).exportProfileForCloud(),
        );
        await syncService.bulkSync(
          'daily_logs',
          ref.read(dailyLogRepoProvider).exportForCloud(),
        );
        await syncService.bulkSync(
          'meal_logs',
          ref.read(mealRepoProvider).exportLogsForCloud(),
        );
        await syncService.bulkSync(
          'body_stats',
          ref.read(bodyStatsRepoProvider).exportStatsForCloud(),
        );
        await syncService.bulkSync(
          'habit_config',
          ref.read(habitRepoProvider).exportConfigForCloud(),
        );
        await syncService.bulkSync(
          'habit_completions',
          ref.read(habitRepoProvider).exportCompletionsForCloud(),
        );
        await syncService.bulkSync(
          'workout_plans',
          ref.read(workoutRepoProvider).exportPlansForCloud(),
        );
        await syncService.bulkSync(
          'meal_plans',
          ref.read(mealRepoProvider).exportPlansForCloud(),
        );
      }
      state = CloudSyncState.success;
    } catch (e) {
      errorMessage = e.toString().replaceAll('Exception: ', '');
      state = CloudSyncState.error;
    }
  }
}

final geminiFoodServiceProvider = Provider<IAiFoodService>((ref) {
  final credentialState = ref.watch(credentialProvider);
  return GeminiFoodService(
    apiKey: credentialState.key,
    aiClient: ref.watch(aiClientProvider),
    nutritionLookup: ref.watch(nutritionLookupServiceProvider),
  );
});

final coachServiceProvider = Provider<CoachService>((ref) {
  final key = ref.watch(credentialProvider.select((s) => s.key));
  return CoachService(
    apiKey: key,
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
