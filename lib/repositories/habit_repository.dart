import 'package:isar/isar.dart';
import '../models/habit.dart';
import '../interfaces/i_cloud_sync_service.dart';

class HabitRepository {
  late Isar _isar;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) => _sync = sync;

  Future<void> init(Isar isar) async {
    _isar = isar;
    await _seedIfEmpty();
  }

  Future<void> _seedIfEmpty() async {
    if (_isar.habits.where().countSync() == 0) {
      final defaultHabits = Habit.defaults;
      await _isar.writeTxn(() async {
        for (final habit in defaultHabits) {
          await _isar.habits.put(habit);
        }
      });
    }
  }

  List<Habit> getHabits() {
    return _isar.habits.where().sortByOrder().findAllSync();
  }

  Habit? getHabit(String id) {
    return _isar.habits.where().idEqualTo(id).findFirstSync();
  }

  Future<void> saveHabit(Habit habit) async {
    final updatedHabit = habit.copyWith(updatedAt: DateTime.now());
    final existing = getHabit(habit.id);
    if (existing != null) {
      updatedHabit.idInternal = existing.idInternal;
    }
    await _isar.writeTxn(() async {
      await _isar.habits.put(updatedHabit);
    });
    _sync?.syncToCloud('habit_config', updatedHabit.id, updatedHabit.toJson());
  }

  Future<void> deleteHabit(String id) async {
    final existing = getHabit(id);
    if (existing != null) {
      await _isar.writeTxn(() async {
        await _isar.habits.delete(existing.idInternal);
      });
    }
    _sync?.deleteFromCloud('habit_config', id);
  }

  Future<void> reorderHabits(List<Habit> reordered) async {
    for (int i = 0; i < reordered.length; i++) {
      final h = reordered[i].copyWith(order: i);
      await saveHabit(h);
    }
  }

  HabitCompletion getCompletions(String date) {
    return _isar.habitCompletions.where().dateEqualTo(date).findFirstSync() ??
        HabitCompletion(date: date);
  }

  Stream<HabitCompletion?> watchCompletions(String date) {
    return _isar.habitCompletions
        .where()
        .dateEqualTo(date)
        .watch(fireImmediately: true)
        .map((comps) {
          return comps.isNotEmpty ? comps.first : null;
        });
  }

  Future<void> saveCompletion(HabitCompletion completion) async {
    final updatedCompletion = HabitCompletion(
      date: completion.date,
      completions: completion.completions,
      overrides: completion.overrides,
      streaks: completion.streaks,
      updatedAt: DateTime.now(),
    );
    final existing = _isar.habitCompletions
        .where()
        .dateEqualTo(completion.date)
        .findFirstSync();
    if (existing != null) {
      updatedCompletion.id = existing.id;
    }
    await _isar.writeTxn(() async {
      await _isar.habitCompletions.put(updatedCompletion);
    });
    _sync?.syncToCloud(
      'habit_completions',
      updatedCompletion.date,
      updatedCompletion.toJson(),
    );
  }

  // Checkbox toggle
  Future<void> toggleCheckboxCompletion(String date, String habitId) async {
    final completion = getCompletions(date);
    final updated = completion.toggleCheckbox(habitId);
    await saveCompletion(updated);
  }

  // Counter / numeric update
  Future<void> updateProgress(
    String date,
    String habitId,
    double progress,
  ) async {
    final completion = getCompletions(date);
    final updated = completion.updateProgress(habitId, progress);
    await saveCompletion(updated);
  }

  // Backwards compatibility for old HealthConnectService code
  Future<void> setCompletion(
    String date,
    String habitId,
    dynamic completed,
  ) async {
    final completion = getCompletions(date);
    final current = completion.completions[habitId];
    if (current == completed) return;

    final newCompletions = Map<String, dynamic>.from(completion.completions);
    newCompletions[habitId] = completed;
    final updated = HabitCompletion(
      date: date,
      completions: newCompletions,
      overrides: completion.overrides,
    );
    await saveCompletion(updated);
  }

  Future<void> setOverride(
    String date,
    String habitId,
    String? overrideValue,
  ) async {
    final completion = getCompletions(date);
    final updated = completion.setOverride(habitId, overrideValue);
    await saveCompletion(updated);
  }

  // ── Cloud sync helpers ──

  Future<void> importConfigFromCloud(
    Map<String, Map<String, dynamic>> cloudData,
  ) async {
    for (final entry in cloudData.entries) {
      final cloudHabit = Habit.fromJson(entry.value);
      final localHabit = getHabit(entry.key);

      if (localHabit == null) {
        await _isar.writeTxn(() async {
          await _isar.habits.put(cloudHabit);
        });
      } else {
        final localDate = localHabit.updatedAt ?? DateTime.parse('2000-01-01');
        final cloudDate = cloudHabit.updatedAt ?? DateTime.parse('2000-01-01');
        if (cloudDate.isAfter(localDate)) {
          cloudHabit.idInternal = localHabit.idInternal;
          await _isar.writeTxn(() async {
            await _isar.habits.put(cloudHabit);
          });
        }
      }
    }
  }

  Future<void> importCompletionsFromCloud(
    Map<String, Map<String, dynamic>> cloudData,
  ) async {
    for (final entry in cloudData.entries) {
      final cloudCompletion = HabitCompletion.fromJson(entry.value);
      final localCompletion = _isar.habitCompletions
          .where()
          .dateEqualTo(entry.key)
          .findFirstSync();

      if (localCompletion == null) {
        await _isar.writeTxn(() async {
          await _isar.habitCompletions.put(cloudCompletion);
        });
      } else {
        final localDate =
            localCompletion.updatedAt ?? DateTime.parse('2000-01-01');
        final cloudDate =
            cloudCompletion.updatedAt ?? DateTime.parse('2000-01-01');
        if (cloudDate.isAfter(localDate)) {
          cloudCompletion.id = localCompletion.id;
          await _isar.writeTxn(() async {
            await _isar.habitCompletions.put(cloudCompletion);
          });
        }
      }
    }
  }

  Map<String, Map<String, dynamic>> exportConfigForCloud() {
    final result = <String, Map<String, dynamic>>{};
    final habits = getHabits();
    for (final habit in habits) {
      result[habit.id] = habit.toJson();
    }
    return result;
  }

  Map<String, Map<String, dynamic>> exportCompletionsForCloud() {
    final result = <String, Map<String, dynamic>>{};
    final completions = _isar.habitCompletions.where().findAllSync();
    for (final completion in completions) {
      result[completion.date] = completion.toJson();
    }
    return result;
  }
}
