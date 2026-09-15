import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:trufit_bodamma/providers/app_providers.dart';
import 'package:trufit_bodamma/services/progress_aggregation_service.dart';
import 'package:trufit_bodamma/screens/progress/progress_screen.dart';
import 'package:trufit_bodamma/screens/progress/widgets/shared_chart_card.dart';
import 'package:trufit_bodamma/theme/app_colors.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class ChartDrilldownSheet extends ConsumerWidget {
  const ChartDrilldownSheet({
    super.key,
    required this.bucket,
    required this.metric,
  });

  final ChartBucket bucket;
  final MetricType metric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startStr = DateFormat('yyyy-MM-dd').format(bucket.startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(bucket.endDate);
    
    // We fetch the EXACT daily logs for the bucket's date range
    final logs = ref.watch(dailyLogsRangeProvider((startStr, endStr)));
    final mealLogs = ref.watch(dailyMealLogsRangeProvider((startStr, endStr)));
    final profile = ref.watch(profileProvider);
    final useKg = profile.useKg;
    
    // Aggregate them as daily buckets (1W/1M style)
    final dailyBuckets = ProgressAggregationService.aggregate(
      logs: logs,
      mealLogs: mealLogs,
      metric: metric,
      range: bucket.endDate.difference(bucket.startDate).inDays <= 7 ? TimeRange.weekly : TimeRange.oneMonth,
      rangeStart: bucket.startDate,
      rangeEnd: bucket.endDate,
      today: DateTime.now(),
      heightInMeters: profile.heightInMeters,
      useKg: useKg,
    );
    
    final data = dailyBuckets.map((b) => ChartDataPoint(b.startDate, b.average, bucket: b)).toList();
    
    ChartPlotType plotType;
    String unit = '';
    bool isCount = false;
    String title = '';
    
    switch (metric) {
      case MetricType.weight: title = 'Weight'; unit = useKg ? 'kg' : 'lb'; plotType = ChartPlotType.line; break;
      case MetricType.steps: title = 'Steps'; unit = 'steps'; isCount = true; plotType = ChartPlotType.bar; break;
      case MetricType.sleep: title = 'Sleep'; unit = 'h'; plotType = ChartPlotType.bar; break;
      case MetricType.bmi: title = 'BMI'; plotType = ChartPlotType.line; break;
      case MetricType.bodyFat: title = 'Body Fat'; unit = '%'; plotType = ChartPlotType.line; break;
      case MetricType.calories: title = 'Calories'; unit = 'kcal'; isCount = true; plotType = ChartPlotType.bar; break;
      case MetricType.protein: title = 'Protein'; unit = 'g'; isCount = true; plotType = ChartPlotType.bar; break;
      case MetricType.screenTime: title = 'Screen Time'; unit = 'h'; plotType = ChartPlotType.bar; break;
    }
    
    final metricSpec = MetricSpec(
      title: title,
      unit: unit,
      isCount: isCount,
      plotType: plotType,
      showKgLbToggle: false,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.scaffoldBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(
              'Daily Details: ${DateFormat('MMM d').format(bucket.startDate)} - ${DateFormat('MMM d').format(bucket.endDate)}',
              style: context.text.screenTitle.copyWith(color: context.colors.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SharedChartCard(
                metric: metricSpec,
                data: data,
                startDate: bucket.startDate,
                endDate: bucket.endDate,
                useKg: useKg,
                statLabels: const [],
                statValues: const [],
                timeFormat: bucket.endDate.difference(bucket.startDate).inDays <= 7 ? ChartTimeFormat.weekly : ChartTimeFormat.monthly,
                emptyMessage: 'No daily entries in this period.',
                expandChart: true,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
