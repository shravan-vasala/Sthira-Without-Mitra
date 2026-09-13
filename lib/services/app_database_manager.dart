import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../models/daily_log.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';
import '../models/daily_meal_log.dart';
import '../models/meal_plan.dart';
import '../models/habit.dart';
import '../models/scanned_meal_log.dart';
import '../models/progress_photo.dart';
import '../models/exercise_log.dart';
import '../models/exercise_pr.dart';
import '../models/coach_note.dart';
import '../models/body_stats.dart';
import '../models/badge.dart';
import '../models/app_config.dart';
import '../models/ai_cache_entry.dart';
import '../models/food_search_cache.dart';
import '../models/user_food_log.dart';
import '../models/friend.dart';
import '../models/sync_queue_item.dart';

class AppDatabaseManager {
  static const List<CollectionSchema> schemas = [
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
  ];

  static Future<Isar> openDatabaseForUser(String? uid) async {
    final rootDir = await getApplicationDocumentsDirectory();
    final isarName = uid ?? 'guest';
    
    final existing = Isar.getInstance(isarName);
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final targetDir = Directory('${rootDir.path}/$isarName');
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }
    
    final oldDbPath = '${rootDir.path}/default.isar';
    final oldLockPath = '${rootDir.path}/default.lock';
    final targetDbPath = '${targetDir.path}/$isarName.isar';

    if (!File(targetDbPath).existsSync() && File(oldDbPath).existsSync()) {
      debugPrint('AppDatabaseManager: Migrating legacy root database to scoped directory for $isarName...');
      File(oldDbPath).renameSync(targetDbPath);
      if (File(oldLockPath).existsSync()) {
        File(oldLockPath).renameSync('${targetDir.path}/$isarName.lock');
      }
    }
    
    try {
      return await Isar.open(
        schemas,
        name: isarName,
        directory: targetDir.path,
      );
    } catch (e) {
      debugPrint('AppDatabaseManager: Error opening Isar: $e');
      rethrow;
    }
  }
}
