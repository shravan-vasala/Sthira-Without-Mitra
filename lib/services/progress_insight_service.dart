import 'package:intl/intl.dart';
import '../screens/progress/progress_screen.dart';
import 'progress_aggregation_service.dart';

class MetricInsight {
  final double? heroValue;
  final String heroLabel;
  final String? insightText;

  MetricInsight({
    this.heroValue,
    required this.heroLabel,
    this.insightText,
  });
}

class ProgressInsightService {
  static bool _isTrendMetric(MetricType metric) {
    return metric == MetricType.weight ||
        metric == MetricType.bodyFat ||
        metric == MetricType.bmi;
  }

  static bool _downIsGood(MetricType metric) {
    return metric == MetricType.weight ||
        metric == MetricType.bodyFat ||
        metric == MetricType.bmi ||
        metric == MetricType.screenTime;
  }

  static String _formatValue(double value, MetricType metric, bool useKg) {
    if (metric == MetricType.steps || metric == MetricType.calories || metric == MetricType.protein) {
      return NumberFormat('#,###').format(value.toInt());
    }
    return value.toStringAsFixed(1);
  }

  static String _unit(MetricType metric, bool useKg) {
    switch (metric) {
      case MetricType.weight:
        return useKg ? 'kg' : 'lb';
      case MetricType.steps:
        return 'steps';
      case MetricType.sleep:
        return 'hrs';
      case MetricType.bodyFat:
        return '%';
      case MetricType.calories:
        return 'kcal';
      case MetricType.protein:
        return 'g';
      case MetricType.screenTime:
        return 'hrs';
      case MetricType.bmi:
        return '';
    }
  }

  static MetricInsight buildInsight({
    required MetricType metric,
    required TimeRange range,
    required List<ChartBucket> currentBuckets,
    required List<ChartBucket> previousBuckets,
    required bool useKg,
    double? targetValue,
  }) {
    final validCurrent = currentBuckets.where((b) => b.average != null).toList();
    final validPrevious = previousBuckets.where((b) => b.average != null).toList();

    // 1. Calculate Hero Stats
    double? currentSummary;
    double? previousSummary;

    final isTrend = _isTrendMetric(metric);

    if (isTrend) {
      // Trend metrics (weight, bodyFat) show the latest valid value
      if (validCurrent.isNotEmpty) {
        currentSummary = validCurrent.last.average;
      }
      if (validPrevious.isNotEmpty) {
        previousSummary = validPrevious.last.average;
      }
    } else {
      // Count metrics (steps, sleep, calories) show the average over the period
      if (validCurrent.isNotEmpty) {
        double sum = 0;
        int days = 0;
        for (final b in validCurrent) {
          sum += b.average! * b.validDaysCount;
          days += b.validDaysCount;
        }
        currentSummary = days > 0 ? sum / days : null;
      }
      if (validPrevious.isNotEmpty) {
        double sum = 0;
        int days = 0;
        for (final b in validPrevious) {
          sum += b.average! * b.validDaysCount;
          days += b.validDaysCount;
        }
        previousSummary = days > 0 ? sum / days : null;
      }
    }

    final unitLabel = _unit(metric, useKg);
    final heroLabel = isTrend
        ? (unitLabel.isEmpty ? 'latest' : 'latest $unitLabel')
        : (unitLabel.isEmpty ? 'avg / day' : 'avg $unitLabel / day');

    // 2. Data Thresholding
    int totalValidDays = validCurrent.fold(0, (sum, b) => sum + b.validDaysCount);
    bool isSparse = false;
    if (range == TimeRange.weekly && totalValidDays < 3) isSparse = true;
    if (range != TimeRange.weekly && totalValidDays < 7) isSparse = true;

    if (isSparse || currentSummary == null) {
      return MetricInsight(
        heroValue: currentSummary,
        heroLabel: heroLabel,
        insightText: null,
      );
    }

    // 3. Compute Delta
    String? insightSentence;
    final currentFmt = _formatValue(currentSummary, metric, useKg);

    final String periodLabel;
    final String prevPeriodLabel;
    switch (range) {
      case TimeRange.weekly:
        periodLabel = 'this week';
        prevPeriodLabel = 'last week';
        break;
      case TimeRange.oneMonth:
        periodLabel = 'this month';
        prevPeriodLabel = 'last month';
        break;
      case TimeRange.threeMonths:
        periodLabel = 'this quarter';
        prevPeriodLabel = 'last quarter';
        break;
      case TimeRange.sixMonths:
        periodLabel = 'these 6 months';
        prevPeriodLabel = 'the previous 6 months';
        break;
      case TimeRange.twelveMonths:
        periodLabel = 'this year';
        prevPeriodLabel = 'last year';
        break;
    }

    // Try Goal Tracking (Priority 1)
    if (targetValue != null && !isTrend && (range == TimeRange.weekly || range == TimeRange.oneMonth)) {
      int hitDays = 0;
      for (final b in validCurrent) {
        if (b.average != null && b.average! >= targetValue) {
          hitDays += b.validDaysCount; // Each daily bucket has 1 valid day
        }
      }
      final targetStr = _formatValue(targetValue, metric, useKg);
      if (hitDays > 0) {
        insightSentence = "You've hit your $targetStr goal on $hitDays of the last $totalValidDays days.";
      }
    }

    // Best Stretch (Priority 2)
    if (insightSentence == null && (range == TimeRange.threeMonths || range == TimeRange.sixMonths || range == TimeRange.twelveMonths)) {
      if (validCurrent.length >= 2) {
        ChartBucket? bestBucket;
        final downIsGood = _downIsGood(metric);
        
        for (final b in validCurrent) {
          if (b.average == null) continue;
          if (bestBucket == null) {
            bestBucket = b;
          } else {
            if (downIsGood) {
              if (b.average! < bestBucket.average!) bestBucket = b;
            } else {
              if (b.average! > bestBucket.average!) bestBucket = b;
            }
          }
        }
        
        if (bestBucket != null && bestBucket.average != null) {
           final bestVal = _formatValue(bestBucket.average!, metric, useKg);
           
           final startFmt = DateFormat('d MMM').format(bestBucket.startDate);
           final endFmt = bestBucket.startDate.month == bestBucket.endDate.month 
                ? DateFormat('d').format(bestBucket.endDate) 
                : DateFormat('d MMM').format(bestBucket.endDate);
           
           String dateStr = '$startFmt-$endFmt';
           if (range == TimeRange.twelveMonths) {
              dateStr = DateFormat('MMMM yyyy').format(bestBucket.startDate);
           }
           
           final stretchLabel = downIsGood ? 'lowest' : 'best';
           final unitStr = unitLabel.isNotEmpty ? ' $unitLabel' : '';
           insightSentence = "Your $stretchLabel stretch was $dateStr at $bestVal$unitStr/day.";
        }
      }
    }

    // Trend Comparison (Priority 3)
    if (insightSentence == null) {
      if (previousSummary != null) {
        final delta = currentSummary - previousSummary;
        final absDelta = delta.abs();
        
        if (absDelta < 0.01) {
          insightSentence = isTrend 
              ? "${metric.name.capitalize()} has been flat $periodLabel." 
              : "Averaging $currentFmt${unitLabel.isNotEmpty ? ' $unitLabel' : ''}/day $periodLabel.";
        } else {
           if (isTrend) {
             final dirStr = delta > 0 ? 'up' : 'down';
             final deltaFmt = _formatValue(absDelta, metric, useKg);
             insightSentence = "${metric.name.capitalize()} is $dirStr $deltaFmt${unitLabel.isNotEmpty ? ' $unitLabel' : ''} $periodLabel.";
           } else {
             final pct = (absDelta / previousSummary) * 100;
             final pctStr = pct.toStringAsFixed(0);
             final dirStr = delta > 0 ? 'up' : 'down';
             insightSentence = "Averaging $currentFmt${unitLabel.isNotEmpty ? ' $unitLabel' : ''}/day $periodLabel — $dirStr $pctStr% from $prevPeriodLabel.";
           }
        }
      } else {
        // No previous data
        insightSentence = isTrend 
            ? "Your latest ${metric.name.toLowerCase()} is $currentFmt${unitLabel.isNotEmpty ? ' $unitLabel' : ''}."
            : "Averaging $currentFmt${unitLabel.isNotEmpty ? ' $unitLabel' : ''}/day $periodLabel.";
      }
    }
    
    // Fix capitalize extension
    if (insightSentence != null && insightSentence.startsWith('BodyFat')) {
      insightSentence = insightSentence.replaceFirst('BodyFat', 'Body fat');
    } else if (insightSentence != null && insightSentence.startsWith('ScreenTime')) {
      insightSentence = insightSentence.replaceFirst('ScreenTime', 'Screen time');
    } else if (insightSentence != null && insightSentence.startsWith('Bmi')) {
      insightSentence = insightSentence.replaceFirst('Bmi', 'BMI');
    }

    return MetricInsight(
      heroValue: currentSummary,
      heroLabel: heroLabel,
      insightText: insightSentence,
    );
  }
}

extension StringExtension on String {
    String capitalize() {
      if (isEmpty) return this;
      return "${this[0].toUpperCase()}${substring(1)}";
    }
}
