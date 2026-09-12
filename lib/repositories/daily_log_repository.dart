import 'dart:async';
import 'dart:convert';
import 'package:isar/isar.dart';
import '../models/daily_log.dart';
import '../interfaces/i_cloud_sync_service.dart';

class DailyLogRepository {
  late Isar _isar;
  ICloudSyncService? _sync;
  
  final _updates = StreamController<void>.broadcast();
  Stream<void> get watchUpdates => _updates.stream;

  /// Attach a Firestore sync service (called after sign-in).
  void attachSync(ICloudSyncService sync) {
    _sync = sync;
    if (_sync?.canSync == true) {
      _sync!.streamCollection('daily_logs').listen((data) async {
        for (final entry in data.entries) {
          final log = DailyLog.fromJson(entry.value);
          final existing = getLog(entry.key);
          if (existing == null ||
              jsonEncode(existing.toJson()) != jsonEncode(log.toJson())) {
            if (existing != null) log.id = existing.id;
            await _isar.writeTxn(() async {
              await _isar.dailyLogs.put(log);
            });
            _updates.add(null);
          }
        }
      });
    }
  }

  Future<void> init(Isar isar) async {
    _isar = isar;
  }

  DailyLog? getLog(String date) {
    return _isar.dailyLogs.where().dateEqualTo(date).findFirstSync();
  }

  Stream<DailyLog?> watchLog(String date) {
    return _isar.dailyLogs
        .where()
        .dateEqualTo(date)
        .watch(fireImmediately: true)
        .map((logs) {
          return logs.isNotEmpty ? logs.first : null;
        });
  }

  DailyLog getOrCreate(String date) {
    return getLog(date) ?? DailyLog(date: date);
  }

  Future<void> saveLog(DailyLog log) async {
    final updatedLog = log.copyWith(updatedAt: DateTime.now());
    final existing = getLog(log.date);
    if (existing != null) {
      updatedLog.id = existing.id;
    }
    await _isar.writeTxn(() async {
      await _isar.dailyLogs.put(updatedLog);
    });
    _sync?.syncToCloud('daily_logs', updatedLog.date, updatedLog.toJson());
    _updates.add(null);
  }

  Future<void> updateWeight(String date, double weight) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(weight: weight));
  }

  Future<void> updateSteps(String date, int steps, {String? source}) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(steps: steps, stepsSource: source));
  }

  Future<void> updateScreenTime(String date, int minutes) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(screenTimeMinutes: minutes));
  }

  Future<void> updateSleep(String date, double? hours, {String? source}) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(sleepHours: hours, sleepSource: source));
  }

  Future<void> updateFromHealthConnect(List<dynamic> healthDataList) async {
    for (final data in healthDataList) {
      final log = getOrCreate(data.dateStr);
      var updatedLog = log;
      bool changed = false;

      // Don't overwrite manual steps
      if (data.steps != null && data.steps > 0) {
        if (log.stepsSource != 'manual') {
          updatedLog = updatedLog.copyWith(steps: data.steps, stepsSource: 'healthConnect');
          changed = true;
        }
      }

      // Don't overwrite manual sleep
      if (data.sleepHours != null && data.sleepHours > 0) {
        if (log.sleepSource != 'manual') {
          updatedLog = updatedLog.copyWith(sleepHours: data.sleepHours, sleepSource: 'healthConnect');
          changed = true;
        }
      }

      if (changed) {
        await saveLog(updatedLog);
      }
    }
  }

  Future<void> clearSteps(String date) async {
    final log = getOrCreate(date);
    await saveLog(log.clearSteps());
  }

  Future<void> clearSleep(String date) async {
    final log = getOrCreate(date);
    await saveLog(log.clearSleep());
  }

  Future<void> updateBodyFat(String date, double bodyFat) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(bodyFat: bodyFat));
  }

  Future<void> markWorkoutCompleted(String date, String dayId) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(workoutCompleted: true, workoutDayId: dayId));
  }

  List<DailyLog> getLogsInRange(String startDate, String endDate) {
    return _isar.dailyLogs
        .filter()
        .dateGreaterThan(startDate, include: true)
        .and()
        .dateLessThan(endDate, include: true)
        .sortByDate()
        .findAllSync();
  }

  List<DailyLog> getAllLogs() {
    return _isar.dailyLogs.where().sortByDate().findAllSync();
  }

  bool hasActivityOnDate(String date) {
    final log = getLog(date);
    return log?.hasAnyActivity ?? false;
  }

  /// Bulk import from Firestore (used on new-device sign-in).
  Future<void> importFromCloud(
    Map<String, Map<String, dynamic>> cloudData,
  ) async {
    for (final entry in cloudData.entries) {
      final cloudLog = DailyLog.fromJson(entry.value);
      final localLog = getLog(entry.key);

      if (localLog == null) {
        await _isar.writeTxn(() async {
          await _isar.dailyLogs.put(cloudLog);
        });
      } else {
        final localDate = localLog.updatedAt ?? DateTime.parse('2000-01-01');
        final cloudDate = cloudLog.updatedAt ?? DateTime.parse('2000-01-01');
        if (cloudDate.isAfter(localDate)) {
          cloudLog.id = localLog.id;
          await _isar.writeTxn(() async {
            await _isar.dailyLogs.put(cloudLog);
          });
        }
      }
    }
    _updates.add(null);
  }

  /// Export all local data as a map for bulk cloud upload.
  Map<String, Map<String, dynamic>> exportForCloud() {
    final result = <String, Map<String, dynamic>>{};
    final logs = _isar.dailyLogs.where().findAllSync();
    for (final log in logs) {
      result[log.date] = log.toJson();
    }
    return result;
  }
}
