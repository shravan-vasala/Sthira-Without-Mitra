import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/services/progress_insight_service.dart';
import 'package:trufit_bodamma/services/progress_aggregation_service.dart';
import 'package:trufit_bodamma/screens/progress/progress_screen.dart';

void main() {
  group('ProgressInsightService', () {
    test('Sparse data returns no insight', () {
      final buckets = [
        ChartBucket(
          startDate: DateTime(2023, 1, 1),
          endDate: DateTime(2023, 1, 1),
          average: 5000,
          validDaysCount: 1,
          eligibleDaysCount: 1,
        ),
      ];

      final insight = ProgressInsightService.buildInsight(
        metric: MetricType.steps,
        range: TimeRange.oneMonth,
        currentBuckets: buckets,
        previousBuckets: [],
        useKg: true,
      );

      expect(insight.heroValue, 5000);
      expect(insight.heroLabel, 'avg steps / day');
      expect(insight.insightText, isNull);
    });

    test('Goal tracking on 1W or 1M', () {
      final buckets = List.generate(7, (i) => ChartBucket(
        startDate: DateTime(2023, 1, i + 1),
        endDate: DateTime(2023, 1, i + 1),
        average: i % 2 == 0 ? 10500 : 8000, // 4 days > 10000
        validDaysCount: 1,
        eligibleDaysCount: 1,
      ));

      final insight = ProgressInsightService.buildInsight(
        metric: MetricType.steps,
        range: TimeRange.weekly,
        currentBuckets: buckets,
        previousBuckets: [],
        useKg: true,
        targetValue: 10000,
      );

      expect(insight.insightText, "You've hit your 10,000 goal on 4 of the last 7 days.");
    });

    test('Best stretch on 3M', () {
      final buckets = [
        ChartBucket(
          startDate: DateTime(2023, 8, 5),
          endDate: DateTime(2023, 8, 11),
          average: 8000,
          validDaysCount: 7,
          eligibleDaysCount: 7,
        ),
        ChartBucket(
          startDate: DateTime(2023, 8, 12),
          endDate: DateTime(2023, 8, 18),
          average: 11200,
          validDaysCount: 7,
          eligibleDaysCount: 7,
        ),
      ];

      final insight = ProgressInsightService.buildInsight(
        metric: MetricType.steps,
        range: TimeRange.threeMonths,
        currentBuckets: buckets,
        previousBuckets: [],
        useKg: true,
      );

      expect(
        insight.insightText,
        'Your best stretch was 12 Aug-18 at 11,200 steps/day.',
      );
    });

    test('Trend comparison when previous data exists', () {
      final currentBuckets = List.generate(30, (i) => ChartBucket(
        startDate: DateTime(2023, 2, i + 1),
        endDate: DateTime(2023, 2, i + 1),
        average: 7412,
        validDaysCount: 1,
        eligibleDaysCount: 1,
      ));

      final previousBuckets = List.generate(30, (i) => ChartBucket(
        startDate: DateTime(2023, 1, i + 1),
        endDate: DateTime(2023, 1, i + 1),
        average: 6281.35, // ~18% lower
        validDaysCount: 1,
        eligibleDaysCount: 1,
      ));

      final insight = ProgressInsightService.buildInsight(
        metric: MetricType.steps,
        range: TimeRange.oneMonth,
        currentBuckets: currentBuckets,
        previousBuckets: previousBuckets,
        useKg: true,
      );

      expect(insight.heroValue, 7412);
      expect(insight.insightText, "Averaging 7,412 steps/day this month — up 18% from last month.");
    });

    test('Trend comparison down is good for weight', () {
      final currentBuckets = [
        ChartBucket(
          startDate: DateTime(2023, 2, 1),
          endDate: DateTime(2023, 2, 1),
          average: 75.0,
          validDaysCount: 20,
          eligibleDaysCount: 30,
        ),
      ];

      final previousBuckets = [
        ChartBucket(
          startDate: DateTime(2023, 1, 1),
          endDate: DateTime(2023, 1, 1),
          average: 76.2,
          validDaysCount: 20,
          eligibleDaysCount: 30,
        ),
      ];

      final insight = ProgressInsightService.buildInsight(
        metric: MetricType.weight,
        range: TimeRange.oneMonth,
        currentBuckets: currentBuckets,
        previousBuckets: previousBuckets,
        useKg: true,
      );

      expect(insight.heroValue, 75.0);
      expect(insight.insightText, "Weight is down 1.2 kg this month.");
    });
  });
}
