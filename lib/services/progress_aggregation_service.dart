import '../models/daily_log.dart';
import '../models/daily_meal_log.dart';
import '../screens/progress/progress_screen.dart'; // For MetricType and TimeRange

class ChartBucket {
  final DateTime startDate;
  final DateTime endDate;
  final double? average;
  final double? min;
  final double? max;
  final int validDaysCount;
  final int eligibleDaysCount;
  final bool isPartial;
  
  ChartBucket({
    required this.startDate,
    required this.endDate,
    this.average,
    this.min,
    this.max,
    required this.validDaysCount,
    required this.eligibleDaysCount,
    this.isPartial = false,
  });
}

class ProgressAggregationService {
  /// Aggregates daily logs into buckets depending on the TimeRange.
  static List<ChartBucket> aggregate({
    required List<DailyLog> logs,
    required List<DailyMealLog> mealLogs,
    required MetricType metric,
    required TimeRange range,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required double heightInMeters,
    required bool useKg,
  }) {
    if (range == TimeRange.weekly || range == TimeRange.oneMonth) {
      // Return daily buckets
      return _buildDailyBuckets(logs, mealLogs, metric, rangeStart, rangeEnd, heightInMeters, useKg);
    } else if (range == TimeRange.threeMonths || range == TimeRange.sixMonths) {
      // Return weekly buckets (Monday to Sunday)
      return _buildWeeklyBuckets(logs, mealLogs, metric, rangeStart, rangeEnd, heightInMeters, useKg);
    } else {
      // 12M: Return monthly buckets
      return _buildMonthlyBuckets(logs, mealLogs, metric, rangeStart, rangeEnd, heightInMeters, useKg);
    }
  }

  static double? _extractValue(DailyLog? log, DailyMealLog? mLog, MetricType metric, double heightInMeters, bool useKg) {
    switch (metric) {
      case MetricType.weight:
        if (log?.weight == null) return null;
        return useKg ? log!.weight! : log!.weight! * 2.20462;
      case MetricType.steps:
        return log?.steps?.toDouble();
      case MetricType.sleep:
        return log?.sleepHours;
      case MetricType.screenTime:
        if (log?.screenTimeMinutes != null) return log!.screenTimeMinutes! / 60.0;
        return null;
      case MetricType.bodyFat:
        return log?.bodyFat;
      case MetricType.bmi:
        if (log?.weight != null && heightInMeters > 0) {
          return log!.weight! / (heightInMeters * heightInMeters);
        }
        return null;
      case MetricType.calories:
        if (mLog != null && mLog.loggedSlotsCount > 0) return mLog.totalCalories.toDouble();
        return null;
      case MetricType.protein:
        if (mLog != null && mLog.loggedSlotsCount > 0) return mLog.totalProtein;
        return null;
    }
  }

  static List<ChartBucket> _buildDailyBuckets(
      List<DailyLog> logs, List<DailyMealLog> mealLogs, MetricType metric, DateTime start, DateTime end, double h, bool useKg) {
    
    final logsMap = {for (var l in logs) l.date: l};
    final mealMap = {for (var m in mealLogs) m.date: m};
    
    final buckets = <ChartBucket>[];
    
    // Iterate day by day
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    
    while (!current.isAfter(endDay)) {
      final dateStr = '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      final log = logsMap[dateStr];
      final mLog = mealMap[dateStr];
      
      final val = _extractValue(log, mLog, metric, h, useKg);
      
      buckets.add(ChartBucket(
        startDate: current,
        endDate: current,
        average: val,
        min: val,
        max: val,
        validDaysCount: val != null ? 1 : 0,
        eligibleDaysCount: 1, // Only 1 day in a daily bucket
        isPartial: false,
      ));
      
      current = current.add(const Duration(days: 1));
    }
    
    return buckets;
  }

  static List<ChartBucket> _buildWeeklyBuckets(
      List<DailyLog> logs, List<DailyMealLog> mealLogs, MetricType metric, DateTime start, DateTime end, double h, bool useKg) {
    
    final logsMap = {for (var l in logs) l.date: l};
    final mealMap = {for (var m in mealLogs) m.date: m};
    
    final buckets = <ChartBucket>[];
    
    // Find first Monday on or before start
    DateTime current = DateTime(start.year, start.month, start.day);
    while (current.weekday != DateTime.monday) {
      current = current.subtract(const Duration(days: 1));
    }
    
    final endDay = DateTime(end.year, end.month, end.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    while (!current.isAfter(endDay)) {
      DateTime weekStart = current;
      DateTime weekEnd = current.add(const Duration(days: 6));
      
      // Clip boundaries to the requested range
      DateTime effectiveStart = weekStart.isBefore(start) ? DateTime(start.year, start.month, start.day) : weekStart;
      DateTime effectiveEnd = weekEnd.isAfter(endDay) ? endDay : weekEnd;
      
      List<double> values = [];
      int eligibleDays = 0;
      
      for (int i = 0; i <= effectiveEnd.difference(effectiveStart).inDays; i++) {
        final d = effectiveStart.add(Duration(days: i));
        if (d.isAfter(today)) continue; // Exclude future days
        
        eligibleDays++;
        final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final val = _extractValue(logsMap[dateStr], mealMap[dateStr], metric, h, useKg);
        if (val != null) {
          values.add(val);
        }
      }
      
      double? avg;
      double? minVal;
      double? maxVal;
      if (values.isNotEmpty) {
        avg = values.reduce((a, b) => a + b) / values.length;
        minVal = values.reduce((a, b) => a < b ? a : b);
        maxVal = values.reduce((a, b) => a > b ? a : b);
      }
      
      bool isPartial = weekEnd.isAfter(today) || weekStart.isBefore(start) || weekEnd.isAfter(endDay);
      
      buckets.add(ChartBucket(
        startDate: effectiveStart,
        endDate: effectiveEnd,
        average: avg,
        min: minVal,
        max: maxVal,
        validDaysCount: values.length,
        eligibleDaysCount: eligibleDays,
        isPartial: isPartial,
      ));
      
      current = current.add(const Duration(days: 7));
    }
    
    return buckets;
  }

  static List<ChartBucket> _buildMonthlyBuckets(
      List<DailyLog> logs, List<DailyMealLog> mealLogs, MetricType metric, DateTime start, DateTime end, double h, bool useKg) {
    
    final logsMap = {for (var l in logs) l.date: l};
    final mealMap = {for (var m in mealLogs) m.date: m};
    
    final buckets = <ChartBucket>[];
    
    DateTime currentMonthStart = DateTime(start.year, start.month, 1);
    final endDay = DateTime(end.year, end.month, end.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    while (!currentMonthStart.isAfter(endDay)) {
      // Find end of month
      int nextMonth = currentMonthStart.month + 1;
      int nextYear = currentMonthStart.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      DateTime monthEnd = DateTime(nextYear, nextMonth, 1).subtract(const Duration(days: 1));
      
      DateTime effectiveStart = currentMonthStart.isBefore(start) ? DateTime(start.year, start.month, start.day) : currentMonthStart;
      DateTime effectiveEnd = monthEnd.isAfter(endDay) ? endDay : monthEnd;
      
      List<double> values = [];
      int eligibleDays = 0;
      
      for (int i = 0; i <= effectiveEnd.difference(effectiveStart).inDays; i++) {
        final d = effectiveStart.add(Duration(days: i));
        if (d.isAfter(today)) continue;
        
        eligibleDays++;
        final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final val = _extractValue(logsMap[dateStr], mealMap[dateStr], metric, h, useKg);
        if (val != null) {
          values.add(val);
        }
      }
      
      double? avg;
      double? minVal;
      double? maxVal;
      if (values.isNotEmpty) {
        avg = values.reduce((a, b) => a + b) / values.length;
        minVal = values.reduce((a, b) => a < b ? a : b);
        maxVal = values.reduce((a, b) => a > b ? a : b);
      }
      
      bool isPartial = monthEnd.isAfter(today) || currentMonthStart.isBefore(start) || monthEnd.isAfter(endDay);
      
      buckets.add(ChartBucket(
        startDate: effectiveStart,
        endDate: effectiveEnd,
        average: avg,
        min: minVal,
        max: maxVal,
        validDaysCount: values.length,
        eligibleDaysCount: eligibleDays,
        isPartial: isPartial,
      ));
      
      currentMonthStart = DateTime(nextYear, nextMonth, 1);
    }
    
    return buckets;
  }
}
