import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../screens/progress/progress_screen.dart'; // for MetricType, TimeRange
import '../services/progress_aggregation_service.dart';
import 'app_providers.dart'; // exports profileProvider, dailyLogsRangeProvider, dailyMealLogsRangeProvider

final aggregatedChartProvider = Provider.autoDispose.family<List<ChartBucket>, ({MetricType metric, TimeRange range, DateTime start, DateTime end})>((ref, args) {
  final startStr = DateFormat('yyyy-MM-dd').format(args.start);
  final endStr = DateFormat('yyyy-MM-dd').format(args.end);
  
  final logs = ref.watch(dailyLogsRangeProvider((startStr, endStr)));
  final mealLogs = ref.watch(dailyMealLogsRangeProvider((startStr, endStr)));
  final profile = ref.watch(profileProvider);

  return ProgressAggregationService.aggregate(
    logs: logs,
    mealLogs: mealLogs,
    metric: args.metric,
    range: args.range,
    rangeStart: args.start,
    rangeEnd: args.end,
    heightInMeters: profile.heightInMeters,
    useKg: profile.useKg,
  );
});
