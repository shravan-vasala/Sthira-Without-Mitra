import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'repositories/workout_repository.dart';
import 'repositories/meal_repository.dart';
import 'repositories/daily_log_repository.dart';
import 'repositories/habit_repository.dart';
import 'repositories/body_stats_repository.dart';
import 'repositories/media_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/exercise_log_repository.dart';
import 'repositories/badge_repository.dart';
import 'repositories/coach_note_repository.dart';
import 'repositories/friend_repository.dart';
import 'repositories/photo_meal_repository.dart';
import 'services/health_connect_service.dart';
import 'services/backup_service.dart';
import 'services/notification_service.dart';
import 'services/schema_migration_service.dart';
import 'providers/app_providers.dart';
import 'providers/reminders_provider.dart';
import 'services/diagnostic_logger.dart';
import 'router/app_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/firestore_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Models
import 'models/user_profile.dart';
import 'models/daily_log.dart';
import 'models/workout_plan.dart';
import 'models/workout_session.dart';
import 'models/daily_meal_log.dart';
import 'models/meal_plan.dart';
import 'models/habit.dart';
import 'models/scanned_meal_log.dart';
import 'models/progress_photo.dart';
import 'models/exercise_log.dart';
import 'models/exercise_pr.dart';
import 'models/coach_note.dart';
import 'models/body_stats.dart';
import 'models/badge.dart';
import 'models/app_config.dart';
import 'models/ai_cache_entry.dart';
import 'models/food_search_cache.dart';
import 'models/user_food_log.dart';
import 'models/friend.dart';
import 'models/sync_queue_item.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    // ── Manual font loading ──
    // Load fonts explicitly via FontLoader to ensure they register
    // with the engine before the first frame renders.
    final fontAssets = <String, List<String>>{
      'Cabinet Grotesk': [
        'assets/fonts/CabinetGrotesk-Light.ttf',
        'assets/fonts/CabinetGrotesk-Regular.ttf',
        'assets/fonts/CabinetGrotesk-Medium.ttf',
        'assets/fonts/CabinetGrotesk-Bold.ttf',
        'assets/fonts/CabinetGrotesk-Extrabold.ttf',
        'assets/fonts/CabinetGrotesk-Black.ttf',
      ],
      'General Sans': [
        'assets/fonts/GeneralSans-Light.ttf',
        'assets/fonts/GeneralSans-Regular.ttf',
        'assets/fonts/GeneralSans-Medium.ttf',
        'assets/fonts/GeneralSans-Semibold.ttf',
        'assets/fonts/GeneralSans-Bold.ttf',
      ],
    };
    for (final entry in fontAssets.entries) {
      final loader = FontLoader(entry.key);
      for (final assetPath in entry.value) {
        loader.addFont(rootBundle.load(assetPath));
      }
      await loader.load();
    }
    debugPrint('✅ All custom fonts loaded manually via FontLoader');

    // Lock to portrait
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open([
      UserProfileSchema,
      DailyLogSchema,
      WorkoutPlanSchema,
      WorkoutSessionSchema,
      DailyMealLogSchema,
      MealPlanSchema,
      HabitSchema,
      HabitCompletionSchema,
      ScannedMealLogSchema,
      ProgressPhotoSchema,
      ExerciseLogSchema,
      ExercisePrSchema,
      CoachNoteSchema,
      BodyStatsSchema,
      BadgeSchema,
      AppConfigSchema,
      AiCacheEntrySchema,
      FoodSearchCacheSchema,
      UserFoodLogSchema,
      FriendSchema,
      SyncQueueItemSchema,
    ], directory: dir.path);

    // ignore: unawaited_futures
    SchemaMigrationService.runStartupMigrations(isar);

    // Initialize all repositories
    final workoutRepo = WorkoutRepository();
    final mealRepo = MealRepository();
    final photoMealRepo = PhotoMealRepository();
    final dailyLogRepo = DailyLogRepository();
    final habitRepo = HabitRepository();
    final bodyStatsRepo = BodyStatsRepository();
    final mediaRepo = MediaRepository();
    final profileRepo = ProfileRepository();
    final exerciseLogRepo = ExerciseLogRepository();
    final coachNoteRepo = CoachNoteRepository();
    final badgeRepo = BadgeRepository();
    final friendRepo = FriendRepository(isar);
    final healthConnectService = HealthConnectService();

    await Future.wait([
      workoutRepo.init(isar),
      mealRepo.init(isar),
      photoMealRepo.init(isar),
      dailyLogRepo.init(isar),
      habitRepo.init(isar),
      bodyStatsRepo.init(isar),
      mediaRepo.init(isar),
      profileRepo.init(isar),
      exerciseLogRepo.init(isar),
      coachNoteRepo.init(isar),
      badgeRepo.init(isar),
      healthConnectService.init(),
      NotificationService().init(),
    ]);

    final authService = AuthService();
    final firestoreSyncService = FirestoreSyncService(authService);

    workoutRepo.attachSync(firestoreSyncService);
    mealRepo.attachSync(firestoreSyncService);
    dailyLogRepo.attachSync(firestoreSyncService);
    habitRepo.attachSync(firestoreSyncService);
    bodyStatsRepo.attachSync(firestoreSyncService);
    profileRepo.attachSync(firestoreSyncService);
    exerciseLogRepo.attachSync(firestoreSyncService);
    coachNoteRepo.attachSync(firestoreSyncService);
    badgeRepo.attachSync(firestoreSyncService);

    // Fetch global plans from Firebase (non-blocking) to merge with local seed data
    // ignore: unawaited_futures
    workoutRepo.fetchGlobalPlans();
    // ignore: unawaited_futures
    mealRepo.fetchGlobalPlans();

    // Fetch user-specific personal plans from Firebase (non-blocking)
    // ignore: unawaited_futures
    workoutRepo.fetchUserPlans();
    // ignore: unawaited_futures
    mealRepo.fetchUserPlans();

    // Run weekly auto-backup (non-blocking)
    // ignore: unawaited_futures
    BackupService().autoBackup();

    final initialGeminiKey = await profileRepo.getSecureGeminiKey();
    final prefs = await SharedPreferences.getInstance();

    final logger = DiagnosticLogger(prefs);
    logger.info('Sthira started cleanly');

    runApp(
      ProviderScope(
        observers: [DiagnosticProviderObserver(logger)],
        overrides: [
          workoutRepoProvider.overrideWithValue(workoutRepo),
          mealRepoProvider.overrideWithValue(mealRepo),
          photoMealRepoProvider.overrideWithValue(photoMealRepo),
          dailyLogRepoProvider.overrideWithValue(dailyLogRepo),
          habitRepoProvider.overrideWithValue(habitRepo),
          bodyStatsRepoProvider.overrideWithValue(bodyStatsRepo),
          mediaRepoProvider.overrideWithValue(mediaRepo),
          profileRepoProvider.overrideWithValue(profileRepo),
          exerciseLogRepoProvider.overrideWithValue(exerciseLogRepo),
          coachNoteRepoProvider.overrideWithValue(coachNoteRepo),
          badgeRepoProvider.overrideWithValue(badgeRepo),
          friendRepoProvider.overrideWithValue(friendRepo),
          healthConnectServiceProvider.overrideWithValue(healthConnectService),
          authServiceProvider.overrideWithValue(authService),
          initialGeminiKeyProvider.overrideWithValue(initialGeminiKey ?? ''),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const TruFitApp(),
      ),
    );
  } catch (e, stack) {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logFile = File('${dir.path}/crash_log.txt');
      await logFile.writeAsString('Error:\n$e\n\nStack:\n$stack');

      runApp(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Fatal Error on Startup.\n\nA crash log has been saved to:\n${logFile.path}\n\nError: $e',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (fallbackErr) {
      runApp(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Fatal Error on Startup:\n\n$e',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}

class TruFitApp extends ConsumerStatefulWidget {
  const TruFitApp({super.key});

  @override
  ConsumerState<TruFitApp> createState() => _TruFitAppState();
}

class _TruFitAppState extends ConsumerState<TruFitApp> {
  @override
  void initState() {
    super.initState();
    // Initialize notifications and sync them
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(remindersProvider.notifier).initializeNotifications();
      ref.read(socialPushControllerProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Sthira',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
