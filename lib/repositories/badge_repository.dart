import 'package:hive/hive.dart';
import 'dart:convert';
import '../models/badge.dart';
import '../interfaces/i_cloud_sync_service.dart';

class BadgeRepository {
  static const String _boxName = 'badges_v1';
  late Box<Badge> _box;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) {
    _sync = sync;
    if (_sync?.canSync == true) {
      _sync!.streamCollection('badges').listen((data) async {
        for (final entry in data.entries) {
          final b = Badge.fromJson(entry.value);
          final existing = _box.get(entry.key);
          if (existing == null || jsonEncode(existing.toJson()) != jsonEncode(b.toJson())) {
            await _box.put(entry.key, b);
          }
        }
      });
    }
  }

  Future<void> init() async {
    _box = await Hive.openBox<Badge>(_boxName);
    await _seedDefaultBadges();
  }

  Future<void> _seedDefaultBadges() async {
    final defaults = [
      Badge(
        id: 'first_workout',
        category: 'workout',
        title: 'Welcome to the Iron',
        description: 'Log your first workout',
        iconEmoji: '🏋️',
        requiredProgress: 1,
      ),
      Badge(
        id: 'workout_10',
        category: 'workout',
        title: 'Consistency Key',
        description: 'Log 10 workouts',
        iconEmoji: '🔥',
        requiredProgress: 10,
      ),
      Badge(
        id: 'workout_50',
        category: 'workout',
        title: 'Iron Lifter',
        description: 'Log 50 workouts',
        iconEmoji: '🦍',
        requiredProgress: 50,
      ),
      Badge(
        id: 'streak_3',
        category: 'streak',
        title: 'Momentum',
        description: 'Workout 3 days in a row',
        iconEmoji: '⚡',
        requiredProgress: 3,
      ),
      Badge(
        id: 'streak_7',
        category: 'streak',
        title: 'Unstoppable',
        description: 'Workout 7 days in a row',
        iconEmoji: '🔥',
        requiredProgress: 7,
      ),
    ];

    for (final b in defaults) {
      if (!_box.containsKey(b.id)) {
        await _box.put(b.id, b);
      }
    }
  }

  List<Badge> getAllBadges() {
    return _box.values.toList();
  }

  Badge? getBadge(String id) {
    return _box.get(id);
  }

  Future<void> saveBadge(Badge badge) async {
    await _box.put(badge.id, badge);
    _sync?.syncToCloud('badges', badge.id, badge.toJson());
  }

  /// Bulk import from Firestore (used on new-device sign-in).
  Future<void> importFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      final cloudBadge = Badge.fromJson(entry.value);
      final localBadge = _box.get(entry.key);

      if (localBadge == null) {
        await _box.put(entry.key, cloudBadge);
      } else {
        final localDate = localBadge.unlockedAt ?? DateTime.parse('2000-01-01');
        final cloudDate = cloudBadge.unlockedAt ?? DateTime.parse('2000-01-01');
        if (cloudDate.isAfter(localDate) || (cloudBadge.currentProgress > localBadge.currentProgress && localBadge.unlockedAt == null)) {
          await _box.put(entry.key, cloudBadge);
        }
      }
    }
  }

  /// Export all local data as a map for bulk cloud upload.
  Map<String, Map<String, dynamic>> exportForCloud() {
    final result = <String, Map<String, dynamic>>{};
    for (final badge in _box.values) {
      result[badge.id] = badge.toJson();
    }
    return result;
  }

  Future<void> clearAllProgressForDebug() async {
    final keys = _box.keys.toList();
    for (final key in keys) {
      final badge = _box.get(key);
      if (badge != null) {
        await _box.put(key, Badge(
          id: badge.id,
          category: badge.category,
          title: badge.title,
          description: badge.description,
          iconEmoji: badge.iconEmoji,
          requiredProgress: badge.requiredProgress,
          currentProgress: 0,
          unlockedAt: null,
        ));
      }
    }
  }
}
