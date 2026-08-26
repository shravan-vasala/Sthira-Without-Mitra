import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/coach_note.dart';
import '../models/daily_log.dart';
import '../models/daily_meal_log.dart';
import '../models/habit.dart';
import '../models/daily_stats_snapshot.dart';
import 'app_providers.dart';

class CoachNoteNotifier extends StateNotifier<AsyncValue<CoachNote>> {
  final Ref _ref;
  final String dateStr;

  CoachNoteNotifier(this._ref, this.dateStr) : super(const AsyncValue.loading()) {
    _loadForDate();
  }

  Future<void> _loadForDate() async {
    final repo = _ref.read(coachNoteRepoProvider);
    final cached = repo.getNote(dateStr);
    
    if (cached != null) {
      if (mounted) state = AsyncValue.data(cached);
      
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (dateStr == todayStr) {
        // Silently evaluate the 4-hour rule in the background
        await fetchNote(background: true);
      }
      return;
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (dateStr == todayStr) {
      await fetchNote();
      return;
    }

    if (mounted) {
      state = AsyncValue.data(CoachNote(
        date: dateStr,
        note: 'No coach note saved for this day yet.',
        isAi: false,
      ));
    }
  }

  Future<void> fetchNote({bool force = false, bool background = false}) async {
    final repo = _ref.read(coachNoteRepoProvider);
    final prefs = _ref.read(sharedPreferencesProvider);
    final lastGenStr = prefs.getString('coach_note_last_gen_$dateStr');
    final lastGen = lastGenStr != null ? DateTime.tryParse(lastGenStr) : null;
    
    bool shouldRegenerate = force;

    if (!force) {
      final cached = repo.getNote(dateStr);
      if (cached != null) {
        if (lastGen != null && DateTime.now().difference(lastGen).inHours < 4) {
          if (mounted && !background) state = AsyncValue.data(cached);
          return;
        } else {
          shouldRegenerate = true;
        }
      } else {
        shouldRegenerate = true;
      }
    }

    if (!shouldRegenerate) return;
    
    if (!background) state = const AsyncValue.loading();
    try {
      final coachService = _ref.read(coachServiceProvider);
      final profile = _ref.read(profileProvider);
      final dailyLog = _ref.read(dailyLogProvider);
      final dailyLogRepo = _ref.read(dailyLogRepoProvider);
      final habitRepo = _ref.read(habitRepoProvider);

      final habits = _ref.read(habitsProvider);
      final completions = _ref.read(habitCompletionsProvider);
      final workoutPlan = _ref.read(workoutPlanProvider);
      final logRepo = _ref.read(exerciseLogRepoProvider);
      final mealPlan = _ref.read(mealPlanProvider);
      final mealLog = _ref.read(dailyMealLogProvider);
      
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
      );

      final yesterday = DateTime.parse(dateStr).subtract(const Duration(days: 1));
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
      final yCompletions = habitRepo.getCompletions(yesterdayStr);
      final yLog = dailyLogRepo.getLog(yesterdayStr) ?? DailyLog(date: yesterdayStr);
      
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
      );

      final isAi = coachService.apiKey != null && coachService.apiKey!.isNotEmpty;
      
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
      );
      
      String accumulatedNote = "";
      
      await for (final chunk in stream) {
        accumulatedNote += chunk;
        if (mounted) {
          state = AsyncValue.data(CoachNote(
            date: dateStr,
            note: accumulatedNote,
            isAi: isAi,
          ));
        }
      }
      
      if (accumulatedNote.isEmpty) throw Exception('Failed to generate note stream');

      final finalNote = CoachNote(date: dateStr, note: accumulatedNote, isAi: isAi);
      await repo.saveNote(finalNote);
      
      final prefs = _ref.read(sharedPreferencesProvider);
      await prefs.setString('coach_note_last_gen_$dateStr', DateTime.now().toIso8601String());
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

final coachNoteProvider =
    StateNotifierProvider<CoachNoteNotifier, AsyncValue<CoachNote>>((ref) {
  final dateStr = ref.watch(dateStringProvider);
  return CoachNoteNotifier(ref, dateStr);
});
