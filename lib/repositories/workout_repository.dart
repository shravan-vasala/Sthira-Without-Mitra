import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';
import '../interfaces/i_cloud_sync_service.dart';
import '../models/sync_queue_item.dart';
import '../utils/seed_migration_manager.dart';

class WorkoutRepository {
  late Isar _isar;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) => _sync = sync;
  Future<void> detachSync() async {
    _sync = null;
  }

  Future<void> init(Isar isar) async {
    _isar = isar;
    await _seedIfEmpty();
  }

  Future<void> _seedIfEmpty() async {
    await SeedMigrationManager.seedOrMigrateWorkouts(
      _isar,
      'assets/data/seed_workout_plan.json',
    );
  }

  List<WorkoutPlan> getAllPlans() {
    return _isar.workoutPlans.where().findAllSync();
  }

  WorkoutPlan? getPlan(String key) {
    return _isar.workoutPlans.where().planNameEqualTo(key).findFirstSync();
  }

  /// Resolves the plan for [preferredKey], falling back to `beginner_plan`
  /// then the first stored plan (same pattern as meal plans).
  WorkoutPlan? getActivePlan({String? preferredKey}) {
    if (_isar.workoutPlans.where().countSync() == 0) return null;
    if (preferredKey != null) {
      final preferred = getPlan(preferredKey);
      if (preferred != null) return preferred;
    }
    return getPlan('beginner_plan') ??
        _isar.workoutPlans.where().findFirstSync();
  }

  WorkoutDay? getWorkoutDay(String dayId) {
    final plans = getAllPlans();
    for (final plan in plans) {
      for (final day in plan.days) {
        if (day.dayId == dayId) return day;
      }
    }
    return null;
  }

  Future<void> savePlan(String key, WorkoutPlan plan) async {
    final existing = getPlan(key);
    if (existing != null) {
      plan.id = existing.id;
    }
    await _isar.writeTxn(() async {
      await _isar.workoutPlans.put(plan);
      if (_isar.name != 'guest') {
        _isar.syncQueueItems.put(
          SyncQueueItem(
            uid: _isar.name,
            collection: 'workout_plans',
            docId: key,
            payload: jsonEncode(plan.toJson()),
            timestamp: DateTime.now(),
          ),
        );
      }
    });
    _sync?.triggerFlush();
  }

  Future<void> renamePlan(String oldKey, String newKey, String jsonStr) async {
    final existing = getPlan(oldKey);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    final newPlan = WorkoutPlan.fromJson(map);

    await _isar.writeTxn(() async {
      if (existing != null) {
        await _isar.workoutPlans.delete(existing.id);
      }
      await _isar.workoutPlans.put(newPlan);
      if (_isar.name != 'guest') {
        _isar.syncQueueItems.put(
          SyncQueueItem(
            uid: _isar.name,
            collection: '_delete_/workout_plans',
            docId: oldKey,
            payload: '{}',
            timestamp: DateTime.now(),
          ),
        );
        _isar.syncQueueItems.put(
          SyncQueueItem(
            uid: _isar.name,
            collection: 'workout_plans',
            docId: newKey,
            payload: jsonEncode(newPlan.toJson()),
            timestamp: DateTime.now(),
          ),
        );
      }
    });
    _sync?.triggerFlush();
  }

  Future<void> savePlanJson(String key, String jsonStr) async {
    // Validate JSON first
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Root JSON must be an object');
    }
    final map = decoded;

    if (map['planName'] == null || map['planName'].toString().trim().isEmpty) {
      throw const FormatException('Missing or empty "planName"');
    }

    final days = map['days'];
    final weeks = map['weeks'];
    
    if (days == null && weeks == null) {
      throw const FormatException('Must contain either "days" or "weeks"');
    }
    
    if (days != null && days is! List) {
      throw const FormatException('"days" must be an array');
    }

    if (weeks != null) {
      if (weeks is! List) {
        throw const FormatException('"weeks" must be an array');
      }
      if (weeks.isEmpty) {
        throw const FormatException('"weeks" cannot be empty');
      }
      
      int expectedWeekNumber = 1;
      for (int i = 0; i < weeks.length; i++) {
        final w = weeks[i];
        if (w is! Map<String, dynamic>) {
          throw FormatException('Week at index $i is not an object');
        }
        
        final wn = w['weekNumber'];
        if (wn != null) {
           if (wn != expectedWeekNumber) {
             throw FormatException('Expected weekNumber $expectedWeekNumber but got $wn');
           }
        } else {
           w['weekNumber'] = expectedWeekNumber;
        }
        expectedWeekNumber++;
        
        final weekDays = w['days'];
        if (weekDays == null || weekDays is! List) {
           throw FormatException('Week ${w['weekNumber']} must have a "days" array');
        }
      }
    }

    // Validation for days structure - we'll collect all days from weeks or root days
    final List<dynamic> allDaysToValidate = [];
    if (days != null) allDaysToValidate.addAll(days);
    if (weeks != null) {
      for (final w in weeks) {
        allDaysToValidate.addAll(w['days']);
      }
    }

    for (int i = 0; i < allDaysToValidate.length; i++) {
      final day = allDaysToValidate[i];
      if (day is! Map<String, dynamic>) {
        throw FormatException('Day at index $i is not an object');
      }

      if (day['dayId'] == null || day['dayId'].toString().trim().isEmpty) {
        day['dayId'] = const Uuid().v4();
      }

      final sections = day['sections'];
      if (sections != null && sections is! List) {
        throw FormatException(
          '"sections" in day "${day['dayName'] ?? day['dayId']}" must be an array',
        );
      }

      if (sections != null) {
        for (final section in sections) {
          if (section is! Map<String, dynamic>) {
            throw const FormatException('Each section must be an object');
          }
          final exercises = section['exercises'];
          if (exercises != null && exercises is! List) {
            throw FormatException(
              '"exercises" in section "${section['title'] ?? 'unknown'}" must be an array',
            );
          }

          if (exercises != null) {
            for (final ex in exercises) {
              if (ex is! Map<String, dynamic>) {
                throw const FormatException('Each exercise must be an object');
              }
              final name = ex['name']?.toString() ?? '';
              if (name.trim().isEmpty) {
                throw const FormatException('An exercise is missing a "name"');
              }
              final reps = ex['reps'];
              final duration = ex['durationSeconds'];
              if ((reps == null || (reps is List && reps.isEmpty)) &&
                  (duration == null || duration <= 0)) {
                throw FormatException(
                  'Exercise "$name" is missing "reps" or valid "durationSeconds"',
                );
              }

              final yt = ex['youtubeUrl']?.toString() ?? '';
              if (yt.isNotEmpty) {
                if (!yt.contains('youtube.com/watch') &&
                    !yt.contains('youtu.be') &&
                    !yt.contains('youtube.com/shorts')) {
                  throw FormatException(
                    'Invalid YouTube URL format for exercise "$name". Use youtube.com/watch, youtu.be, or shorts',
                  );
                }
              }

              if (ex['instanceId'] == null ||
                  ex['instanceId'].toString().trim().isEmpty) {
                ex['instanceId'] = const Uuid().v4();
              }
            }
          }
        }
      }
    }
    final plan = WorkoutPlan.fromJson(map);
    await savePlan(key, plan);
  }

  Future<void> finishWorkout(
    String date,
    String dayId, {
    String status = 'completed',
  }) async {
    final key = '${date}_$dayId';
    final existingSession = _isar.workoutSessions
        .where()
        .keyEqualTo(key)
        .findFirstSync();
    Map<String, dynamic> data = {};
    if (existingSession != null) {
      data = jsonDecode(existingSession.jsonStr) as Map<String, dynamic>;
    }
    data['finished'] = true;
    data['status'] = status;
    data['finishedAt'] = DateTime.now().toIso8601String();
    data['dayId'] = dayId;
    data['date'] = date;

    final newSession = WorkoutSession(key: key, jsonStr: jsonEncode(data));
    if (existingSession != null) {
      newSession.id = existingSession.id;
    }

    await _isar.writeTxn(() async {
      await _isar.workoutSessions.put(newSession);
      if (_isar.name != 'guest') {
        _isar.syncQueueItems.put(
          SyncQueueItem(
            uid: _isar.name,
            collection: 'workout_sessions',
            docId: key,
            payload: jsonEncode(data),
            timestamp: DateTime.now(),
          ),
        );
      }
    });
    _sync?.triggerFlush();
  }

  bool isWorkoutFinished(String date, String dayId) {
    final key = '${date}_$dayId';
    final existingSession = _isar.workoutSessions
        .where()
        .keyEqualTo(key)
        .findFirstSync();
    if (existingSession == null) return false;
    final data = jsonDecode(existingSession.jsonStr) as Map<String, dynamic>;
    return data['finished'] as bool? ?? false;
  }

  String? getRawPlanJson(String key) {
    final plan = getPlan(key);
    if (plan == null) return null;
    return jsonEncode(plan.toJson());
  }

  List<String> getPlanKeys() {
    final plans = _isar.workoutPlans.where().findAllSync();
    return plans.map((p) => p.planName).toList();
  }

  // ── Cloud sync helpers ──

  Future<void> importPlansFromCloud(
    Map<String, Map<String, dynamic>> cloudData,
  ) async {
    for (final entry in cloudData.entries) {
      if (getPlan(entry.key) == null) {
        final plan = WorkoutPlan.fromJson(entry.value);
        await savePlan(entry.key, plan);
      }
    }
  }

  /// Fetches global/public workout plans from Firebase and merges them locally.
  Future<void> fetchGlobalPlans() async {
    if (_sync == null) return;
    try {
      final globalData = await _sync!.pullGlobalCollection(
        'public_workout_plans',
      );
      for (final entry in globalData.entries) {
        final plan = WorkoutPlan.fromJson(entry.value);
        await savePlan(
          entry.key,
          plan,
        ); // Always updates with latest from cloud
      }
    } catch (e) {
      debugPrint('Error fetching global workout plans: $e');
    }
  }

  /// Fetches the user's personal workout plans from Firebase and merges them locally.
  Future<void> fetchUserPlans() async {
    if (_sync == null) return;
    try {
      final userData = await _sync!.pullCollection('workout_plans');
      for (final entry in userData.entries) {
        final plan = WorkoutPlan.fromJson(entry.value);
        await savePlan(
          entry.key,
          plan,
        ); // Always updates with latest from cloud
      }
    } catch (e) {
      debugPrint('Error fetching user workout plans: $e');
    }
  }

  Future<void> importSessionsFromCloud(
    Map<String, Map<String, dynamic>> cloudData,
  ) async {
    for (final entry in cloudData.entries) {
      final existingSession = _isar.workoutSessions
          .where()
          .keyEqualTo(entry.key)
          .findFirstSync();
      if (existingSession == null) {
        final newSession = WorkoutSession(
          key: entry.key,
          jsonStr: jsonEncode(entry.value),
        );
        await _isar.writeTxn(() async {
          await _isar.workoutSessions.put(newSession);
        });
      }
    }
  }

  Map<String, Map<String, dynamic>> exportPlansForCloud() {
    final result = <String, Map<String, dynamic>>{};
    final plans = getAllPlans();
    for (final plan in plans) {
      result[plan.planName] = plan.toJson();
    }
    return result;
  }

  Map<String, Map<String, dynamic>> exportSessionsForCloud() {
    final result = <String, Map<String, dynamic>>{};
    final sessions = _isar.workoutSessions.where().findAllSync();
    for (final session in sessions) {
      result[session.key] = jsonDecode(session.jsonStr) as Map<String, dynamic>;
    }
    return result;
  }
}
