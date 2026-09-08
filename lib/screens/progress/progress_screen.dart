import 'package:flutter/material.dart';
import '../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/layout_insets.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../providers/app_providers.dart';
import '../../models/daily_log.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_profile.dart';
import 'widgets/shared_chart_card.dart';
import '../home/weight_entry_dialog.dart';
import '../home/steps_entry_dialog.dart';
import '../home/sleep_entry_dialog.dart';
import '../home/body_fat_entry_dialog.dart';
import '../../models/daily_meal_log.dart';
import 'widgets/insights_card.dart';

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

enum TimeRange { weekly, monthly, sixMonths }

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key, this.initialMetric});

  final MetricType? initialMetric;

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  late MetricType _selectedMetric;
  TimeRange _selectedRange = TimeRange.monthly;
  late DateTime _currentReferenceDate;

  @override
  void initState() {
    super.initState();
    _selectedMetric = widget.initialMetric ?? MetricType.weight;
    _currentReferenceDate = DateTime.now();
  }

  void _nextMetric() {
    Haptics.tap();
    setState(() {
      int idx = MetricType.values.indexOf(_selectedMetric);
      idx = (idx + 1) % MetricType.values.length;
      _selectedMetric = MetricType.values[idx];
    });
  }

  void _prevMetric() {
    Haptics.tap();
    setState(() {
      int idx = MetricType.values.indexOf(_selectedMetric);
      idx = (idx - 1 + MetricType.values.length) % MetricType.values.length;
      _selectedMetric = MetricType.values[idx];
    });
  }

  void _handleSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null) return;
    if (details.primaryVelocity! > 300) {
      // Swiped right -> older range or wider scale? Let's cycle TimeRange:
      Haptics.tap();
      setState(() {
        if (_selectedRange == TimeRange.sixMonths) _selectedRange = TimeRange.monthly;
        else if (_selectedRange == TimeRange.monthly) _selectedRange = TimeRange.weekly;
        else _selectedRange = TimeRange.sixMonths;
      });
    } else if (details.primaryVelocity! < -300) {
      // Swiped left
      Haptics.tap();
      setState(() {
        if (_selectedRange == TimeRange.weekly) _selectedRange = TimeRange.monthly;
        else if (_selectedRange == TimeRange.monthly) _selectedRange = TimeRange.sixMonths;
        else _selectedRange = TimeRange.weekly;
      });
    }
  }

  DateTime get _startDate {
    final d = _currentReferenceDate;
    switch (_selectedRange) {
      case TimeRange.weekly:
        final daysToSubtract = d.weekday - DateTime.monday;
        return DateTime(d.year, d.month, d.day - daysToSubtract);
      case TimeRange.monthly:
        return DateTime(d.year, d.month, 1);
      case TimeRange.sixMonths:
        return DateTime(d.year, d.month - 5, 1);
    }
  }

  DateTime get _endDate {
    final d = _currentReferenceDate;
    switch (_selectedRange) {
      case TimeRange.weekly:
        return _startDate.add(const Duration(days: 6));
      case TimeRange.monthly:
        return DateTime(d.year, d.month + 1, 0);
      case TimeRange.sixMonths:
        return DateTime(d.year, d.month + 1, 0);
    }
  }

  void _shiftDate(int direction) {
    Haptics.tap();
    setState(() {
      if (_selectedRange == TimeRange.weekly) {
        _currentReferenceDate = _currentReferenceDate.add(Duration(days: 7 * direction));
      } else if (_selectedRange == TimeRange.monthly) {
        _currentReferenceDate = DateTime(_currentReferenceDate.year, _currentReferenceDate.month + direction, 1);
      } else {
        _currentReferenceDate = DateTime(_currentReferenceDate.year, _currentReferenceDate.month + (6 * direction), 1);
      }
    });
  }

  String get _headerText {
    if (_selectedRange == TimeRange.weekly) {
      return '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}';
    } else if (_selectedRange == TimeRange.monthly) {
      return DateFormat('MMMM yyyy').format(_startDate);
    } else {
      return '${DateFormat('MMM yyyy').format(_startDate)} - ${DateFormat('MMM yyyy').format(_endDate)}';
    }
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

  List<ChartDataPoint> _calculateTrendData(List<ChartDataPoint> data) {
    if (data.isEmpty) return [];
    final trend = <ChartDataPoint>[];
    for (int i = 0; i < data.length; i++) {
        final window = data.sublist(i > 6 ? i - 6 : 0, i + 1);
        final sum = window.fold<double>(0, (p, c) => p + c.value);
        trend.add(ChartDataPoint(data[i].date, sum / window.length));
    }
    return trend;
  }

  List<ChartDataPoint> _downsampleToWeekly(List<ChartDataPoint> data) {
    if (data.isEmpty) return [];
    final result = <ChartDataPoint>[];
    int currentWeek = -1;
    List<double> currentWeekVals = [];
    DateTime? currentWeekDate;

    for (var d in data) {
       final weekIdx = d.date.difference(data.first.date).inDays ~/ 7;
       if (weekIdx != currentWeek) {
           if (currentWeekVals.isNotEmpty) {
               final avg = currentWeekVals.reduce((a,b)=>a+b) / currentWeekVals.length;
               result.add(ChartDataPoint(currentWeekDate!, avg));
           }
           currentWeek = weekIdx;
           currentWeekVals = [d.value];
           currentWeekDate = d.date;
       } else {
           currentWeekVals.add(d.value);
       }
    }
    if (currentWeekVals.isNotEmpty) {
        final avg = currentWeekVals.reduce((a,b)=>a+b) / currentWeekVals.length;
        result.add(ChartDataPoint(currentWeekDate!, avg));
    }
    return result;
  }

  List<ChartDataPoint> _dailyMetricSeries(List<DailyLog> logs, List<DailyMealLog> mealLogs, MetricType metric, UserProfile profile) {
    final logsByDate = {for (var l in logs) l.date: l};
    final daysDiff = _endDate.difference(_startDate).inDays;
    final data = <ChartDataPoint>[];
    final useKg = profile.useKg;

    for (int i = 0; i <= daysDiff; i++) {
      final d = _startDate.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final log = logsByDate[dateStr];
      if (log == null) continue;

      double? val;
      switch (metric) {
        case MetricType.weight: val = log.weight != null ? (useKg ? log.weight! : log.weight! * 2.20462) : null; break;
        case MetricType.steps: val = log.steps?.toDouble(); break;
        case MetricType.sleep: val = log.sleepHours; break;
        case MetricType.screenTime: if (log.screenTimeMinutes != null) val = log.screenTimeMinutes! / 60.0; break;
        case MetricType.bodyFat: val = log.bodyFat; break;
        case MetricType.bmi: 
          if (log.weight != null) {
            final h = profile.heightInMeters;
            val = log.weight! / (h * h);
          }
          break;
        case MetricType.calories:
          final mLog = mealLogs.firstWhere((m) => m.date == dateStr, orElse: () => DailyMealLog(date: dateStr));
          if (mLog.loggedSlotsCount > 0) val = mLog.totalCalories.toDouble();
          break;
        case MetricType.protein: 
          final mLog = mealLogs.firstWhere((m) => m.date == dateStr, orElse: () => DailyMealLog(date: dateStr));
          if (mLog.loggedSlotsCount > 0) val = mLog.totalProtein;
          break;
      }
      if (val != null) {
        if (metric == MetricType.steps && val <= 0) continue;
        data.add(ChartDataPoint(d, val));
      }
    }
    return data;
  }

  String _formatOverviewValue(double value, MetricType metric, bool useKg) {
    switch (metric) {
      case MetricType.weight: return '${value.toStringAsFixed(1)}';
      case MetricType.steps: return NumberFormat('#,###').format(value.toInt());
      case MetricType.sleep: return '${value.toStringAsFixed(1)}';
      case MetricType.screenTime: return '${value.toStringAsFixed(1)}';
      case MetricType.bodyFat: return '${value.toStringAsFixed(1)}';
      case MetricType.calories: return '${value.toInt()}';
      case MetricType.protein: return '${value.toStringAsFixed(0)}';
      case MetricType.bmi: return value.toStringAsFixed(1);
    }
  }

  String _overviewSubtitle(List<ChartDataPoint> data, MetricType metric, bool useKg) {
    if (data.isEmpty) return 'No data yet';
    final isTrendMetric = metric == MetricType.weight || metric == MetricType.bodyFat || metric == MetricType.bmi || metric == MetricType.sleep;
    if (isTrendMetric && data.length >= 2) {
      final trend = _calculateTrendData(data);
      if (trend.isEmpty) trend.addAll(data);
      final delta = trend.last.value - trend.first.value;
      final abs = delta.abs();
      final sign = delta > 0 ? '+' : delta < 0 ? '−' : '';
      switch (metric) {
        case MetricType.weight: return 'You have a stable track record. $sign${abs.toStringAsFixed(1)} ${useKg ? 'kg' : 'lb'} vs start!';
        case MetricType.sleep:
        case MetricType.screenTime: return 'Trend shows $sign${abs.toStringAsFixed(1)}h vs start of period.';
        case MetricType.bodyFat: return 'Progress: $sign${abs.toStringAsFixed(1)}% vs start.';
        case MetricType.bmi: return 'Your BMI shifted $sign${abs.toStringAsFixed(1)}.';
        default: break;
      }
    }
    return 'Consistent tracking is the key to steady action.';
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
    if (data.isEmpty) return const SizedBox();

    if (metric == MetricType.steps) {
      final valid = data.map((d) => d.value).toList();
      final total = valid.reduce((a, b) => a + b);
      final avg = total ~/ valid.length;
      final maxVal = valid.reduce((a, b) => a > b ? a : b).toInt();
      final kcal = (avg * 0.04).toStringAsFixed(0);
      final distance = (avg * 0.762).toStringAsFixed(0); // roughly 0.762m per step

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCircularStat('kcal', '${kcal}+', Icons.bolt),
            _buildCircularStat('meters', distance, Icons.location_on),
            _buildCircularStat('max steps', NumberFormat('#,###').format(maxVal), Icons.directions_run),
          ],
        ),
      );
    } 
    
    // Unify all metrics to the beautifully flat Triple-Circle Sesireka Layout
    // Displaying "The Journey": Start, Latest, and Delta (Change)
    final start = data.first.value;
    final latest = data.last.value;
    final delta = latest - start;
    final sign = delta > 0 ? '+' : '';
    
    final unit = _overviewUnit(metric, useKg);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCircularStat('start $unit', start.toStringAsFixed(1), Icons.flag_rounded),
          _buildCircularStat('latest', latest.toStringAsFixed(1), Icons.today_rounded),
          if (data.length > 1)
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
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.colors.textDark)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: context.colors.textLight)),
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
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.colors.textDark)),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 14, color: context.colors.textLight)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: context.colors.textLight, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildChart(List<DailyLog> logs, List<DailyMealLog> mealLogs, bool useKg, dynamic profile) {
    List<ChartDataPoint> data = _dailyMetricSeries(logs, mealLogs, _selectedMetric, profile);
    
    // We intentionally bypass downsampling (like _downsampleToWeekly) for 6 Months 
    // to preserve massive daily volatility (like a stock/Sensex graph).
    
    final daysWithData = data.length;
    final isEmpty = daysWithData == 0;
    
    ChartTimeFormat format;
    switch (_selectedRange) {
      case TimeRange.weekly: format = ChartTimeFormat.weekly; break;
      case TimeRange.monthly: format = ChartTimeFormat.monthly; break;
      case TimeRange.sixMonths: format = ChartTimeFormat.sixMonths; break;
    }

    String emptyMessage = 'No ${_metricLabel(_selectedMetric).toLowerCase()} entries yet.';
    if (_selectedMetric == MetricType.bmi) emptyMessage = 'Log your weight to see BMI.';

    final isTrendMetric = _selectedMetric == MetricType.weight || _selectedMetric == MetricType.bodyFat || _selectedMetric == MetricType.bmi;
    final trendData = (_selectedRange != TimeRange.sixMonths && isTrendMetric && data.length > 2) ? _calculateTrendData(data) : null;
    
    final double avgValue = data.isNotEmpty ? data.map((d) => d.value).reduce((a,b)=>a+b)/data.length : 0;
    
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
                  tween: Tween<double>(begin: avgValue * 0.5, end: avgValue),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutQuart,
                  builder: (context, value, child) {
                    final displayValue = data.isNotEmpty ? _formatOverviewValue(value, _selectedMetric, useKg) : '—';
                    return Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textDark,
                        letterSpacing: -1.5,
                      ),
                    );
                  }
                ),
                const SizedBox(width: 6),
                Text(
                  unitText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textMedium,
                  ),
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.textMedium,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        // Date Pill Navigation
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.card.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _shiftDate(-1),
                  child: Icon(Icons.chevron_left_rounded, color: context.colors.textMedium, size: 20),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _headerText,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textDark),
                  ),
                ),
                GestureDetector(
                  onTap: () => _shiftDate(1),
                  child: Icon(Icons.chevron_right_rounded, color: context.colors.textMedium, size: 20),
                ),
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
              title: '', // No title needed since it's above
              data: isEmpty ? [] : data,
              trendData: trendData,
              startDate: _startDate,
              endDate: _endDate,
              isSteps: _selectedMetric == MetricType.steps,
              showKgLbToggle: false,
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
              onPointTap: (date, value) {
                ref.read(selectedDateProvider.notifier).state = date;
                context.go('/home');
              },
              expandChart: true,
            ),
          ),
        ),
        
        // Bottom Sesireka styled cards
        _buildStatCards(data, _selectedMetric, useKg, profile as UserProfile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    final logs = ref.watch(dailyLogsRangeProvider((startStr, endStr)));
    final mealLogs = ref.watch(dailyMealLogsRangeProvider((startStr, endStr)));
    final profile = ref.watch(profileProvider);

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
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.colors.textDark,
                letterSpacing: -0.5,
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded, color: context.colors.textMedium),
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
            key: ValueKey('${_selectedMetric.name}_${_selectedRange.name}_${_currentReferenceDate.toIso8601String()}'),
            child: _buildChart(logs, mealLogs, profile.useKg, profile),
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
}
