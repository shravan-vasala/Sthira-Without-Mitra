import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/social_profile.dart';
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

import 'auth_provider.dart';
import 'profile_providers.dart';

// used for daily log habit auto-complete

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

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('prefs must be overridden in ProviderScope');
});

final onboardingCompletedProvider = NotifierProvider<OnboardingCompletedNotifier, bool>(() {
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
  return DateFormat('yyyy-MM-dd').format(date);
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
    _pushProfile(ref, next);
  });
  ref.listen(profileProvider, (prev, next) {
    _pushProfile(ref, ref.read(dailyLogProvider));
  });
});

void _pushProfile(Ref ref, DailyLog dailyLog) {
  final profile = ref.read(profileProvider);
  final syncService = ref.read(socialSyncServiceProvider);
  final authService = ref.read(authServiceProvider);

  if (authService.uid == null) return;

  final profileData = SocialProfile(
    uid: authService.uid!,
    name: profile.name,
    avatarUrl: profile.photoPath,
    todaySteps: dailyLog.steps ?? 0,
    todayWorkouts: dailyLog.workoutCompleted ? 1 : 0,
    currentStreak: 0, // TODO: calculate streak
    latestBadge: null, // TODO: fetch latest badge
    lastUpdatedAt: DateTime.now(),
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
  final isSignedIn = ref.watch(isSignedInProvider);
  return GeminiFoodService(
    apiKey: profile.geminiApiKey,
    isSignedIn: isSignedIn,
    aiClient: ref.watch(aiClientProvider),
    nutritionLookup: ref.watch(nutritionLookupServiceProvider),
  );
});

final coachServiceProvider = Provider<CoachService>((ref) {
  final apiKey = ref.watch(profileProvider.select((p) => p.geminiApiKey));
  final isSignedIn = ref.watch(isSignedInProvider);
  return CoachService(
    apiKey: apiKey, 
    isSignedIn: isSignedIn,
    aiClient: ref.watch(aiClientProvider),
  );
});

final stepsSourceProvider = StateProvider<StepsSource>((ref) => StepsSource.none);

// ── End of file ──
