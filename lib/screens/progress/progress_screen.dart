import 'package:flutter/material.dart';
import '../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../providers/app_providers.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_profile.dart';
import 'widgets/shared_chart_card.dart';
import '../home/weight_entry_dialog.dart';
import '../home/steps_entry_dialog.dart';
import '../home/sleep_entry_dialog.dart';
import '../home/body_fat_entry_dialog.dart';
import 'widgets/chart_drilldown_sheet.dart';
import '../../providers/progress_chart_provider.dart';
import '../../services/progress_aggregation_service.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

enum MetricType {
  weight,
  steps,
  sleep,
  bmi,
  bodyFat,
  calories,
  protein,
  screenTime,
}

enum TimeRange { weekly, oneMonth, threeMonths, sixMonths, twelveMonths }

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key, this.initialMetric});

  final MetricType? initialMetric;

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  late MetricType _selectedMetric;
  final Map<MetricType, TimeRange> _selectedRanges = {};
  ChartBucket? _selectedBucket;

  TimeRange get _selectedRange {
    if (_selectedRanges.containsKey(_selectedMetric)) return _selectedRanges[_selectedMetric]!;
    // Default: daily activity/nutrition to 1W, body measurements to 1M
    final isBody = _selectedMetric == MetricType.weight || _selectedMetric == MetricType.bodyFat || _selectedMetric == MetricType.bmi;
    return isBody ? TimeRange.oneMonth : TimeRange.weekly;
  }
  
  void _setRange(TimeRange range) {
    setState(() {
      _selectedRanges[_selectedMetric] = range;
      _selectedBucket = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedMetric = widget.initialMetric ?? MetricType.weight;
  }

  void _nextMetric() {
    Haptics.tap();
    setState(() {
      int idx = MetricType.values.indexOf(_selectedMetric);
      idx = (idx + 1) % MetricType.values.length;
      _selectedMetric = MetricType.values[idx];
      _selectedBucket = null;
    });
  }

  void _prevMetric() {
    Haptics.tap();
    setState(() {
      int idx = MetricType.values.indexOf(_selectedMetric);
      idx = (idx - 1 + MetricType.values.length) % MetricType.values.length;
      _selectedMetric = MetricType.values[idx];
      _selectedBucket = null;
    });
  }

  void _handleSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;
    if (details.primaryVelocity! > 300) {
      Haptics.tap();
      if (_selectedRange == TimeRange.twelveMonths) {
        _setRange(TimeRange.sixMonths);
      } else if (_selectedRange == TimeRange.sixMonths) _setRange(TimeRange.threeMonths);
      else if (_selectedRange == TimeRange.threeMonths) _setRange(TimeRange.oneMonth);
      else if (_selectedRange == TimeRange.oneMonth) _setRange(TimeRange.weekly);
      else _setRange(TimeRange.twelveMonths);
    } else if (details.primaryVelocity! < -300) {
      Haptics.tap();
      if (_selectedRange == TimeRange.weekly) {
        _setRange(TimeRange.oneMonth);
      } else if (_selectedRange == TimeRange.oneMonth) _setRange(TimeRange.threeMonths);
      else if (_selectedRange == TimeRange.threeMonths) _setRange(TimeRange.sixMonths);
      else if (_selectedRange == TimeRange.sixMonths) _setRange(TimeRange.twelveMonths);
      else _setRange(TimeRange.weekly);
    }
  }

  DateTime _calcStartDate(DateTime now) {
    final d = DateTime(now.year, now.month, now.day);
    switch (_selectedRange) {
      case TimeRange.weekly:
        return DateTime(d.year, d.month, d.day - 6);
      case TimeRange.oneMonth:
        final m = _clampMonth(d, 1);
        return DateTime(m.year, m.month, m.day + 1);
      case TimeRange.threeMonths:
        final m = _clampMonth(d, 3);
        return DateTime(m.year, m.month, m.day + 1);
      case TimeRange.sixMonths:
        final m = _clampMonth(d, 6);
        return DateTime(m.year, m.month, m.day + 1);
      case TimeRange.twelveMonths:
        return DateTime(d.year, d.month - 11, 1);
    }
  }

  DateTime _clampMonth(DateTime date, int monthsBack) {
    int targetYear = date.year;
    int targetMonth = date.month - monthsBack;
    while (targetMonth <= 0) {
      targetMonth += 12;
      targetYear--;
    }
    final int lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final int targetDay = date.day > lastDay ? lastDay : date.day;
    return DateTime(targetYear, targetMonth, targetDay);
  }

  DateTime _calcEndDate(DateTime now) {
    return DateTime(now.year, now.month, now.day);
  }

  void _openManualEntry() {
    if (_selectedMetric == MetricType.weight || _selectedMetric == MetricType.bmi) {
      showAppBottomSheet(context: context, builder: (_) => const WeightEntryDialog());
    } else if (_selectedMetric == MetricType.bodyFat) {
      showAppBottomSheet(context: context, builder: (_) => const BodyFatEntryDialog());
    } else if (_selectedMetric == MetricType.steps) {
      showAppBottomSheet(context: context, builder: (_) => const StepsEntryDialog());
    } else if (_selectedMetric == MetricType.sleep) {
      showAppBottomSheet(context: context, builder: (_) => const SleepEntryDialog());
    }
  }

  void _openDrilldownSheet(ChartBucket bucket) {
    showAppBottomSheet(
      context: context,
      builder: (_) => ChartDrilldownSheet(
        bucket: bucket,
        metric: _selectedMetric,
      ),
    );
  }

  List<ChartDataPoint> _calculateTrendData(List<ChartDataPoint> data) {
    if (data.isEmpty) return [];
    final trend = <ChartDataPoint>[];
    for (int i = 0; i < data.length; i++) {
        final windowStart = data[i].date.subtract(const Duration(days: 6));
        final window = data.where((d) => d.value != null && !d.date.isBefore(windowStart) && !d.date.isAfter(data[i].date)).toList();
        if (window.isNotEmpty) {
          final sum = window.fold<double>(0, (p, c) => p + c.value!);
          trend.add(ChartDataPoint(data[i].date, sum / window.length, bucket: data[i].bucket));
        } else {
          trend.add(ChartDataPoint(data[i].date, null, bucket: data[i].bucket));
        }
    }
    return trend;
  }


  MetricSpec _getMetricSpec(MetricType metric, bool useKg) {
    switch (metric) {
      case MetricType.weight: return MetricSpec(title: 'Weight', unit: useKg ? 'kg' : 'lb', isCount: false, plotType: ChartPlotType.line, showKgLbToggle: true);
      case MetricType.steps: return const MetricSpec(title: 'Steps Taken', unit: 'steps', isCount: true, plotType: ChartPlotType.bar);
      case MetricType.sleep: return const MetricSpec(title: 'Sleep Quality', unit: 'h', isCount: false, plotType: ChartPlotType.bar);
      case MetricType.bmi: return const MetricSpec(title: 'BMI Index', unit: '', isCount: false, plotType: ChartPlotType.line);
      case MetricType.bodyFat: return const MetricSpec(title: 'Body Fat', unit: '%', isCount: false, plotType: ChartPlotType.line);
      case MetricType.calories: return const MetricSpec(title: 'Calories', unit: 'kcal', isCount: true, plotType: ChartPlotType.bar);
      case MetricType.protein: return const MetricSpec(title: 'Protein', unit: 'g', isCount: true, plotType: ChartPlotType.bar);
      case MetricType.screenTime: return const MetricSpec(title: 'Screen Time', unit: 'h', isCount: false, plotType: ChartPlotType.bar);
    }
  }

  String _formatOverviewValue(double value, MetricType metric, bool useKg) {
    switch (metric) {
      case MetricType.weight: return value.toStringAsFixed(1);
      case MetricType.steps: return NumberFormat('#,###').format(value.toInt());
      case MetricType.sleep: return value.toStringAsFixed(1);
      case MetricType.screenTime: return value.toStringAsFixed(1);
      case MetricType.bodyFat: return value.toStringAsFixed(1);
      case MetricType.calories: return '${value.toInt()}';
      case MetricType.protein: return value.toStringAsFixed(0);
      case MetricType.bmi: return value.toStringAsFixed(1);
    }
  }

  String _overviewSubtitle(List<ChartDataPoint> data, MetricType metric, bool useKg) {
    final validData = data.where((d) => d.value != null && d.value!.isFinite).toList();
    if (validData.isEmpty) return 'No recorded data for this period.';
    
    int validDaysCount = 0;
    int eligibleDaysCount = 0;
    for (final d in data) { // sum across all buckets in data!
      if (d.bucket != null) {
        validDaysCount += d.bucket!.validDaysCount;
        eligibleDaysCount += d.bucket!.eligibleDaysCount;
      }
    }
    if (eligibleDaysCount == 0) eligibleDaysCount = validDaysCount == 0 ? 1 : validDaysCount; // fallback
    
    final isTrendMetric = metric == MetricType.weight || metric == MetricType.bodyFat || metric == MetricType.bmi;
    if (isTrendMetric && validData.length >= 2) {
      final trend = _calculateTrendData(validData);
      ChartDataPoint? validFirst, validLast;
      for (final t in trend) {
        if (t.value != null) {
          validFirst ??= t;
          validLast = t;
        }
      }
      if (validFirst != null && validLast != null && validFirst != validLast) {
        final delta = validLast.value! - validFirst.value!;
        final abs = delta.abs();
        final sign = delta > 0 ? '+' : delta < 0 ? '−' : '';
        switch (metric) {
           case MetricType.weight: return 'Coverage: $validDaysCount/$eligibleDaysCount days. $sign${abs.toStringAsFixed(1)} ${useKg ? 'kg' : 'lb'} vs start.';
           case MetricType.bodyFat: return 'Coverage: $validDaysCount/$eligibleDaysCount days. Progress: $sign${abs.toStringAsFixed(1)}% vs start.';
           case MetricType.bmi: return 'Coverage: $validDaysCount/$eligibleDaysCount days. BMI shifted $sign${abs.toStringAsFixed(1)}.';
           default: break;
        }
      }
    }
    return 'Coverage: $validDaysCount/$eligibleDaysCount calendar days logged.';
  }

  String _overviewUnit(MetricType metric, bool useKg) {
    switch (metric) {
      case MetricType.weight: return useKg ? 'kg' : 'lb';
      case MetricType.steps: return 'steps';
      case MetricType.sleep: return 'hrs';
      case MetricType.screenTime: return 'hrs';
      case MetricType.bodyFat: return '%';
      case MetricType.calories: return 'kcal';
      case MetricType.protein: return 'g';
      case MetricType.bmi: return 'BMI';
    }
  }

  Widget _buildStatCards(List<ChartDataPoint> data, MetricType metric, bool useKg, UserProfile profile) {
    final validData = data.where((d) => d.value != null && d.value!.isFinite).toList();
    if (validData.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          'No recorded data for this period.',
          style: context.text.body.copyWith(color: context.colors.textMedium),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (metric == MetricType.steps) {
      double totalSteps = 0;
      int totalDays = 0;
      for (final d in validData) {
        final days = d.bucket?.validDaysCount ?? 1;
        totalSteps += d.value! * days;
        totalDays += days;
      }
      final avg = totalDays > 0 ? (totalSteps / totalDays).toInt() : 0;
      
      double maxVal = 0;
      for (final d in validData) {
        if (d.bucket != null && d.bucket!.max != null) {
          if (d.bucket!.max! > maxVal) maxVal = d.bucket!.max!;
        } else {
          if (d.value! > maxVal) maxVal = d.value!;
        }
      }

      final totalFormatted = NumberFormat('#,###').format(totalSteps.toInt());

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCircularStat('total steps', totalFormatted, Icons.directions_walk_rounded),
            _buildCircularStat('days logged', '$totalDays', Icons.fact_check_rounded),
            _buildCircularStat('best day', NumberFormat('#,###').format(maxVal.toInt()), Icons.emoji_events_rounded),
          ],
        ),
      );
    }
    
    // Unify all metrics to the beautifully flat Triple-Circle Sesireka Layout
    // Displaying "The Journey": Start, Latest, and Delta (Change)
    final start = validData.first.value!;
    final latest = validData.last.value!;
    final delta = latest - start;
    final sign = delta > 0 ? '+' : '';
    
    final unit = _overviewUnit(metric, useKg);

    final isMacroBucket = _selectedRange == TimeRange.threeMonths || _selectedRange == TimeRange.sixMonths || _selectedRange == TimeRange.twelveMonths;
    final startLabel = isMacroBucket ? 'start avg' : 'start $unit';
    final latestLabel = isMacroBucket ? 'latest avg' : 'latest';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCircularStat(startLabel, start.toStringAsFixed(1), Icons.flag_rounded),
          _buildCircularStat(latestLabel, latest.toStringAsFixed(1), Icons.today_rounded),
          if (validData.length > 1)
            _buildCircularStat('change', '$sign${delta.toStringAsFixed(1)}', delta > 0 ? Icons.trending_up_rounded : (delta < 0 ? Icons.trending_down_rounded : Icons.trending_flat_rounded))
          else
            _buildCircularStat('change', '0.0', Icons.trending_flat_rounded),
        ],
      ),
    );
  }

  Widget _buildCircularStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.colors.card.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: context.colors.primary, size: 20),
        ),
        const SizedBox(height: 12),
        Text(value, style: context.text.cardTitle.copyWith(color: context.colors.textDark)),
        const SizedBox(height: 2),
        Text(label, style: context.text.micro.copyWith(color: context.colors.textLight)),
      ],
    );
  }

  Widget _buildRectStat(String label, String value, String unit, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assessment_rounded, color: iconColor, size: 18),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: context.text.screenTitle.copyWith(color: context.colors.textDark)),
              const SizedBox(width: 4),
              Text(unit, style: context.text.body.copyWith(color: context.colors.textLight)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: context.text.caption.copyWith(color: context.colors.textLight)),
        ],
      ),
    );
  }

  Widget _buildChart(List<ChartDataPoint> data, bool useKg, dynamic profile, DateTime startDate, DateTime endDate) {
    final daysWithData = data.where((d) => d.value != null).length;
    final isEmpty = daysWithData == 0;
    
    ChartTimeFormat format;
    switch (_selectedRange) {
      case TimeRange.weekly: format = ChartTimeFormat.weekly; break;
      case TimeRange.oneMonth: format = ChartTimeFormat.oneMonth; break;
      case TimeRange.threeMonths: format = ChartTimeFormat.threeMonths; break;
      case TimeRange.sixMonths: format = ChartTimeFormat.sixMonths; break;
      case TimeRange.twelveMonths: format = ChartTimeFormat.twelveMonths; break;
    }

    String emptyMessage = 'No ${_metricLabel(_selectedMetric).toLowerCase()} entries yet.';
    if (_selectedMetric == MetricType.bmi) emptyMessage = 'Log your weight to see BMI.';

    final isTrendMetric = _selectedMetric == MetricType.weight || _selectedMetric == MetricType.bodyFat || _selectedMetric == MetricType.bmi;
    final trendData = (_selectedRange != TimeRange.sixMonths && isTrendMetric && data.length > 2) ? _calculateTrendData(data) : null;
    
    final validData = data.where((d) => d.value != null && d.value!.isFinite).toList();
    
    double avgValue = 0;
    if (validData.isNotEmpty) {
      double sum = 0;
      int days = 0;
      for (final d in validData) {
        final c = d.bucket?.validDaysCount ?? 1;
        sum += d.value! * c;
        days += c;
      }
      avgValue = days > 0 ? sum / days : 0;
    }
    
    final subtitleText = _overviewSubtitle(data, _selectedMetric, useKg);
    final unitText = _overviewUnit(_selectedMetric, useKg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isEmpty) ...[
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                  TweenAnimationBuilder<double>(
                  key: ValueKey('$_selectedMetric-$_selectedRange'),
                  tween: Tween<double>(begin: avgValue, end: avgValue), // Disable 1200ms count-up
                  duration: const Duration(milliseconds: 200),
                  builder: (context, value, child) {
                    final displayValue = data.isNotEmpty ? _formatOverviewValue(value, _selectedMetric, useKg) : '—';
                    return Text(
                      displayValue,
                      style: context.text.metric.copyWith(color: context.colors.textDark),
                    );
                  }
                ),
                const SizedBox(width: 6),
                Text(
                  unitText,
                  style: context.text.screenTitle.copyWith(color: context.colors.textMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              subtitleText,
              textAlign: TextAlign.center,
              style: context.text.body.copyWith(color: context.colors.textMedium),
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        // Date Pill Navigation
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: context.colors.card.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRangeTab(context, '1W', TimeRange.weekly),
                _buildRangeTab(context, '1M', TimeRange.oneMonth),
                _buildRangeTab(context, '3M', TimeRange.threeMonths),
                _buildRangeTab(context, '6M', TimeRange.sixMonths),
                _buildRangeTab(context, '12M', TimeRange.twelveMonths),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: _handleSwipe,
            behavior: HitTestBehavior.opaque,
            child: SharedChartCard(
              metric: _getMetricSpec(_selectedMetric, useKg),
              data: isEmpty ? [] : data,
              trendData: trendData,
              startDate: startDate,
              endDate: endDate,
              useKg: useKg,
              onToggleUnit: () {},
              statLabels: const [], // Hide Shared Chart Footer
              statValues: const [],
              timeFormat: format,
              emptyMessage: emptyMessage,
              // ignore: avoid_dynamic_calls
              targetValue: _selectedMetric == MetricType.weight && profile.targetWeight != null
                  ? (useKg
                      // ignore: avoid_dynamic_calls
                      ? profile.targetWeight as double
                      // ignore: avoid_dynamic_calls
                      : (profile.targetWeight as double) * 2.20462)
                  : null,
              onPointLongPress: null,
              onPointTap: (point) {
                if (_selectedRange == TimeRange.threeMonths || _selectedRange == TimeRange.sixMonths || _selectedRange == TimeRange.twelveMonths) {
                  if (point.bucket != null) {
                    setState(() {
                      _selectedBucket = point.bucket;
                    });
                  }
                } else {
                  // Direct daily navigation for 1W/1M
                  ref.read(selectedDateProvider.notifier).state = point.date;
                  context.go('/home');
                }
              },
              expandChart: true,
            ),
          ),
        ),
        
        // Show Drilldown Button if a bucket is selected
        if (_selectedBucket != null && (_selectedRange == TimeRange.threeMonths || _selectedRange == TimeRange.sixMonths || _selectedRange == TimeRange.twelveMonths))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () {
                Haptics.tap();
                _openDrilldownSheet(_selectedBucket!);
              },
              icon: const Icon(Icons.calendar_view_day_rounded, size: 20),
              label: const Text('View Daily Details', style: context.text.body),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        
        // Bottom Sesireka styled cards
        // Pass data if needed, or update _buildStatCards logic
        _buildStatCards(data, _selectedMetric, useKg, profile as UserProfile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider);
    final startDate = _calcStartDate(now);
    final endDate = _calcEndDate(now);
    
    final profile = ref.watch(profileProvider);
    final useKg = profile.useKg;
    
    final buckets = ref.watch(aggregatedChartProvider((
      metric: _selectedMetric,
      range: _selectedRange,
      start: startDate,
      end: endDate,
    )));
    
    final data = buckets.map((b) => ChartDataPoint(b.startDate, b.average, bucket: b)).toList();

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left_rounded, color: context.colors.textMedium),
              onPressed: _prevMetric,
            ),
            Text(
              _metricTitle(_selectedMetric),
              style: context.text.screenTitle.copyWith(color: context.colors.textDark),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded, color: context.colors.textMedium, size: 16),
              onPressed: _nextMetric,
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () {
              Haptics.tap();
              context.push('/progress/yearly-activity');
            },
          ),
          if (_selectedMetric != MetricType.bmi &&
              _selectedMetric != MetricType.calories &&
              _selectedMetric != MetricType.protein &&
              _selectedMetric != MetricType.screenTime)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () {
                Haptics.tap();
                _openManualEntry();
              },
            ),
            const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey('$_selectedMetric-$_selectedRange'),
            child: _buildChart(data, useKg, profile, startDate, endDate),
          ),
        ),
      ),
    );
  }

  String _metricTitle(MetricType metric) {
    switch (metric) {
      case MetricType.weight: return 'Weight';
      case MetricType.steps: return 'Steps Taken';
      case MetricType.sleep: return 'Sleep Quality';
      case MetricType.bmi: return 'BMI Index';
      case MetricType.bodyFat: return 'Body Fat';
      case MetricType.calories: return 'Calories';
      case MetricType.protein: return 'Protein';
      case MetricType.screenTime: return 'Screen Time';
    }
  }

  String _metricLabel(MetricType metric) {
    return _metricTitle(metric);
  }

  Widget _buildRangeTab(BuildContext context, String label, TimeRange range) {
    final isSelected = _selectedRange == range;
    return GestureDetector(
      onTap: () {
        Haptics.tap();
        _setRange(range);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: context.text.caption.copyWith(color: isSelected ? context.colors.onPrimary : context.colors.textMedium),
        ),
      ),
    );
  }
}
