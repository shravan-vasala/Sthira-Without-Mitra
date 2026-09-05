import 'package:isar/isar.dart';
import '../models/body_stats.dart';
import '../interfaces/i_cloud_sync_service.dart';

class BodyStatsRepository {
  late Isar _isar;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) => _sync = sync;

  Future<void> init(Isar isar) async {
    _isar = isar;
  }

  BodyStats? getStats(String date) {
    return _isar.bodyStats.where().dateEqualTo(date).findFirstSync();
  }

  Future<void> saveStats(BodyStats stats) async {
    final existing = getStats(stats.date);
    if (existing != null) {
      stats.id = existing.id;
    }
    await _isar.writeTxn(() async {
      await _isar.bodyStats.put(stats);
    });
    _sync?.syncToCloud('body_stats', stats.date, stats.toJson());
  }

  BodyStats? getLatestStats() {
    return _isar.bodyStats.where().sortByDateDesc().findFirstSync();
  }

  List<BodyStats> getAllStats() {
    return _isar.bodyStats.where().sortByDate().findAllSync();
  }

  // ── Cloud sync helpers ──

  Future<void> importStatsFromCloud(
    Map<String, Map<String, dynamic>> cloudData,
  ) async {
    for (final entry in cloudData.entries) {
      if (getStats(entry.key) == null) {
        final stats = BodyStats.fromJson(entry.value);
        await _isar.writeTxn(() async {
          await _isar.bodyStats.put(stats);
        });
      }
    }
  }

  Map<String, Map<String, dynamic>> exportStatsForCloud() {
    final result = <String, Map<String, dynamic>>{};
    final allStats = getAllStats();
    for (final stats in allStats) {
      result[stats.date] = stats.toJson();
    }
    return result;
  }
}
