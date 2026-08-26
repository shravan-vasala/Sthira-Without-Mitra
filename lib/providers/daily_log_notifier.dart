import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_log.dart';
import '../models/habit.dart';
import '../repositories/daily_log_repository.dart';
import '../services/health_connect_service.dart';
import 'app_providers.dart';

class DailyLogNotifier extends StateNotifier<DailyLog> {
  final DailyLogRepository _repo;
  final Ref _ref;
  StreamSubscription? _sub;

  DailyLogNotifier(this._repo, String date, this._ref) : super(_repo.getOrCreate(date)) {
    _sub = _repo.watchLog(date).listen((log) {
      if (mounted) {
        state = log ?? _repo.getOrCreate(date);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> updateWeight(double weight) async {
    await _repo.updateWeight(state.date, weight);
    state = _repo.getOrCreate(state.date);
  }

  Future<void> updateSteps(int steps, {String? source}) async {
    await _repo.updateSteps(state.date, steps, source: source ?? 'manual');
    state = _repo.getOrCreate(state.date);
    _ref.read(stepsSourceProvider.notifier).state = 
        (source == 'healthConnect') ? StepsSource.healthConnect : StepsSource.manual;
  }

  Future<void> updateSleep(double hours, {String? source}) async {
    await _repo.updateSleep(state.date, hours, source: source ?? 'manual');
    state = _repo.getOrCreate(state.date);

    final habitRepo = _ref.read(habitRepoProvider);
    final allHabits = habitRepo.getHabits();
    for (final habit in allHabits.where((h) => h.type == HabitType.autoSleep)) {
      if (hours >= habit.target) {
        await habitRepo.setCompletion(state.date, habit.id, true);
      } else {
        await habitRepo.setCompletion(state.date, habit.id, false);
      }
    }
    _ref.invalidate(habitCompletionsProvider);
  }

  Future<void> clearSleep() async {
    await _repo.clearSleep(state.date);
    state = _repo.getOrCreate(state.date);
    
    final habitRepo = _ref.read(habitRepoProvider);
    final allHabits = habitRepo.getHabits();
    for (final habit in allHabits.where((h) => h.type == HabitType.autoSleep)) {
      await habitRepo.setCompletion(state.date, habit.id, false);
    }
    _ref.invalidate(habitCompletionsProvider);
  }

  Future<void> updateBodyFat(double bodyFat) async {
    await _repo.updateBodyFat(state.date, bodyFat);
    state = _repo.getOrCreate(state.date);
  }

  Future<void> updateWater(int waterMl) async {
    final current = state;
    await _repo.saveLog(current.copyWith(waterMl: waterMl));
    state = _repo.getOrCreate(state.date);
  }

  Future<void> clearWater() async {
    final current = state;
    await _repo.saveLog(current.copyWith(waterMl: 0));
    state = _repo.getOrCreate(state.date);
  }

  Future<void> markWorkoutCompleted(String dayId) async {
    await _repo.markWorkoutCompleted(state.date, dayId);
    state = _repo.getOrCreate(state.date);

    final profile = _ref.read(profileProvider);
    if (profile.planStartDate == null) {
      final now = DateTime.now();
      _ref.read(profileProvider.notifier).updateProfile(profile.copyWith(
        planStartDate: DateTime(now.year, now.month, now.day),
        currentPhaseWeek: 1,
      ));
    }
  }
}

final dailyLogProvider =
    StateNotifierProvider<DailyLogNotifier, DailyLog>((ref) {
  final repo = ref.watch(dailyLogRepoProvider);
  final date = ref.watch(dateStringProvider);
  return DailyLogNotifier(repo, date, ref);
});

final dailyLogsRangeProvider =
    Provider.family<List<DailyLog>, (String, String)>((ref, range) {
  final (start, end) = range;
  return ref.watch(dailyLogRepoProvider).getLogsInRange(start, end);
});
