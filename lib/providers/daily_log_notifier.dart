import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_log.dart';

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
    await updateWeightForDate(state.date, weight);
  }

  Future<void> updateWeightForDate(String date, double weight) async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.updateWeight(date, weight);
    if (state.date == date) {
      state = repo.getOrCreate(date);
    }
  }

  Future<void> updateSteps(int steps, {String? source}) async {
    await updateStepsForDate(state.date, steps, source: source);
  }

  Future<void> updateStepsForDate(String date, int steps, {String? source}) async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.updateSteps(date, steps, source: source ?? 'manual');
    if (state.date == date) {
      state = repo.getOrCreate(date);
    }
    ref.read(stepsSourceProvider.notifier).state = (source == 'healthConnect')
        ? StepsSource.healthConnect
        : StepsSource.manual;
  }

  Future<void> clearStepsForDate(String date) async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.clearSteps(date);
    if (state.date == date) {
      state = repo.getOrCreate(date);
    }
    ref.read(stepsSourceProvider.notifier).state = StepsSource.manual;
  }

  Future<void> updateSleep(double hours, {String? source}) async {
    await updateSleepForDate(state.date, hours, source: source);
  }

  Future<void> updateSleepForDate(String date, double hours, {String? source}) async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.updateSleep(date, hours, source: source ?? 'manual');
    if (state.date == date) {
      state = repo.getOrCreate(date);
    }

    final habitRepo = ref.read(habitRepoProvider);
    final allHabits = habitRepo.getHabits();
    for (final habit in allHabits.where((h) => h.type == HabitType.autoSleep)) {
      if (hours >= habit.target) {
        await habitRepo.setCompletion(date, habit.id, true);
      } else {
        await habitRepo.setCompletion(date, habit.id, false);
      }
    }
    if (state.date == date) {
      ref.invalidate(habitCompletionsProvider);
    }
  }

  Future<void> clearSleep() async {
    await clearSleepForDate(state.date);
  }

  Future<void> clearSleepForDate(String date) async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.clearSleep(date);
    if (state.date == date) {
      state = repo.getOrCreate(date);
    }

    final habitRepo = ref.read(habitRepoProvider);
    final allHabits = habitRepo.getHabits();
    for (final habit in allHabits.where((h) => h.type == HabitType.autoSleep)) {
      await habitRepo.setCompletion(date, habit.id, false);
    }
    if (state.date == date) {
      ref.invalidate(habitCompletionsProvider);
    }
  }

  Future<void> updateBodyFat(double bodyFat) async {
    await updateBodyFatForDate(state.date, bodyFat);
  }

  Future<void> updateBodyFatForDate(String date, double bodyFat) async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.updateBodyFat(date, bodyFat);
    if (state.date == date) {
      state = repo.getOrCreate(date);
    }
  }

  Future<void> clearBodyFatForDate(String date) async {
    final repo = ref.read(dailyLogRepoProvider);
    final current = repo.getOrCreate(date);
    await repo.saveLog(current.clearBodyFat());
    if (state.date == date) {
      state = repo.getOrCreate(date);
    }
  }

  Future<void> updateWater(int waterMl) async {
    await updateWaterForDate(state.date, waterMl);
  }

  Future<void> updateWaterForDate(String date, int waterMl) async {
    final repo = ref.read(dailyLogRepoProvider);
    final current = repo.getOrCreate(date);
    await repo.saveLog(current.copyWith(waterMl: waterMl));
    if (state.date == date) {
      state = repo.getOrCreate(date);
    }

    final habitRepo = ref.read(habitRepoProvider);
    final allHabits = habitRepo.getHabits();
    final waterHabit = allHabits.where((h) => h.id == 'water').firstOrNull;
    if (waterHabit != null) {
      double targetInMl = waterHabit.target.toDouble();
      if (waterHabit.unit.toLowerCase() == 'l' || waterHabit.unit.toLowerCase() == 'liters') {
        targetInMl *= 1000;
      }
      if (waterMl >= targetInMl) {
        await habitRepo.setCompletion(date, waterHabit.id, true);
      } else {
        await habitRepo.setCompletion(date, waterHabit.id, false);
      }
    }
    if (state.date == date) {
      ref.invalidate(habitCompletionsProvider);
    }
  }

  Future<void> clearWater() async {
    await clearWaterForDate(state.date);
  }

  Future<void> clearWaterForDate(String date) async {
    final repo = ref.read(dailyLogRepoProvider);
    final current = repo.getOrCreate(date);
    await repo.saveLog(current.clearWater());
    if (state.date == date) {
      state = repo.getOrCreate(date);
    }

    final habitRepo = ref.read(habitRepoProvider);
    final waterHabit = habitRepo.getHabits().where((h) => h.id == 'water').firstOrNull;
    if (waterHabit != null) {
      await habitRepo.setCompletion(date, waterHabit.id, false);
    }
    if (state.date == date) {
      ref.invalidate(habitCompletionsProvider);
    }
  }

  Future<void> markWorkoutCompleted(String dayId) async {
    final repo = ref.read(dailyLogRepoProvider);
    await repo.markWorkoutCompleted(state.date, dayId);
    state = repo.getOrCreate(state.date);

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
      ref.watch(dailyLogsUpdateProvider);
      final (start, end) = range;
      return ref.watch(dailyLogRepoProvider).getLogsInRange(start, end);
    });
