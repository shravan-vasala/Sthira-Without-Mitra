import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/habit.dart';
import '../interfaces/i_cloud_sync_service.dart';

class HabitRepository {
  static const String _configBoxName = 'habit_config_v2';
  static const String _completionBoxName = 'habit_completions_v2';

  late Box<Habit> _configBox;
  late Box<HabitCompletion> _completionBox;
  ICloudSyncService? _sync;

  void attachSync(ICloudSyncService sync) => _sync = sync;

  Future<void> init() async {
    _configBox = await Hive.openBox<Habit>(_configBoxName);
    _completionBox = await Hive.openBox<HabitCompletion>(_completionBoxName);
    await _seedIfEmpty();
  }

  Future<void> _seedIfEmpty() async {
    if (_configBox.isEmpty) {
      final defaultHabits = Habit.defaults;
      for (final habit in defaultHabits) {
        await _configBox.put(habit.id, habit);
      }
    }
  }

  // Legacy migrations removed, handled by V2 migration now.

  List<Habit> getHabits() {
    final habits = _configBox.values.toList();
    habits.sort((a, b) => a.order.compareTo(b.order));
    return habits;
  }

  Future<void> saveHabit(Habit habit) async {
    final updatedHabit = habit.copyWith(updatedAt: DateTime.now());
    await _configBox.put(updatedHabit.id, updatedHabit);
    _sync?.syncToCloud('habit_config', updatedHabit.id, updatedHabit.toJson());
  }

  Future<void> deleteHabit(String id) async {
    await _configBox.delete(id);
    _sync?.deleteFromCloud('habit_config', id);
  }

  Future<void> reorderHabits(List<Habit> reordered) async {
    for (int i = 0; i < reordered.length; i++) {
      final h = reordered[i].copyWith(order: i);
      await saveHabit(h);
    }
  }

  HabitCompletion getCompletions(String date) {
    return _completionBox.get(date) ?? HabitCompletion(date: date);
  }

  Future<void> saveCompletion(HabitCompletion completion) async {
    final updatedCompletion = HabitCompletion(
      date: completion.date,
      completions: completion.completions,
      overrides: completion.overrides,
      streaks: completion.streaks,
      updatedAt: DateTime.now(),
    );
    await _completionBox.put(updatedCompletion.date, updatedCompletion);
    _sync?.syncToCloud('habit_completions', updatedCompletion.date, updatedCompletion.toJson());
  }

  // Checkbox toggle
  Future<void> toggleCheckboxCompletion(String date, String habitId) async {
    final completion = getCompletions(date);
    final updated = completion.toggleCheckbox(habitId);
    await saveCompletion(updated);
  }

  // Counter / numeric update
  Future<void> updateProgress(String date, String habitId, double progress) async {
    final completion = getCompletions(date);
    final updated = completion.updateProgress(habitId, progress);
    await saveCompletion(updated);
  }

  // Backwards compatibility for old HealthConnectService code
  Future<void> setCompletion(String date, String habitId, dynamic completed) async {
    final completion = getCompletions(date);
    final current = completion.completions[habitId];
    if (current == completed) return; 

    final newCompletions = Map<String, dynamic>.from(completion.completions);
    newCompletions[habitId] = completed;
    final updated = HabitCompletion(date: date, completions: newCompletions, overrides: completion.overrides);
    await saveCompletion(updated);
  }

  Future<void> setOverride(String date, String habitId, String? overrideValue) async {
    final completion = getCompletions(date);
    final updated = completion.setOverride(habitId, overrideValue);
    await saveCompletion(updated);
  }

  // ── Cloud sync helpers ──

  Future<void> importConfigFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      final cloudHabit = Habit.fromJson(entry.value);
      final localHabit = _configBox.get(entry.key);

      if (localHabit == null) {
        await _configBox.put(entry.key, cloudHabit);
      } else {
        final localDate = localHabit.updatedAt ?? DateTime.parse('2000-01-01');
        final cloudDate = cloudHabit.updatedAt ?? DateTime.parse('2000-01-01');
        if (cloudDate.isAfter(localDate)) {
          await _configBox.put(entry.key, cloudHabit);
        }
      }
    }
  }

  Future<void> importCompletionsFromCloud(Map<String, Map<String, dynamic>> cloudData) async {
    for (final entry in cloudData.entries) {
      final cloudCompletion = HabitCompletion.fromJson(entry.value);
      final localCompletion = _completionBox.get(entry.key);

      if (localCompletion == null) {
        await _completionBox.put(entry.key, cloudCompletion);
      } else {
        final localDate = localCompletion.updatedAt ?? DateTime.parse('2000-01-01');
        final cloudDate = cloudCompletion.updatedAt ?? DateTime.parse('2000-01-01');
        if (cloudDate.isAfter(localDate)) {
          await _completionBox.put(entry.key, cloudCompletion);
        }
      }
    }
  }

  Map<String, Map<String, dynamic>> exportConfigForCloud() {
    final result = <String, Map<String, dynamic>>{};
    for (final habit in _configBox.values) {
      result[habit.id] = habit.toJson();
    }
    return result;
  }

  Map<String, Map<String, dynamic>> exportCompletionsForCloud() {
    final result = <String, Map<String, dynamic>>{};
    for (final completion in _completionBox.values) {
      result[completion.date] = completion.toJson();
    }
    return result;
  }
}
