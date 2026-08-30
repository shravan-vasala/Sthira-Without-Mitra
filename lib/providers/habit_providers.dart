import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';
import '../models/habit.dart';
import '../models/daily_log.dart';

final habitsProvider = Provider<List<Habit>>((ref) {
  return ref.watch(habitRepoProvider).getHabits();
});

class HabitCompletionsNotifier extends Notifier<HabitCompletion> {
  @override
  HabitCompletion build() {
    final repo = ref.watch(habitRepoProvider);
    final date = ref.watch(dateStringProvider);
    
    final sub = repo.watchCompletions(date).listen((completion) {
      state = completion ?? repo.getCompletions(date);
    });
    
    ref.onDispose(() => sub.cancel());
    
    return repo.getCompletions(date);
  }

  Future<void> toggle(String habitId) async {
    final repo = ref.read(habitRepoProvider);
    final date = ref.read(dateStringProvider);
    await repo.toggleCheckboxCompletion(date, habitId);
    state = repo.getCompletions(date);
  }

  Future<void> updateProgress(String habitId, double progress) async {
    final repo = ref.read(habitRepoProvider);
    final date = ref.read(dateStringProvider);
    await repo.updateProgress(date, habitId, progress);
    state = repo.getCompletions(date);
  }

  Future<void> setOverride(String habitId, String? overrideValue) async {
    final repo = ref.read(habitRepoProvider);
    final date = ref.read(dateStringProvider);
    await repo.setOverride(date, habitId, overrideValue);
    state = repo.getCompletions(date);
  }
}

final habitCompletionsProvider = NotifierProvider<HabitCompletionsNotifier, HabitCompletion>(HabitCompletionsNotifier.new);

final habitStreakProvider = Provider.family<int, String>((ref, habitId) {
  final habitsList = ref.watch(habitsProvider);
  final habit = habitsList.firstWhere((h) => h.id == habitId, orElse: () => Habit(id: '', name: '', icon: '', target: 1));
  if (habit.id.isEmpty) return 0;
  
  final dateStr = ref.watch(dateStringProvider);
  
  // Reactive to today's changes for THIS specific habit
  ref.watch(habitCompletionsProvider.select((c) => c.completions[habitId]));
  ref.watch(habitCompletionsProvider.select((c) => c.overrides[habitId]));
  
  if (habit.type == HabitType.autoSteps) {
    ref.watch(dailyLogProvider.select((d) => d.steps));
  } else if (habit.type == HabitType.autoSleep) {
    ref.watch(dailyLogProvider.select((d) => d.sleepHours));
  }
  
  final habitRepo = ref.watch(habitRepoProvider);
  final dailyLogRepo = ref.watch(dailyLogRepoProvider);
  
  int streak = 0;
  final DateTime current = DateTime.parse(dateStr);
  
  // Check today
  final todayCompletions = habitRepo.getCompletions(dateStr);
  final todayLog = dailyLogRepo.getLog(dateStr) ?? DailyLog(date: dateStr);
  if (isHabitCompleted(habit, todayCompletions, todayLog)) {
    streak++;
  }
  
  // Go backward
  DateTime checkDate = current.subtract(const Duration(days: 1));
  while (streak < 365) {
    final dStr = '${checkDate.year.toString().padLeft(4, '0')}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
    final comp = habitRepo.getCompletions(dStr);
    final log = dailyLogRepo.getLog(dStr) ?? DailyLog(date: dStr);
    
    if (isHabitCompleted(habit, comp, log)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }
  return streak;
});
