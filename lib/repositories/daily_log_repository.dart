import 'dart:async';
import 'dart:convert';
import 'package:isar/isar.dart';
import '../models/daily_log.dart';
import '../interfaces/i_cloud_sync_service.dart';

class DailyLogRepository {
  late Isar _isar;
  ICloudSyncService? _sync;
  
  int _syncGeneration = 0;
  String? _attachedUid;
  final List<StreamSubscription> _syncSubscriptions = [];
  final Map<String, DateTime> _localEdits = {};

  final _updates = StreamController<void>.broadcast();
  Stream<void> get watchUpdates => _updates.stream;

  Future<void> detachSync() async {
    _syncGeneration++;
    _attachedUid = null;
    final toCancel = List<StreamSubscription>.from(_syncSubscriptions);
    _syncSubscriptions.clear();
    for (final sub in toCancel) {
      try {
        await sub.cancel();
      } catch (e) {
        // ignore errors during teardown
      }
    }
    _sync = null;
  }

  /// Attach a Firestore sync service (called after sign-in).
  Future<void> attachSync(ICloudSyncService sync) async {
    await detachSync();
    _sync = sync;
    final currentGen = _syncGeneration;
    final targetUid = sync.currentUid;
    _attachedUid = targetUid;

    if (sync.canSync) {
      _syncSubscriptions.add(
        sync.streamCollection('daily_logs').listen((data) async {
          if (currentGen != _syncGeneration) return;
          for (final entry in data.entries) {
            if (currentGen != _syncGeneration) return;
            final log = DailyLog.fromJson(entry.value);
            final existing = getLog(entry.key);

            // If incoming is older than existing, skip
            if (existing?.updatedAt != null && log.updatedAt != null && log.updatedAt!.isBefore(existing!.updatedAt!)) {
              continue;
            }
            final localEdit = _localEdits[entry.key];
            if (log.updatedAt != null && localEdit != null && log.updatedAt!.isBefore(localEdit)) {
              continue;
            }

            if (existing == null ||
                jsonEncode(existing.toJson()) != jsonEncode(log.toJson())) {
              if (existing != null) log.id = existing.id;
              await _isar.writeTxn(() async {
                if (currentGen != _syncGeneration ||
                    sync.currentUid != targetUid ||
                    _attachedUid != targetUid) {
                  return;
                }
                await _isar.dailyLogs.put(log);
              });
              _updates.add(null);
            }
          }
        }),
      );
    }
  }

  void dispose() {
    detachSync();
    _updates.close();
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
    _localEdits[log.date] = DateTime.now();
    final updatedLog = log.copyWith(updatedAt: DateTime.now());
    final existing = getLog(log.date);
    if (existing != null) {
      updatedLog.id = existing.id;
    }
    await _isar.writeTxn(() async {
      await _isar.dailyLogs.put(updatedLog);
      _sync?.queueSyncInTxn(_isar, 'daily_logs', updatedLog.date, updatedLog.toJson());
    });
    _sync?.triggerFlush();
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
      if (data.steps != null) {
        if (log.stepsSource != 'manual') {
          updatedLog = updatedLog.copyWith(steps: data.steps, stepsSource: 'healthConnect');
          changed = true;
        }
      }

      // Don't overwrite manual sleep
      if (data.sleepHours != null) {
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

  Future<void> updateWorkoutStatus(String date, String dayId, String status) async {
    final log = getOrCreate(date);
    await saveLog(log.copyWith(workoutStatus: status, workoutDayId: dayId));
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
