import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_log.dart';
import '../services/widget_update_service.dart';
import '../models/habit.dart';
import '../services/health_connect_service.dart';
import 'app_providers.dart';

class DailyLogNotifier extends Notifier<DailyLog> {
  StreamSubscription? _sub;

  @override
  DailyLog build() {
    final repo = ref.watch(dailyLogRepoProvider);
    final date = ref.watch(dateStringProvider);

    ref.onDispose(() {
      _sub?.cancel();
    });

    _sub?.cancel();
    _sub = repo.watchLog(date).listen((log) {
      state = log ?? repo.getOrCreate(date);
    });

    return repo.getOrCreate(date);
  }

  Future<void> updateWeight(double weight) async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.updateWeight(state.date, weight);
    state = repo.getOrCreate(state.date);
    WidgetUpdateService.pushWidgetState(ref);
  }

  Future<void> updateSteps(int steps, {String? source}) async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.updateSteps(state.date, steps, source: source ?? 'manual');
    state = repo.getOrCreate(state.date);
    WidgetUpdateService.pushWidgetState(ref);
    ref.read(stepsSourceProvider.notifier).state = (source == 'healthConnect')
        ? StepsSource.healthConnect
        : StepsSource.manual;
  }

  Future<void> updateSleep(double hours, {String? source}) async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.updateSleep(state.date, hours, source: source ?? 'manual');
    state = repo.getOrCreate(state.date);
    WidgetUpdateService.pushWidgetState(ref);

    final habitRepo = ref.read(habitRepoProvider);
    final allHabits = habitRepo.getHabits();
    for (final habit in allHabits.where((h) => h.type == HabitType.autoSleep)) {
      if (hours >= habit.target) {
        await habitRepo.setCompletion(state.date, habit.id, true);
      } else {
        await habitRepo.setCompletion(state.date, habit.id, false);
      }
    }
    ref.invalidate(habitCompletionsProvider);
  }

  Future<void> clearSleep() async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.clearSleep(state.date);
    state = repo.getOrCreate(state.date);
    WidgetUpdateService.pushWidgetState(ref);

    final habitRepo = ref.read(habitRepoProvider);
    final allHabits = habitRepo.getHabits();
    for (final habit in allHabits.where((h) => h.type == HabitType.autoSleep)) {
      await habitRepo.setCompletion(state.date, habit.id, false);
    }
    ref.invalidate(habitCompletionsProvider);
  }

  Future<void> updateBodyFat(double bodyFat) async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.updateBodyFat(state.date, bodyFat);
    state = repo.getOrCreate(state.date);
    WidgetUpdateService.pushWidgetState(ref);
  }

  Future<void> updateWater(int waterMl) async {
    final repo = ref.read(dailyLogRepoProvider);
    final current = state;
    await repo.saveLog(current.copyWith(waterMl: waterMl));
    state = repo.getOrCreate(state.date);
    WidgetUpdateService.pushWidgetState(ref);
  }

  Future<void> clearWater() async {
    final repo = ref.read(dailyLogRepoProvider);
    final current = state;
    await repo.saveLog(current.clearWater());
    state = repo.getOrCreate(state.date);
    WidgetUpdateService.pushWidgetState(ref);
  }

  Future<void> markWorkoutCompleted(String dayId) async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.markWorkoutCompleted(state.date, dayId);
    state = repo.getOrCreate(state.date);
    WidgetUpdateService.pushWidgetState(ref);

    final profile = ref.read(profileProvider);
    if (profile.planStartDate == null) {
      final now = DateTime.now();
      // ignore: unawaited_futures
      ref
          .read(profileProvider.notifier)
          .updateProfile(
            profile.copyWith(
              planStartDate: DateTime(now.year, now.month, now.day),
              currentPhaseWeek: 1,
            ),
          );
    }
  }
}

final dailyLogProvider = NotifierProvider<DailyLogNotifier, DailyLog>(() {
  return DailyLogNotifier();
});

final dailyLogsRangeProvider =
    Provider.family<List<DailyLog>, (String, String)>((ref, range) {
      final (start, end) = range;
      return ref.watch(dailyLogRepoProvider).getLogsInRange(start, end);
    });
