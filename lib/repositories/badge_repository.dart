import 'dart:convert';
import 'package:isar/isar.dart';
import '../models/badge.dart';
import '../interfaces/i_cloud_sync_service.dart';

class BadgeRepository {
  late Isar _isar;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) {
    _sync = sync;
    if (_sync?.canSync == true) {
      _sync!.streamCollection('badges').listen((data) async {
        for (final entry in data.entries) {
          final b = Badge.fromJson(entry.value);
          final existing = _isar.badges.where().idStrEqualTo(entry.key).findFirstSync();
          if (existing == null || jsonEncode(existing.toJson()) != jsonEncode(b.toJson())) {
            if (existing != null) b.id = existing.id;
            await _isar.writeTxn(() async {
              await _isar.badges.put(b);
            });
          }
        }
      });
    }
  }

  Future<void> init(Isar isar) async {
    _isar = isar;
    await _seedDefaultBadges();
  }

  Future<void> _seedDefaultBadges() async {
    final defaults = [
      Badge(
        idStr: 'first_workout',
        category: 'workout',
        title: 'Welcome to the Iron',
        description: 'Log your first workout',
        iconEmoji: '🏋️',
        requiredProgress: 1,
      ),
      Badge(
        idStr: 'workout_10',
        category: 'workout',
        title: 'Consistency Key',
        description: 'Log 10 workouts',
        iconEmoji: '🔥',
        requiredProgress: 10,
      ),
      Badge(
        idStr: 'workout_50',
        category: 'workout',
        title: 'Iron Lifter',
        description: 'Log 50 workouts',
        iconEmoji: '🦍',
        requiredProgress: 50,
      ),
      Badge(
        idStr: 'streak_3',
        category: 'streak',
        title: 'Momentum',
        description: 'Workout 3 days in a row',
        iconEmoji: '⚡',
        requiredProgress: 3,
      ),
      Badge(
        idStr: 'streak_7',
        category: 'streak',
        title: 'Unstoppable',
        description: 'Workout 7 days in a row',
        iconEmoji: '🔥',
        requiredProgress: 7,
      ),
    ];

    await _isar.writeTxn(() async {
      for (final b in defaults) {
        if (_isar.badges.where().idStrEqualTo(b.idStr).findFirstSync() == null) {
          await _isar.badges.put(b);
        }
      }
    });
  }

  List<Badge> getAllBadges() {
    return _isar.badges.where().findAllSync();
  }

  Badge? getBadge(String idStr) {
    return _isar.badges.where().idStrEqualTo(idStr).findFirstSync();
  }

  Future<void> saveBadge(Badge badge) async {
    final existing = getBadge(badge.idStr);
    if (existing != null) {
      badge.id = existing.id;
    }
    await _isar.writeTxn(() async {
      await _isar.badges.put(badge);
    });
    _sync?.syncToCloud('badges', badge.idStr, badge.toJson());
  }

  /// Bulk import from Firestore (used on new-device sign-in).
  Future<void> importFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      final cloudBadge = Badge.fromJson(entry.value);
      final localBadge = getBadge(entry.key);

      if (localBadge == null) {
        await _isar.writeTxn(() async {
          await _isar.badges.put(cloudBadge);
        });
      } else {
        final localDate = localBadge.unlockedAt ?? DateTime.parse('2000-01-01');
        final cloudDate = cloudBadge.unlockedAt ?? DateTime.parse('2000-01-01');
        if (cloudDate.isAfter(localDate) || (cloudBadge.currentProgress > localBadge.currentProgress && localBadge.unlockedAt == null)) {
          cloudBadge.id = localBadge.id;
          await _isar.writeTxn(() async {
            await _isar.badges.put(cloudBadge);
          });
        }
      }
    }
  }

  /// Export all local data as a map for bulk cloud upload.
  Map<String, Map<String, dynamic>> exportForCloud() {
    final result = <String, Map<String, dynamic>>{};
    final badges = getAllBadges();
    for (final badge in badges) {
      result[badge.idStr] = badge.toJson();
    }
    return result;
  }

  Future<void> clearAllProgressForDebug() async {
    final badges = getAllBadges();
    for (final badge in badges) {
      final newBadge = Badge(
        idStr: badge.idStr,
        category: badge.category,
        title: badge.title,
        description: badge.description,
        iconEmoji: badge.iconEmoji,
        requiredProgress: badge.requiredProgress,
        currentProgress: 0,
        unlockedAt: null,
      );
      newBadge.id = badge.id;
      await _isar.writeTxn(() async {
        await _isar.badges.put(newBadge);
      });
    }
  }
}

