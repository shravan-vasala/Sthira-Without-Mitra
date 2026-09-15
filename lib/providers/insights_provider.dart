import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../models/insight.dart';
import '../models/daily_meal_log.dart';
import 'app_providers.dart';
import '../utils/time_utils.dart';

final insightsProvider = Provider<List<Insight>>((ref) {
  final dailyLogRepo = ref.watch(dailyLogRepoProvider);
  final mealRepo = ref.watch(mealRepoProvider);
  final logs = dailyLogRepo.getAllLogs();

  final insights = <Insight>[];
  final now = DateTime.now();

  // 0. Meal Appreciation Insight
  final thirtyDaysAgoStr = todayKey(now.subtract(const Duration(days: 30)));
  final todayStr = todayKey(now);
  final mealLogs = mealRepo.getLogsInRange(thirtyDaysAgoStr, todayStr);
  
  if (mealLogs.isNotEmpty) {
    mealLogs.sort((a,b) => b.date.compareTo(a.date));
    final recentMealLog = mealLogs.first;
    
    final allItems = recentMealLog.customSlots.values.expand((slot) => slot.items).toList();
    if (allItems.isNotEmpty) {
      MealItemLog? topProteinItem;
      for (final item in allItems) {
        if ((item.computedNutrition?.proteinG ?? 0) > (topProteinItem?.computedNutrition?.proteinG ?? 0)) {
          topProteinItem = item;
        }
      }

      String foodName = 'your recent meals';
      if (topProteinItem != null && topProteinItem.name != null && topProteinItem.name!.trim().isNotEmpty && topProteinItem.name!.toLowerCase() != 'unknown') {
        foodName = topProteinItem.name!.trim();
      }

      final double totalP = recentMealLog.totalProtein;
      final double totalC = recentMealLog.totalCarbs;

      String description = 'Incorporating ${foodName.toLowerCase()} provides an excellent nutritional foundation. ';
      
      if (totalP < 40) {
        description += 'To elevate this, consider introducing an additional lean protein source to ensure steady recovery and sustained energy.';
      } else if (totalC > totalP * 3 && totalC > 150) {
        description += 'Your energy intake is robust. Pairing it with a proportional increase in protein will anchor your baseline energy levels.';
      } else {
        description += 'Your macronutrient balance is impeccably structured. Maintaining this rhythm will yield steady, long-term results.';
      }

      insights.add(
        Insight(
          id: 'nutrition_analysis',
          type: InsightType.trend,
          title: 'Mindful Nutrient Balance',
          description: description,
          severity: InsightSeverity.positive,
          dateGenerated: now,
          icon: Icons.restaurant_rounded,
        )
      );
    } else if (mealLogs.length >= 3) {
      insights.add(
        Insight(
          id: 'nutrition_consistency',
          type: InsightType.trend,
          title: 'Consistent Awareness',
          description: 'Your daily logging builds a strong foundation. Mindful awareness of your intake is the cornerstone of steady, sustainable progress.',
          severity: InsightSeverity.positive,
          dateGenerated: now,
          icon: Icons.check_circle_outline_rounded,
        )
      );
    }
  }

  if (logs.isEmpty) return insights;

  logs.sort((a, b) => b.date.compareTo(a.date)); // Newest first

  // 1. Step Trend Insight
  int highStepDays = 0;
  for (var i = 0; i < (logs.length > 7 ? 7 : logs.length); i++) {
    if ((logs[i].steps ?? 0) >= 10000) highStepDays++;
  }

  if (highStepDays >= 5) {
    insights.add(
      Insight(
        id: 'trend_steps_high',
        type: InsightType.trend,
        title: 'Amazing Step Consistency',
        description:
            'You hit 10k+ steps in $highStepDays of the last 7 days. Your metabolism is firing on all cylinders!',
        severity: InsightSeverity.positive,
        dateGenerated: now,
        icon: Icons.directions_run_rounded,
      ),
    );
  } else if (highStepDays == 0 && logs.length >= 7) {
    insights.add(
      Insight(
        id: 'trend_steps_low',
        type: InsightType.trend,
        title: 'Time to Move',
        description:
            "You haven't hit 10k steps recently. Adding a 20-minute daily walk can drastically improve your cardiovascular health.",
        severity: InsightSeverity.warning,
        dateGenerated: now,
        icon: Icons.directions_walk_rounded,
      ),
    );
  }

  // 2. Sleep vs Steps Correlation (Real 30-day computation)
  final recentLogs = logs
      .where((l) => l.date.compareTo(thirtyDaysAgoStr) >= 0)
      .toList();

  if (recentLogs.length >= 10) {
    final goodSleepDays = recentLogs
        .where((l) => (l.sleepHours ?? 0) >= 7.5 && (l.steps ?? 0) > 0)
        .toList();
    final badSleepDays = recentLogs
        .where(
          (l) =>
              (l.sleepHours ?? 0) > 0 &&
              (l.sleepHours ?? 0) < 7.5 &&
              (l.steps ?? 0) > 0,
        )
        .toList();

    if (goodSleepDays.isNotEmpty && badSleepDays.isNotEmpty) {
      final avgStepsGood =
          goodSleepDays.fold(0.0, (sum, l) => sum + (l.steps ?? 0)) /
          goodSleepDays.length;
      final avgStepsBad =
          badSleepDays.fold(0.0, (sum, l) => sum + (l.steps ?? 0)) /
          badSleepDays.length;

      if (avgStepsGood > avgStepsBad &&
          ((avgStepsGood - avgStepsBad) / avgStepsBad) >= 0.15) {
        final diff = (avgStepsGood - avgStepsBad).round();
        insights.add(
          Insight(
            id: 'corr_sleep_steps',
            type: InsightType.correlation,
            title: 'Sleep Powers Your Movement',
            description:
                'Over the last 30 days, when you get 7.5h+ sleep, you walk on average  more steps. Sleep is truly your superpower!',
            severity: InsightSeverity.positive,
            dateGenerated: now,
            icon: Icons.bedtime_rounded,
          ),
        );
      }
    }
  }

  return insights;
});
