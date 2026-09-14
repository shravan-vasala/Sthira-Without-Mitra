import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/haptics.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/layout_insets.dart';
import '../../../services/progress_aggregation_service.dart';

enum ChartTimeFormat { weekly, monthly, oneMonth, threeMonths, sixMonths, twelveMonths, allTime }

class ChartDataPoint {
  final DateTime date;
  final double? value;
  final ChartBucket? bucket;
  ChartDataPoint(this.date, this.value, {this.bucket});
}

enum ChartPlotType { bar, line }

class MetricSpec {
  final String title;
  final String unit;
  final bool isCount;
  final ChartPlotType plotType;
  final bool showKgLbToggle;

  const MetricSpec({
    required this.title,
    required this.unit,
    this.isCount = false,
    this.plotType = ChartPlotType.line,
    this.showKgLbToggle = false,
  });
}

class SharedChartCard extends StatelessWidget {
  const SharedChartCard({
    super.key,
    required this.metric,
    required this.data,
    this.trendData,
    required this.startDate,
    required this.endDate,
    this.useKg = true,
    this.onToggleUnit,
    required this.statLabels,
    required this.statValues,
    this.timeFormat = ChartTimeFormat.monthly,
    this.emptyMessage = 'No data available for this period',
    this.targetValue,
    this.onPointLongPress,
    this.onPointTap,
    this.expandChart = false,
  });

  final MetricSpec metric;
  final List<ChartDataPoint> data;
  final List<ChartDataPoint>? trendData;
  final DateTime startDate;
  final DateTime endDate;
  final bool useKg;
  final VoidCallback? onToggleUnit;
  final List<String> statLabels;
  final List<String> statValues;
  final ChartTimeFormat timeFormat;
  final String emptyMessage;
  final double? targetValue;
  final void Function(ChartDataPoint point)? onPointLongPress;
  final void Function(ChartDataPoint point)? onPointTap;
  final bool expandChart;

  bool get _isCount => metric.isCount;

  bool get _useBars => metric.plotType == ChartPlotType.bar && (timeFormat == ChartTimeFormat.weekly || timeFormat == ChartTimeFormat.oneMonth);

  String _unitSuffix() {
    if (metric.showKgLbToggle) return useKg ? ' kg' : ' lb';
    return metric.unit.isEmpty ? '' : ' ${metric.unit}';
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          metric.title,
          style: TextStyle(
            fontFamily: 'Cabinet Grotesk',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.colors.textDark,
          ),
        ),
        const Spacer(),
        if (metric.showKgLbToggle)
          GestureDetector(
            onTap: onToggleUnit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.insetSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                useKg ? 'KG' : 'LB',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.colors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget chartArea = (data.isEmpty && (trendData == null || trendData!.isEmpty))
        ? Center(
            child: Text(
              emptyMessage,
              style: TextStyle(fontSize: 14, color: context.colors.textLight),
              textAlign: TextAlign.center,
            ),
          )
        : _useBars
        ? _buildBarChart(context)
        : _buildLineChart(context);

    if (!expandChart) {
      chartArea = SizedBox(height: 200, child: chartArea);
    } else {
      chartArea = Expanded(child: chartArea);
    }

    Widget mainContainer = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 20),
          chartArea,
        ],
      ),
    );

    if (expandChart) {
      mainContainer = Expanded(child: mainContainer);
    }

    return Column(
      children: [
        mainContainer,
        const SizedBox(height: 16),
        if (statLabels.isNotEmpty && statValues.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(kCardRadius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                statLabels.length,
                (index) => Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              statLabels[index],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textLight,
                                letterSpacing: 1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              statValues[index],
                              style: TextStyle(
                                fontFamily: 'Cabinet Grotesk',
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: context.colors.textDark,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      if (index < statLabels.length - 1)
                        Container(
                          width: 1,
                          height: 30,
                          color: context.colors.border,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  double get _maxXValue => data.isEmpty ? 1.0 : (data.length - 1).toDouble();

  (double, double) _yRange(Iterable<double> ys) {
    final allYs = ys.toList();
    if (targetValue != null) allYs.add(targetValue!);
    double minY = allYs.reduce(min);
    double maxY = allYs.reduce(max);

    if (minY == maxY) {
      if (minY == 0) {
        maxY = 10;
      } else {
        minY -= 1;
        maxY += 1;
      }
    } else {
      final padding = (maxY - minY) * 0.12;
      minY -= padding;
      maxY += padding;
    }

    if (_isCount && minY < 0) minY = 0;
    if (_useBars) minY = 0;
    return (minY, maxY);
  }

  ExtraLinesData? _buildExtraLines(
    BuildContext context, {
    List<FlSpot>? spots,
  }) {
    final lines = <HorizontalLine>[];

    if (targetValue != null) {
      lines.add(
        HorizontalLine(
          y: targetValue!,
          color: context.colors.orange.withValues(alpha: 0.85),
          strokeWidth: 1.5,
          dashArray: [6, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 4, bottom: 2),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.colors.orange,
            ),
            labelResolver: (_) {
              final t = targetValue!;
              if (_isCount && t >= 1000) {
                return 'Goal ${(t / 1000).toStringAsFixed(1)}k';
              }
              if (_isCount) return 'Goal ${t.toStringAsFixed(0)}';
              return 'Goal ${t.toStringAsFixed(1)}';
            },
          ),
        ),
      );
    }

    if (timeFormat == ChartTimeFormat.sixMonths &&
        spots != null &&
        spots.isNotEmpty) {
      final minyData = spots.map((s) => s.y).reduce(min);
      final maxyData = spots.map((s) => s.y).reduce(max);

      lines.add(
        HorizontalLine(
          y: maxyData,
          color: Colors.transparent,
          strokeWidth: 0,
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            style: TextStyle(
              fontSize: 10,
              color: context.colors.primary,
              fontWeight: FontWeight.bold,
            ),
            labelResolver: (_) => 'Max ${maxyData.toStringAsFixed(1)}',
          ),
        ),
      );

      if (minyData != maxyData) {
        lines.add(
          HorizontalLine(
            y: minyData,
            color: Colors.transparent,
            strokeWidth: 0,
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.only(right: 4, top: 2),
              style: TextStyle(
                fontSize: 10,
                color: context.colors.red,
                fontWeight: FontWeight.bold,
              ),
              labelResolver: (_) => 'Min ${minyData.toStringAsFixed(1)}',
            ),
          ),
        );
      }
    }

    if (lines.isEmpty) return null;
    return ExtraLinesData(horizontalLines: lines);
  }

  Widget _bottomTitle(BuildContext context, double value, TitleMeta meta) {
    final int index = value.round();
    if (index < 0 || index >= data.length) {
      return const SizedBox.shrink();
    }

    final date = data[index].date;
    String label;

    if (timeFormat == ChartTimeFormat.weekly) {
      label = DateFormat('E').format(date);
    } else if (timeFormat == ChartTimeFormat.oneMonth) {
      final lastDay = DateTime(date.year, date.month + 1, 0).day;
      final show = date.day == 1 || date.day == 8 || date.day == 15 || date.day == 22 || date.day == lastDay;
      if (!show) return const SizedBox.shrink();
      label = date.day.toString();
      if (date.day == 1) label = '${DateFormat('MMM').format(date)}\n$label';
    } else if (timeFormat == ChartTimeFormat.threeMonths || timeFormat == ChartTimeFormat.sixMonths) {
      bool show = false;
      if (index == 0) show = true;
      else if (data[index].date.month != data[index - 1].date.month) show = true;
      if (!show) return const SizedBox.shrink();
      label = DateFormat('MMM').format(date);
      if (date.month == 1) label = DateFormat('MMM\nyy').format(date);
    } else {
      label = DateFormat('MMM').format(date);
      if (date.month == 1) label = DateFormat('MMM\nyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: context.colors.textLight),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _leftTitle(BuildContext context, double value, TitleMeta meta) {
    if (_isCount && value < 0) return const SizedBox.shrink();

    String label;
    if (_isCount) {
      if (value >= 1000) {
        final kVal = value / 1000;
        label = '${kVal.toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
      } else {
        label = value.toInt().toString();
      }
    } else {
      label = value.toStringAsFixed(1);
    }

    return Text(
      label,
      style: TextStyle(fontSize: 10, color: context.colors.textLight),
    );
  }

  FlTitlesData _titlesData(BuildContext context) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (value, meta) => _bottomTitle(context, value, meta),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) => _leftTitle(context, value, meta),
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  String _tooltipText(ChartDataPoint point) {
    final date = point.date;
    final value = point.value ?? 0.0;
    
    String dateStr;
    String extra = '';
    
    if (point.bucket != null && timeFormat != ChartTimeFormat.weekly && timeFormat != ChartTimeFormat.monthly) {
      final b = point.bucket!;
      if (timeFormat == ChartTimeFormat.allTime) { 
        dateStr = DateFormat('MMM yyyy').format(b.startDate);
      } else { 
        final endFmt = b.startDate.month == b.endDate.month ? 'd' : 'MMM d';
        dateStr = '${DateFormat('MMM d').format(b.startDate)} - ${DateFormat(endFmt).format(b.endDate)}';
      }
      
      if (b.isPartial) dateStr += ' (Partial)';
      
      extra += '\nCoverage: ${b.validDaysCount}/${b.eligibleDaysCount} days';
      if (b.min != null && b.max != null) {
         extra += '\nMin: ${b.min!.toStringAsFixed(1)} | Max: ${b.max!.toStringAsFixed(1)}';
      }
    } else {
      dateStr = DateFormat('EEE, d MMM yyyy').format(date);
    }
    
    final valStr = value.toStringAsFixed(_isCount ? 0 : 1);
    final unit = _unitSuffix();
    if (targetValue != null) {
      final diff = value - targetValue!;
      final sign = diff >= 0 ? '+' : '';
      extra += '\n$sign${diff.toStringAsFixed(_isCount ? 0 : 1)}$unit vs goal';
    }
    return '$dateStr\n$valStr$unit$extra';
  }

  ChartDataPoint? _getPointForOffset(double xOffset) {
    final index = xOffset.toInt();
    if (index >= 0 && index < data.length) return data[index];
    return null;
  }

  // Removed redundant _segmentSpots. We will do this inline in _buildLineChart.

  Widget _buildBarChart(BuildContext context) {
    final primary = context.colors.primary;
    final validVals = data.where((d) => d.value != null).map((d) => d.value!);
    final (minY, maxY) = validVals.isEmpty ? (0.0, 10.0) : _yRange(validVals);
    final daySpan = data.length;
    final barWidth = daySpan <= 7
        ? 14.0
        : daySpan <= 31
        ? 6.0
        : daySpan <= 90
        ? 3.0
        : 1.2;

    // One group per calendar bucket
    final groups = <BarChartGroupData>[
      for (int x = 0; x < daySpan; x++)
        BarChartGroupData(
          x: x,
          barRods: [
            BarChartRodData(
              toY: data[x].value ?? 0,
              width: barWidth,
              borderRadius: data[x].value != null
                  ? const BorderRadius.vertical(top: Radius.circular(4))
                  : BorderRadius.zero,
              color: data[x].value != null ? primary : Colors.transparent,
              gradient: data[x].value != null
                  ? LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [primary.withValues(alpha: 0.55), primary],
                    )
                  : null,
            ),
          ],
        ),
    ];

    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: context.colors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        extraLinesData: _buildExtraLines(context),
        titlesData: _titlesData(context),
        borderData: FlBorderData(show: false),
        barGroups: groups,
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
            if (response != null && response.spot != null) {
              if (event is FlTapUpEvent || event is FlPanStartEvent) {
                Haptics.tap();
              }
              if (event is FlTapUpEvent && onPointTap != null) {
                final pt = _getPointForOffset(response.spot!.touchedBarGroup.x.toDouble());
                if (pt != null) onPointTap!(pt);
              }
              if (event is FlLongPressEnd && onPointLongPress != null) {
                final pt = _getPointForOffset(response.spot!.touchedBarGroup.x.toDouble());
                if (pt != null) onPointLongPress!(pt);
              }
            }
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => context.colors.textDark,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (data[group.x].value == null) {
                return null;
              }
              final pt = data[group.x];
              return BarTooltipItem(
                _tooltipText(pt),
                TextStyle(
                  color: context.colors.card,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(BuildContext context) {
    final segments = <List<FlSpot>>[];
    var currentSegment = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      if (d.value != null && d.value!.isFinite) {
        currentSegment.add(FlSpot(i.toDouble(), d.value!));
      } else if (currentSegment.isNotEmpty) {
        segments.add(currentSegment);
        currentSegment = <FlSpot>[];
      }
    }
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }
    
    final spots = segments.expand((s) => s).toList();
    final validVals = spots.map((s) => s.y);
    final (minY, maxY) = validVals.isEmpty ? (0.0, 10.0) : _yRange(validVals);
    final dataYValues = validVals.toList();
    final dataMinY = dataYValues.isNotEmpty ? dataYValues.reduce(min) : 0.0;
    final dataMaxY = dataYValues.isNotEmpty ? dataYValues.reduce(max) : 0.0;
    final maxXValue = _maxXValue;
    final showDots = spots.length <= 14;
    final useCurve = spots.length > 2;
    final primary = context.colors.primary;
    final hasTrend = trendData != null && trendData!.isNotEmpty;

    final lineBars = <LineChartBarData>[
      for (final segment in segments)
        LineChartBarData(
          spots: segment,
          isCurved: timeFormat == ChartTimeFormat.sixMonths 
              ? false 
              : (useCurve && segment.length > 2),
          curveSmoothness: spots.length > 31 ? 0.40 : 0.25,
          preventCurveOverShooting: true, 
          color: hasTrend ? primary.withValues(alpha: 0.2) : primary,
          barWidth: hasTrend 
              ? 0.0 
              : 2.0, 
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, barData) {
              final isIsolated = segment.length == 1;
              if (timeFormat == ChartTimeFormat.sixMonths) {
                return isIsolated || spot.y == dataMinY || spot.y == dataMaxY;
              }
              if (hasTrend) return true;
              return showDots || segment.length == 1;
            },
            getDotPainter: (spot, percent, bar, index) {
              if (timeFormat == ChartTimeFormat.sixMonths && (spot.y == dataMinY || spot.y == dataMaxY)) {
                final isMax = spot.y == dataMaxY;
                return FlDotCirclePainter(
                  radius: 4.5,
                  color: isMax ? context.colors.primary : context.colors.red,
                  strokeWidth: 2,
                  strokeColor: context.colors.card,
                );
              }
              if (hasTrend) {
                return FlDotCirclePainter(
                  radius: 3.0,
                  color: primary.withValues(alpha: 0.3),
                  strokeWidth: 0,
                  strokeColor: Colors.transparent,
                );
              }
              return FlDotCirclePainter(
                radius: 3.5,
                color: primary,
                strokeWidth: 1.5,
                strokeColor: context.colors.card,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: segment.length > 1,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: timeFormat == ChartTimeFormat.sixMonths
                  ? [
                      primary.withValues(alpha: 0.65),
                      primary.withValues(alpha: 0.05),
                    ]
                  : [
                      primary.withValues(alpha: 0.22),
                      primary.withValues(alpha: 0.0),
                    ],
            ),
          ),
        ),
      if (hasTrend)
        LineChartBarData(
          spots: trendData!.asMap().entries.where((e) => e.value.value != null).map((e) => FlSpot(e.key.toDouble(), e.value.value!)).toList(),
          isCurved: true,
          curveSmoothness: 0.3,
          color: primary,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                primary.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxXValue,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: context.colors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        extraLinesData: _buildExtraLines(context, spots: spots),
        titlesData: _titlesData(context),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (response != null &&
                response.lineBarSpots != null &&
                response.lineBarSpots!.isNotEmpty) {
              if (event is FlTapUpEvent || event is FlPanStartEvent) {
                Haptics.tap();
              }
              if (event is FlTapUpEvent && onPointTap != null) {
                final spot = response.lineBarSpots!.first;
                final pt = _getPointForOffset(spot.x);
                if (pt != null) onPointTap!(pt);
              }
              if (event is FlLongPressEnd && onPointLongPress != null) {
                final spot = response.lineBarSpots!.first;
                final pt = _getPointForOffset(spot.x);
                if (pt != null) onPointLongPress!(pt);
              }
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => context.colors.textDark,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isTrend = spot.barIndex == segments.length;
                final prefix = isTrend ? '7-Day Trend\n' : 'Measured\n';
                final pt = isTrend ? trendData![spot.x.toInt()] : data[spot.x.toInt()];
                return LineTooltipItem(
                  '$prefix${_tooltipText(pt)}',
                  TextStyle(
                    color: context.colors.card,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: lineBars,
      ),
    );
  }
}
