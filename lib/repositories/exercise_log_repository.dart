import 'package:isar/isar.dart';
import '../models/exercise_log.dart';
import '../models/exercise_pr.dart';
import '../interfaces/i_cloud_sync_service.dart';

class ExerciseLogRepository {
  late Isar _isar;
  ICloudSyncService? _sync;

  Stream<void> get watchUpdates => _isar.exerciseLogs.watchLazy(fireImmediately: true);

  void attachSync(ICloudSyncService sync) => _sync = sync;
  Future<void> detachSync() async { _sync = null; }

  Future<void> init(Isar isar) async {
    _isar = isar;
  }

  ExercisePr? getPr(String exerciseName) {
    return _isar.exercisePrs
        .where()
        .exerciseNameEqualTo(exerciseName)
        .findFirstSync();
  }

  Future<void> savePr(ExercisePr pr) async {
    final existing = getPr(pr.exerciseName);
    if (existing != null) pr.id = existing.id;
    await _isar.writeTxn(() async {
      await _isar.exercisePrs.put(pr);
      _sync?.queueSyncInTxn(_isar, 'exercise_prs', pr.exerciseName, pr.toJson());
    });
    _sync?.triggerFlush();
  }

  ExerciseLog? getLog(String date, String instanceId) {
    return _isar.exerciseLogs
        .filter()
        .dateEqualTo(date)
        .and()
        .instanceIdEqualTo(instanceId)
        .findFirstSync();
  }

  Future<void> saveLog(ExerciseLog log) async {
    final existing = getLog(log.date, log.instanceId);
    if (existing != null) log.id = existing.id;
    await _isar.writeTxn(() async {
      await _isar.exerciseLogs.put(log);
      _sync?.queueSyncInTxn(_isar, 'exercise_logs', log.key, log.toJson());
    });
    _sync?.triggerFlush();
  }

  Future<void> deleteLog(String date, String instanceId) async {
    final existing = getLog(date, instanceId);
    if (existing != null) {
      await _isar.writeTxn(() async {
        await _isar.exerciseLogs.delete(existing.id);
        _sync?.queueDeleteInTxn(_isar, 'exercise_logs', existing.key);
      });
      _sync?.triggerFlush();
    }
  }

  bool hasLog(String date, String instanceId) {
    final log = getLog(date, instanceId);
    return log != null && log.sets.isNotEmpty;
  }

  List<ExerciseLog> getLogsForExercise(String exerciseName) {
    // Isar doesn't have a good endswith query out of the box, but we can query all and filter, or use filter().keyEndsWith()
    return _isar.exerciseLogs
        .filter()
        .exerciseNameEqualTo(exerciseName)
        .sortByDate()
        .findAllSync();
  }

  List<ExerciseLog> getLogsForDate(String date) {
    return _isar.exerciseLogs.filter().dateEqualTo(date).findAllSync();
  }

  ExerciseLog? getLastLog(String exerciseName, {String? beforeDate}) {
    var logs = getLogsForExercise(exerciseName);
    if (beforeDate != null) {
      logs = logs.where((l) => l.date.compareTo(beforeDate) <= 0).toList();
    }
    if (logs.isEmpty) return null;
    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs.first;
  }

  // ── Cloud sync helpers ──

  Future<void> importLogsFromCloud(
    Map<String, Map<String, dynamic>> cloudData,
  ) async {
    for (final entry in cloudData.entries) {
      final log = ExerciseLog.fromJson(entry.value);
      if (getLog(log.date, log.instanceId) == null) {
        await _isar.writeTxn(() async {
          await _isar.exerciseLogs.put(log);
        });
      }
    }
  }

  Future<void> importPrsFromCloud(
    Map<String, Map<String, dynamic>> cloudData,
  ) async {
    for (final entry in cloudData.entries) {
      if (getPr(entry.key) == null) {
        final pr = ExercisePr.fromJson(entry.value);
        await _isar.writeTxn(() async {
          await _isar.exercisePrs.put(pr);
        });
      }
    }
  }

  Map<String, Map<String, dynamic>> exportLogsForCloud() {
    final result = <String, Map<String, dynamic>>{};
    final logs = _isar.exerciseLogs.where().findAllSync();
    for (final log in logs) {
      result[log.key] = log.toJson();
    }
    return result;
  }

  Map<String, Map<String, dynamic>> exportPrsForCloud() {
    final result = <String, Map<String, dynamic>>{};
    final prs = _isar.exercisePrs.where().findAllSync();
    for (final pr in prs) {
      result[pr.exerciseName] = pr.toJson();
    }
    return result;
  }
}
