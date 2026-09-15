import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/coach_note.dart';
import '../models/daily_log.dart';
import '../models/daily_meal_log.dart';
import '../models/daily_stats_snapshot.dart';
import 'app_providers.dart';

import '../services/ai_client.dart';

class CoachNoteNotifier extends AsyncNotifier<CoachNote> {
  late String dateStr;
  int _currentRequestId = 0;
  bool _isFetching = false;
  CancellationToken? _cancellationToken;

  @override
  FutureOr<CoachNote> build() async {
    dateStr = ref.watch(dateStringProvider);
    ref.onDispose(() {
      _cancellationToken?.cancel();
    });
    return _loadForDate();
  }

  Future<CoachNote> _loadForDate() async {
    final repo = ref.read(coachNoteRepoProvider);
    final cached = repo.getNote(dateStr);

    if (cached != null) {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (dateStr == todayStr) {
        // Silently evaluate the 4-hour rule in the background
        // ignore: unawaited_futures
        fetchNote(background: true);
      }
      return cached;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (dateStr == todayStr) {
      // ignore: unawaited_futures
      fetchNote(); // Updates state asynchronously
      return CoachNote(date: dateStr, note: 'Generating...', isAi: true);
    }

    return CoachNote(
      date: dateStr,
      note: 'No coach note saved for this day yet.',
      isAi: false,
    );
  }

  Future<void> fetchNote({bool force = false, bool background = false}) async {
    if (_isFetching && !force) return;
    
    final int requestId = ++_currentRequestId;
    final targetDateStr = dateStr;

    final repo = ref.read(coachNoteRepoProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final lastGenStr = prefs.getString('coach_note_last_gen_$dateStr');
    final lastGen = lastGenStr != null ? DateTime.tryParse(lastGenStr) : null;

    bool shouldRegenerate = force;

    if (!force) {
      final cached = repo.getNote(dateStr);
      if (cached != null) {
        if (lastGen != null && DateTime.now().difference(lastGen).inHours < 4) {
          if (!background) state = AsyncValue.data(cached);
          return;
        } else {
          shouldRegenerate = true;
        }
      } else {
        shouldRegenerate = true;
      }
    }

    if (!shouldRegenerate) return;

    // A completely new generation has started for this request
    _cancellationToken?.cancel();
    _cancellationToken = CancellationToken();
    _isFetching = true;

    if (!background) state = const AsyncValue.loading();
    try {
      final coachService = ref.read(coachServiceProvider);
      final profile = ref.read(profileProvider);
      final dailyLog = ref.read(dailyLogProvider);
      final dailyLogRepo = ref.read(dailyLogRepoProvider);
      final habitRepo = ref.read(habitRepoProvider);

      final habits = ref.read(habitsProvider);
      final completions = ref.read(habitCompletionsProvider);
      final workoutPlan = ref.read(workoutPlanProvider);
      final logRepo = ref.read(exerciseLogRepoProvider);
      final mealPlan = ref.read(mealPlanProvider);
      final mealLog = ref.read(dailyMealLogProvider);

      final todayStats = DailyStatsSnapshot.compute(
        date: DateTime.parse(dateStr),
        dateStr: dateStr,
        habits: habits,
        habitCompletions: completions,
        dailyLog: dailyLog,
        workoutPlan: workoutPlan,
        hasLog: logRepo.hasLog,
        mealPlan: mealPlan,
        mealLog: mealLog,
        targetWeight: profile.targetWeight ?? 0.0,
        dailyLogRepo: dailyLogRepo,
        profile: profile,
      );

      final yesterday = DateTime.parse(
        dateStr,
      ).subtract(const Duration(days: 1));
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
      final yCompletions = habitRepo.getCompletions(yesterdayStr);
      final yLog =
          dailyLogRepo.getLog(yesterdayStr) ?? DailyLog(date: yesterdayStr);

      final yesterdayStats = DailyStatsSnapshot.compute(
        date: yesterday,
        dateStr: yesterdayStr,
        habits: habits,
        habitCompletions: yCompletions,
        dailyLog: yLog,
        workoutPlan: workoutPlan,
        hasLog: logRepo.hasLog,
        mealPlan: mealPlan,
        mealLog: DailyMealLog(date: yesterdayStr),
        targetWeight: profile.targetWeight ?? 0.0,
        dailyLogRepo: dailyLogRepo,
        profile: profile,
      );

      // We pass down to coach service. We don't assume isAi here.
      final stream = coachService.generateNoteStream(
        userName: profile.name,
        coachName: profile.coachName,
        steps: todayStats.steps,
        sleep: todayStats.sleepHours,
        habitsDone: todayStats.habitsDone,
        habitsTotal: todayStats.habitsTotal,
        calories: todayStats.totalCalories,
        workoutsDone: todayStats.workoutsDone,
        workoutsTotal: todayStats.workoutsTotal,
        yesterdayHabitRate: yesterdayStats.habitRate,
        weightTrend: todayStats.weightTrend,
        isRestDay: todayStats.isRestDay,
        daysSinceLastWorkout: todayStats.daysSinceLastWorkout,
        cancellationToken: _cancellationToken,
      );

      String accumulatedNote = "";
      bool resolvedIsAi = false;

      // Ensure we only save for the date we requested

      bool hasYielded = false;
      await for (final chunk in stream) {
        if (dateStr != targetDateStr) break;
        if (chunk.startsWith('__AI__')) {
           resolvedIsAi = true;
           continue;
        }
        if (chunk.startsWith('__LOCAL__')) {
           resolvedIsAi = false;
           accumulatedNote = "";
           continue;
        }
        accumulatedNote += chunk;
        if (!background) {
          hasYielded = true;
          state = AsyncValue.data(
            CoachNote(date: targetDateStr, note: accumulatedNote, isAi: resolvedIsAi),
          );
        }
      }

      if (_currentRequestId != requestId || dateStr != targetDateStr) return; // Stale request or navigated away

      if (accumulatedNote.isEmpty)
        throw Exception('Failed to generate note stream');

      final finalNote = CoachNote(
        date: targetDateStr,
        note: accumulatedNote,
        isAi: resolvedIsAi,
      );
      await repo.saveNote(finalNote);

      if (background || !hasYielded) {
        state = AsyncValue.data(finalNote);
      }

      final currentPrefs = ref.read(sharedPreferencesProvider);
      await currentPrefs.setString(
        'coach_note_last_gen_$targetDateStr',
        DateTime.now().toIso8601String(),
      );
    } catch (e, st) {
      if (_currentRequestId != requestId || dateStr != targetDateStr) return;
      if (!background || !state.hasValue || state.value?.note == 'Generating...') {
        // Fallback to cache on transient error
        final repo = ref.read(coachNoteRepoProvider);
        final cached = repo.getNote(targetDateStr);
        if (cached != null) {
          state = AsyncValue.data(cached);
        } else {
          state = AsyncValue.error(e, st);
        }
      }
    } finally {
      if (_currentRequestId == requestId) {
        _isFetching = false;
      }
    }
  }
}

final coachNoteProvider = AsyncNotifierProvider<CoachNoteNotifier, CoachNote>(
  () {
    return CoachNoteNotifier();
  },
);
