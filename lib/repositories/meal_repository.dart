import 'dart:convert';
import 'package:isar/isar.dart';
import '../models/daily_meal_log.dart';
import '../models/meal_plan.dart';
import 'package:flutter/services.dart';
import '../interfaces/i_cloud_sync_service.dart';
import 'package:flutter/foundation.dart';

class MealRepository {
  late Isar _isar;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) {
    _sync = sync;
    if (_sync?.canSync == true) {
      _sync!.streamCollection('meal_logs').listen((data) async {
        for (final entry in data.entries) {
          final log = DailyMealLog.fromJson(entry.value);
          final existing = _isar.dailyMealLogs
              .where()
              .dateEqualTo(entry.key)
              .findFirstSync();
          if (existing == null ||
              jsonEncode(existing.toJson()) != jsonEncode(log.toJson())) {
            if (existing != null) log.id = existing.id;
            await _isar.writeTxn(() async {
              await _isar.dailyMealLogs.put(log);
            });
          }
        }
      });
      _sync!.streamCollection('meal_plans').listen((data) async {
        for (final entry in data.entries) {
          final plan = MealPlan.fromJson(entry.value);
          final existing = _isar.mealPlans
              .where()
              .planNameEqualTo(entry.key)
              .findFirstSync();
          if (existing == null ||
              jsonEncode(existing.toJson()) != jsonEncode(plan.toJson())) {
            if (existing != null) plan.id = existing.id;
            await _isar.writeTxn(() async {
              await _isar.mealPlans.put(plan);
            });
          }
        }
      });
    }
  }

  Future<void> init(Isar isar) async {
    _isar = isar;

    // Quick migration to rename the default plan if the user disliked it.
    final existingPlan = _isar.mealPlans
        .where()
        .planNameEqualTo('standard_plan')
        .findFirstSync();
    if (existingPlan != null &&
        existingPlan.planName == '1200 kcal Cutting Plan') {
      final updatedPlan = existingPlan.copyWith(
        planName: 'Daily Nutrition Plan',
      );
      updatedPlan.id = existingPlan.id;
      await _isar.writeTxn(() async {
        await _isar.mealPlans.put(updatedPlan);
      });
    }

    await _seedIfEmpty();
  }

  Future<void> _seedIfEmpty() async {
    final bodammaPlan = _isar.mealPlans
        .where()
        .planNameEqualTo("Bodamma's Glow & Lean Master Routine")
        .findFirstSync();

    if (bodammaPlan == null) {
      final jsonStr = await rootBundle.loadString(
        'assets/data/seed_meal_plan.json',
      );
      final plan = MealPlan.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
      await _isar.writeTxn(() async {
        await _isar.mealPlans.put(plan);
      });
    }
  }

  DailyMealLog getDailyLog(String date) {
    return _isar.dailyMealLogs.where().dateEqualTo(date).findFirstSync() ??
        DailyMealLog(date: date);
  }

  Stream<DailyMealLog?> watchDailyLog(String date) {
    return _isar.dailyMealLogs
        .where()
        .dateEqualTo(date)
        .watch(fireImmediately: true)
        .map((logs) {
          return logs.isNotEmpty ? logs.first : null;
        });
  }

  List<DailyMealLog> getLogsInRange(String start, String end) {
    return _isar.dailyMealLogs
        .filter()
        .dateGreaterThan(start, include: true)
        .and()
        .dateLessThan(end, include: true)
        .sortByDate()
        .findAllSync();
  }

  Future<void> saveDailyLog(DailyMealLog log) async {
    final existing = _isar.dailyMealLogs
        .where()
        .dateEqualTo(log.date)
        .findFirstSync();
    if (existing != null) {
      log.id = existing.id;
    }
    await _isar.writeTxn(() async {
      await _isar.dailyMealLogs.put(log);
    });
    _sync?.syncToCloud('meal_logs', log.date, log.toJson());
  }

  Future<void> saveMealSlot(
    String date,
    String slotId,
    MealSlotLog slotLog,
  ) async {
    final currentLog = getDailyLog(date);
    final updatedSlots = Map<String, MealSlotLog>.from(currentLog.customSlots);
    updatedSlots[slotId] = slotLog;

    final updated = currentLog.copyWith(customSlots: updatedSlots);
    await saveDailyLog(updated);
  }

  Future<void> clearMealSlot(String date, String slotId) async {
    final currentLog = getDailyLog(date);
    final updatedSlots = Map<String, MealSlotLog>.from(currentLog.customSlots);
    updatedSlots.remove(slotId);

    final updated = currentLog.copyWith(customSlots: updatedSlots);
    await saveDailyLog(updated);
  }

  MealPlan? getMealPlan(String key) {
    return _isar.mealPlans.where().planNameEqualTo(key).findFirstSync();
  }

  Future<void> savePlanJson(String key, String jsonStr) async {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Root JSON must be an object');
    }
    final map = decoded;
    if (map['planName'] == null || map['planName'].toString().trim().isEmpty) {
      throw const FormatException('Missing or empty "planName"');
    }
    final meals = map['meals'];
    if (meals is! List) {
      throw const FormatException('"meals" must be an array');
    }
    final plan = MealPlan.fromJson(map);

    final existing = getMealPlan(key);
    if (existing != null) {
      plan.id = existing.id;
    }
    await _isar.writeTxn(() async {
      await _isar.mealPlans.put(plan);
    });
    _sync?.syncToCloud('meal_plans', key, plan.toJson());
  }

  String? getRawPlanJson(String key) {
    final plan = getMealPlan(key);
    if (plan == null) return null;
    return jsonEncode(plan.toJson());
  }

  List<String> getPlanKeys() {
    final plans = _isar.mealPlans.where().findAllSync();
    return plans.map((p) => p.planName).toList();
  }

  // ── Cloud sync helpers ──

  Future<void> importLogsFromCloud(
    Map<String, Map<String, dynamic>> cloudData,
  ) async {
    for (final entry in cloudData.entries) {
      final existing = _isar.dailyMealLogs
          .where()
          .dateEqualTo(entry.key)
          .findFirstSync();
      if (existing == null) {
        final log = DailyMealLog.fromJson(entry.value);
        await _isar.writeTxn(() async {
          await _isar.dailyMealLogs.put(log);
        });
      }
    }
  }

  Map<String, Map<String, dynamic>> exportLogsForCloud() {
    final result = <String, Map<String, dynamic>>{};
    final logs = _isar.dailyMealLogs.where().findAllSync();
    for (final log in logs) {
      result[log.date] = log.toJson();
    }
    return result;
  }

  Future<void> importPlansFromCloud(
    Map<String, Map<String, dynamic>> cloudData,
  ) async {
    for (final entry in cloudData.entries) {
      final existing = _isar.mealPlans
          .where()
          .planNameEqualTo(entry.key)
          .findFirstSync();
      if (existing == null) {
        final plan = MealPlan.fromJson(entry.value);
        await _isar.writeTxn(() async {
          await _isar.mealPlans.put(plan);
        });
      }
    }
  }

  Future<void> fetchGlobalPlans() async {
    if (_sync == null) return;
    try {
      final globalData = await _sync!.pullGlobalCollection('public_meal_plans');
      for (final entry in globalData.entries) {
        final plan = MealPlan.fromJson(entry.value);
        final existing = _isar.mealPlans
            .where()
            .planNameEqualTo(entry.key)
            .findFirstSync();
        if (existing != null) plan.id = existing.id;
        await _isar.writeTxn(() async {
          await _isar.mealPlans.put(plan);
        });
      }
    } catch (e) {
      debugPrint('Error fetching global meal plans: $e');
    }
  }

  Future<void> fetchUserPlans() async {
    if (_sync == null) return;
    try {
      final userData = await _sync!.pullCollection('meal_plans');
      for (final entry in userData.entries) {
        final plan = MealPlan.fromJson(entry.value);
        final existing = _isar.mealPlans
            .where()
            .planNameEqualTo(entry.key)
            .findFirstSync();
        if (existing != null) plan.id = existing.id;
        await _isar.writeTxn(() async {
          await _isar.mealPlans.put(plan);
        });
      }
    } catch (e) {
      debugPrint('Error fetching user meal plans: $e');
    }
  }

  Map<String, Map<String, dynamic>> exportPlansForCloud() {
    final result = <String, Map<String, dynamic>>{};
    final plans = _isar.mealPlans.where().findAllSync();
    for (final plan in plans) {
      result[plan.planName] = plan.toJson();
    }
    return result;
  }
}
