import 'dart:io';
import 'package:isar/isar.dart';
import 'package:trufit_bodamma/models/user_profile.dart';
import 'package:trufit_bodamma/models/daily_log.dart';
import 'package:trufit_bodamma/models/workout_plan.dart';
import 'package:trufit_bodamma/models/workout_session.dart';
import 'package:trufit_bodamma/models/daily_meal_log.dart';
import 'package:trufit_bodamma/models/meal_plan.dart';
import 'package:trufit_bodamma/models/habit.dart';
import 'package:trufit_bodamma/models/scanned_meal_log.dart';
import 'package:trufit_bodamma/models/progress_photo.dart';
import 'package:trufit_bodamma/models/exercise_log.dart';
import 'package:trufit_bodamma/models/exercise_pr.dart';
import 'package:trufit_bodamma/models/coach_note.dart';
import 'package:trufit_bodamma/models/body_stats.dart';
import 'package:trufit_bodamma/models/badge.dart';
import 'package:trufit_bodamma/models/app_config.dart';
import 'package:trufit_bodamma/models/ai_cache_entry.dart';
import 'package:trufit_bodamma/models/food_search_cache.dart';
import 'package:trufit_bodamma/models/friend.dart';
import 'package:trufit_bodamma/models/sync_queue_item.dart';

Future<Isar> setUpTestIsar() async {
  try {
    await Isar.initializeIsarCore(download: true);
  } catch (_) {}
  
  final tempDir = Directory.systemTemp.createTempSync('isar_test_');
  return await Isar.open(
    [
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
      FriendSchema,
      SyncQueueItemSchema,
    ],
    directory: tempDir.path,
  );
}

Future<void> tearDownTestIsar(Isar isar) async {
  await isar.close(deleteFromDisk: true);
}
