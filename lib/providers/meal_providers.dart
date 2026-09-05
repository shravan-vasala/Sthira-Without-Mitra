import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';
import '../models/meal_plan.dart';
import '../models/daily_meal_log.dart';
import '../services/widget_update_service.dart';

final mealPlanProvider = Provider<MealPlan?>((ref) {
  final repo = ref.watch(mealRepoProvider);
  final profile = ref.watch(profileProvider);

  final activePlanId = profile.activeMealPlan ?? 'Daily Nutrition Plan';
  return repo.getMealPlan(activePlanId);
});

class DailyMealLogNotifier extends Notifier<DailyMealLog> {
  @override
  DailyMealLog build() {
    final repo = ref.watch(mealRepoProvider);
    final date = ref.watch(dateStringProvider);

    final sub = repo.watchDailyLog(date).listen((log) {
      state = log ?? repo.getDailyLog(date);
    });

    ref.onDispose(() => sub.cancel());

    return repo.getDailyLog(date);
  }

  Future<void> saveMealSlot(String slotName, MealSlotLog slotLog) async {
    final repo = ref.read(mealRepoProvider);
    final date = ref.read(dateStringProvider);
    await repo.saveMealSlot(date, slotName, slotLog);
    state = repo.getDailyLog(date);
    WidgetUpdateService.pushWidgetState(ref);
  }

  Future<void> clearMealSlot(String slotName) async {
    final repo = ref.read(mealRepoProvider);
    final date = ref.read(dateStringProvider);
    await repo.clearMealSlot(date, slotName);
    state = repo.getDailyLog(date);
    WidgetUpdateService.pushWidgetState(ref);
  }
}

final dailyMealLogProvider =
    NotifierProvider<DailyMealLogNotifier, DailyMealLog>(
      DailyMealLogNotifier.new,
    );

final dailyMealLogsRangeProvider =
    Provider.family<List<DailyMealLog>, (String, String)>((ref, range) {
      final (start, end) = range;
      final mealRepo = ref.watch(mealRepoProvider);
      return mealRepo.getLogsInRange(start, end);
    });
