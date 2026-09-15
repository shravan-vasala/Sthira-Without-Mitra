import 'dart:async';
import 'dart:convert';
import 'package:isar/isar.dart';
import '../models/daily_log.dart';
import '../interfaces/i_cloud_sync_service.dart';
import '../models/sync_queue_item.dart';
import '../services/health_connect_service.dart';

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
    _syncGeneration++; // Synchronous unique generation
    final currentGen = _syncGeneration;
    _sync = sync;
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
            if (existing?.updatedAt != null &&
                log.updatedAt != null &&
                log.updatedAt!.isBefore(existing!.updatedAt!)) {
              continue;
            }
            final localEdit = _localEdits[entry.key];
            if (log.updatedAt != null &&
                localEdit != null &&
                log.updatedAt!.isBefore(localEdit)) {
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
                final reloaded = _isar.dailyLogs
                    .where()
                    .dateEqualTo(entry.key)
                    .findFirstSync();
                if (reloaded?.updatedAt != null &&
                    log.updatedAt != null &&
                    log.updatedAt!.isBefore(reloaded!.updatedAt!)) {
                  return;
                }
                if (reloaded != null) log.id = reloaded.id;
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
      if (_isar.name != 'guest') {
        _isar.syncQueueItems.put(
          SyncQueueItem(
            uid: _isar.name,
            collection: 'daily_logs',
            docId: updatedLog.date,
            payload: jsonEncode(updatedLog.toJson()),
            timestamp: DateTime.now(),
          ),
        );
      }
    });
    _sync?.triggerFlush();
    _updates.add(null);
  }

  Future<void> _updateLogSafe(
    String date,
    DailyLog Function(DailyLog) modifier,
  ) async {
    _localEdits[date] = DateTime.now();
    await _isar.writeTxn(() async {
      final current =
          await _isar.dailyLogs.where().dateEqualTo(date).findFirst() ??
          DailyLog(date: date);
      final updated = modifier(current).copyWith(updatedAt: DateTime.now());
      updated.id = current.id;

      await _isar.dailyLogs.put(updated);
      if (_isar.name != 'guest') {
        _isar.syncQueueItems.put(
          SyncQueueItem(
            uid: _isar.name,
            collection: 'daily_logs',
            docId: updated.date,
            payload: jsonEncode(updated.toJson()),
            timestamp: DateTime.now(),
          ),
        );
      }
    });
    _sync?.triggerFlush();
    _updates.add(null);
  }

  Future<void> updateWeight(String date, double weight) async {
    await _updateLogSafe(date, (log) => log.copyWith(weight: weight));
  }

  Future<void> updateCheckIn(String date, String feeling, String? note) async {
    await _updateLogSafe(
      date,
      (log) => log.copyWith(
        dayFeeling: feeling,
        dayNote: note,
        checkInUpdatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> removeCheckIn(String date) async {
    await _updateLogSafe(date, (log) => log.clearCheckIn());
  }

  Future<void> updateSteps(String date, int steps, {String? source}) async {
    await _updateLogSafe(
      date,
      (log) => log.copyWith(steps: steps, stepsSource: source),
    );
  }

  Future<void> updateScreenTime(String date, int minutes) async {
    await _updateLogSafe(
      date,
      (log) => log.copyWith(screenTimeMinutes: minutes),
    );
  }

  Future<void> updateSleep(String date, double? hours, {String? source}) async {
    await _updateLogSafe(
      date,
      (log) => log.copyWith(sleepHours: hours, sleepSource: source),
    );
  }

  Future<void> updateFromHealthConnect(List<dynamic> healthDataList) async {
    for (final data in healthDataList) {
      await _updateLogSafe(data.dateStr, (log) {
        var updated = log;
        if (log.stepsSource != 'manual') {
          if (data.stepsResult.status == HealthStatus.success) {
            updated = updated.copyWith(
              steps: data.stepsResult.data,
              stepsSource: 'healthConnect',
            );
          } else if (data.stepsResult.status == HealthStatus.empty) {
            updated = updated.copyWith(steps: 0, stepsSource: 'healthConnect');
          }
        }
        if (log.sleepSource != 'manual') {
          if (data.sleepResult.status == HealthStatus.success) {
            updated = updated.copyWith(
              sleepHours: data.sleepResult.data,
              sleepSource: 'healthConnect',
            );
          } else if (data.sleepResult.status == HealthStatus.empty) {
            updated = updated.copyWith(
              sleepHours: 0.0,
              sleepSource: 'healthConnect',
            );
          }
        }
        return updated;
      });
    }
  }

  Future<void> clearSteps(String date) async {
    await _updateLogSafe(date, (log) => log.clearSteps());
  }

  Future<void> clearSleep(String date) async {
    await _updateLogSafe(date, (log) => log.clearSleep());
  }

  Future<void> updateBodyFat(String date, double bodyFat) async {
    await _updateLogSafe(date, (log) => log.copyWith(bodyFat: bodyFat));
  }

  Future<void> updateWorkoutStatus(
    String date,
    String dayId,
    String status,
  ) async {
    await _updateLogSafe(
      date,
      (log) => log.copyWith(workoutStatus: status, workoutDayId: dayId),
    );
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
