import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/insight.dart';
import 'app_providers.dart';
import '../models/daily_log.dart';

final insightsProvider = Provider<List<Insight>>((ref) {
  final dailyLogRepo = ref.watch(dailyLogRepoProvider);
  final logs = dailyLogRepo.getAllLogs();
  
  if (logs.isEmpty) return [];

  logs.sort((a, b) => b.date.compareTo(a.date)); // Newest first

  final insights = <Insight>[];
  final now = DateTime.now();

  // 1. Step Trend Insight
  int highStepDays = 0;
  for (var i = 0; i < (logs.length > 7 ? 7 : logs.length); i++) {
    if ((logs[i].steps ?? 0) >= 10000) highStepDays++;
  }
  
  if (highStepDays >= 5) {
    insights.add(Insight(
      id: 'trend_steps_high',
      type: InsightType.trend,
      title: 'Amazing Step Consistency',
      description: 'You hit 10k+ steps in $highStepDays of the last 7 days. Your metabolism is firing on all cylinders!',
      severity: InsightSeverity.positive,
      dateGenerated: now,
      icon: Icons.directions_run_rounded,
    ));
  } else if (highStepDays == 0 && logs.length >= 7) {
    insights.add(Insight(
      id: 'trend_steps_low',
      type: InsightType.trend,
      title: 'Time to Move',
      description: "You haven't hit 10k steps recently. Adding a 20-minute daily walk can drastically improve your cardiovascular health.",
      severity: InsightSeverity.warning,
      dateGenerated: now,
      icon: Icons.directions_walk_rounded,
    ));
  }

  // 2. Sleep vs Steps Correlation (fictional heuristic for demo)
  if (logs.length >= 5) {
    final goodSleepDays = logs.where((l) => (l.sleepHours ?? 0) >= 7.5).toList();
    if (goodSleepDays.isNotEmpty && goodSleepDays.length >= 3) {
      double avgStepsGoodSleep = goodSleepDays.fold(0.0, (sum, l) => sum + (l.steps ?? 0)) / goodSleepDays.length;
      
      final badSleepDays = logs.where((l) => (l.sleepHours ?? 0) > 0 && (l.sleepHours ?? 0) < 6.5).toList();
      if (badSleepDays.isNotEmpty) {
        double avgStepsBadSleep = badSleepDays.fold(0.0, (sum, l) => sum + (l.steps ?? 0)) / badSleepDays.length;
        
        if (avgStepsGoodSleep > avgStepsBadSleep + 2000) {
          insights.add(Insight(
            id: 'corr_sleep_steps',
            type: InsightType.correlation,
            title: 'Sleep Powers Your Movement',
            description: 'On days you get 7.5hr+ sleep, you walk on average 2,000 more steps. Sleep is truly your superpower!',
            severity: InsightSeverity.positive,
            dateGenerated: now,
            icon: Icons.bedtime_rounded,
          ));
        }
      }
    }
  }
  
  return insights;
});
