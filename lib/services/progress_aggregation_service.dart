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
    required DateTime today,
    required double heightInMeters,
    required bool useKg,
  }) {
    if (range == TimeRange.weekly || range == TimeRange.oneMonth) {
      return _buildDailyBuckets(
        logs,
        mealLogs,
        metric,
        rangeStart,
        rangeEnd,
        today,
        heightInMeters,
        useKg,
      );
    } else if (range == TimeRange.threeMonths || range == TimeRange.sixMonths) {
      return _buildWeeklyBuckets(
        logs,
        mealLogs,
        metric,
        rangeStart,
        rangeEnd,
        today,
        heightInMeters,
        useKg,
      );
    } else {
      return _buildMonthlyBuckets(
        logs,
        mealLogs,
        metric,
        rangeStart,
        rangeEnd,
        today,
        heightInMeters,
        useKg,
      );
    }
  }

  static double? _extractValue(
    DailyLog? log,
    DailyMealLog? mLog,
    MetricType metric,
    double heightInMeters,
    bool useKg,
  ) {
    double? val;
    switch (metric) {
      case MetricType.weight:
        if (log?.weight != null)
          val = useKg ? log!.weight! : log!.weight! * 2.20462;
        break;
      case MetricType.steps:
        val = log?.steps?.toDouble();
        break;
      case MetricType.sleep:
        val = log?.sleepHours;
        break;
      case MetricType.screenTime:
        if (log?.screenTimeMinutes != null)
          val = log!.screenTimeMinutes! / 60.0;
        break;
      case MetricType.bodyFat:
        val = log?.bodyFat;
        break;
      case MetricType.bmi:
        if (log?.weight != null && heightInMeters > 0) {
          val = log!.weight! / (heightInMeters * heightInMeters);
        }
        break;
      case MetricType.calories:
        if (mLog != null && mLog.loggedSlotsCount > 0)
          val = mLog.totalCalories.toDouble();
        break;
      case MetricType.protein:
        if (mLog != null && mLog.loggedSlotsCount > 0) val = mLog.totalProtein;
        break;
    }
    if (val != null && (!val.isFinite || val < 0)) return null;
    return val;
  }

  static List<ChartBucket> _buildDailyBuckets(
    List<DailyLog> logs,
    List<DailyMealLog> mealLogs,
    MetricType metric,
    DateTime start,
    DateTime end,
    DateTime today,
    double h,
    bool useKg,
  ) {
    final logsMap = {for (var l in logs) l.date: l};
    final mealMap = {for (var m in mealLogs) m.date: m};

    final buckets = <ChartBucket>[];

    // Iterate day by day
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDay)) {
      final dateStr =
          '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      final log = logsMap[dateStr];
      final mLog = mealMap[dateStr];

      final val = _extractValue(log, mLog, metric, h, useKg);

      buckets.add(
        ChartBucket(
          startDate: current,
          endDate: current,
          average: val,
          min: val,
          max: val,
          validDaysCount: val != null ? 1 : 0,
          eligibleDaysCount: 1, // Only 1 day in a daily bucket
          isPartial: false,
        ),
      );

      current = DateTime(current.year, current.month, current.day + 1);
    }

    return buckets;
  }

  static List<ChartBucket> _buildWeeklyBuckets(
    List<DailyLog> logs,
    List<DailyMealLog> mealLogs,
    MetricType metric,
    DateTime start,
    DateTime end,
    DateTime today,
    double h,
    bool useKg,
  ) {
    final logsMap = {for (var l in logs) l.date: l};
    final mealMap = {for (var m in mealLogs) m.date: m};

    final buckets = <ChartBucket>[];

    // Find first Monday on or before start
    DateTime current = DateTime(start.year, start.month, start.day);
    while (current.weekday != DateTime.monday) {
      current = current.subtract(const Duration(days: 1));
    }

    final endDay = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDay)) {
      final DateTime weekStart = current;
      final DateTime weekEnd = DateTime(
        current.year,
        current.month,
        current.day + 6,
      );

      // Clip boundaries to the requested range
      final DateTime effectiveStart = weekStart.isBefore(start)
          ? DateTime(start.year, start.month, start.day)
          : weekStart;
      final DateTime effectiveEnd = weekEnd.isAfter(endDay) ? endDay : weekEnd;

      final List<double> values = [];
      int eligibleDays = 0;

      DateTime d = DateTime(
        effectiveStart.year,
        effectiveStart.month,
        effectiveStart.day,
      );
      while (!d.isAfter(effectiveEnd)) {
        if (!d.isAfter(today)) {
          eligibleDays++;
          final dateStr =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          final val = _extractValue(
            logsMap[dateStr],
            mealMap[dateStr],
            metric,
            h,
            useKg,
          );
          if (val != null) {
            values.add(val);
          }
        }
        d = DateTime(d.year, d.month, d.day + 1);
      }

      double? avg;
      double? minVal;
      double? maxVal;
      if (values.isNotEmpty) {
        avg = values.reduce((a, b) => a + b) / values.length;
        minVal = values.reduce((a, b) => a < b ? a : b);
        maxVal = values.reduce((a, b) => a > b ? a : b);
      }

      final bool isPartial =
          weekEnd.isAfter(today) ||
          weekStart.isBefore(start) ||
          weekEnd.isAfter(endDay);

      buckets.add(
        ChartBucket(
          startDate: effectiveStart,
          endDate: effectiveEnd,
          average: avg,
          min: minVal,
          max: maxVal,
          validDaysCount: values.length,
          eligibleDaysCount: eligibleDays,
          isPartial: isPartial,
        ),
      );

      current = DateTime(current.year, current.month, current.day + 7);
    }

    return buckets;
  }

  static List<ChartBucket> _buildMonthlyBuckets(
    List<DailyLog> logs,
    List<DailyMealLog> mealLogs,
    MetricType metric,
    DateTime start,
    DateTime end,
    DateTime today,
    double h,
    bool useKg,
  ) {
    final logsMap = {for (var l in logs) l.date: l};
    final mealMap = {for (var m in mealLogs) m.date: m};

    final buckets = <ChartBucket>[];

    DateTime currentMonthStart = DateTime(start.year, start.month, 1);
    final endDay = DateTime(end.year, end.month, end.day);

    while (!currentMonthStart.isAfter(endDay)) {
      // Find end of month
      int nextMonth = currentMonthStart.month + 1;
      int nextYear = currentMonthStart.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      final DateTime monthEnd = DateTime(
        nextYear,
        nextMonth,
        0,
      ); // 0th day is last day of previous month

      final DateTime effectiveStart = currentMonthStart.isBefore(start)
          ? DateTime(start.year, start.month, start.day)
          : currentMonthStart;
      final DateTime effectiveEnd = monthEnd.isAfter(endDay)
          ? endDay
          : monthEnd;

      final List<double> values = [];
      int eligibleDays = 0;

      DateTime d = DateTime(
        effectiveStart.year,
        effectiveStart.month,
        effectiveStart.day,
      );
      while (!d.isAfter(effectiveEnd)) {
        if (!d.isAfter(today)) {
          eligibleDays++;
          final dateStr =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          final val = _extractValue(
            logsMap[dateStr],
            mealMap[dateStr],
            metric,
            h,
            useKg,
          );
          if (val != null) {
            values.add(val);
          }
        }
        d = DateTime(d.year, d.month, d.day + 1);
      }

      double? avg;
      double? minVal;
      double? maxVal;
      if (values.isNotEmpty) {
        avg = values.reduce((a, b) => a + b) / values.length;
        minVal = values.reduce((a, b) => a < b ? a : b);
        maxVal = values.reduce((a, b) => a > b ? a : b);
      }

      final bool isPartial =
          monthEnd.isAfter(today) ||
          currentMonthStart.isBefore(start) ||
          monthEnd.isAfter(endDay);

      buckets.add(
        ChartBucket(
          startDate: effectiveStart,
          endDate: effectiveEnd,
          average: avg,
          min: minVal,
          max: maxVal,
          validDaysCount: values.length,
          eligibleDaysCount: eligibleDays,
          isPartial: isPartial,
        ),
      );

      currentMonthStart = DateTime(nextYear, nextMonth, 1);
    }

    return buckets;
  }
}
