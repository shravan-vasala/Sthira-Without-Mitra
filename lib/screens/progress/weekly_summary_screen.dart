import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../providers/weekly_summary_provider.dart';
import '../../providers/app_providers.dart';
import '../../share/share_card_exporter.dart';
import '../../share/weekly_share_layout.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class WeeklySummaryScreen extends ConsumerWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(weeklySummaryProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    // Get week bounds for title
    final weekday = selectedDate.weekday;
    final startOfWeek = selectedDate.subtract(Duration(days: weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final titleText =
        '${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}';

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Weekly Progress',
          style: context.text.screenTitle.copyWith(color: context.colors.textDark),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.colors.textDark),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                titleText,
                style: context.text.body.copyWith(color: context.colors.textMedium),
                textAlign: TextAlign.center,
              ).animate().fade().slideY(begin: -0.2),

              const SizedBox(height: 32),

              // 3.1 Animated Score Card Hero
              _ScoreHeroCard(
                    score: summary.weekScore,
                    prevScore: summary.previousWeekScore,
                    dailyScores: summary.dailyScores,
                  )
                  .animate()
                  .fade(delay: 100.ms)
                  .scale(begin: const Offset(0.95, 0.95)),

              const SizedBox(height: 24),

              // 3.4 Insights Strip
              _InsightsStrip(summary: summary).animate().fade(delay: 200.ms),

              const SizedBox(height: 32),

              // 3.2 Daily Scores Chart
              _DailyScoresChartCard(
                dailyScores: summary.dailyScores,
                startOfWeek: startOfWeek,
              ).animate().fade(delay: 300.ms).slideY(begin: 0.1),

              const SizedBox(height: 16),

              // Secondary Habit Chart
              if (summary.habitCompletionRate > 0)
                _HabitChartCard(
                  rates: summary.dailyHabitRates,
                  totals: summary.dailyHabitsTotal,
                  startOfWeek: startOfWeek,
                ).animate().fade(delay: 400.ms).slideY(begin: 0.1),

              const SizedBox(height: 32),

              Text(
                'STATS OVERVIEW',
                style: context.text.caption.copyWith(color: context.colors.textMedium),
              ).animate().fade(delay: 500.ms),
              const SizedBox(height: 16),

              // 3.3 Grid Stats with Trend Deltas
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.05,
                children:
                    [
                          _StatCard(
                            title: 'Workouts',
                            icon: Icons.fitness_center_rounded,
                            primaryValue:
                                '${summary.workoutsCompleted}/${summary.workoutsTotal}',
                            subtitle: 'Sessions',
                            trendValue: _calculateTrendInt(
                              summary.workoutsCompleted,
                              summary.prevWorkoutsCompleted,
                            ),
                          ),
                          _StatCard(
                            title: 'Habits',
                            icon: Icons.checklist_rounded,
                            numericValue: summary.habitCompletionRate * 100,
                            unit: '%',
                            subtitle: 'Completion',
                            trendValue: _calculateTrendDouble(
                              summary.habitCompletionRate,
                              summary.prevHabitCompletionRate,
                              isPercent: true,
                            ),
                          ),
                          _StatCard(
                            title: 'Steps',
                            icon: Icons.directions_walk_rounded,
                            numericValue: summary.avgSteps.toDouble(),
                            subtitle: 'Avg / day',
                            trendValue: _calculateTrendInt(
                              summary.avgSteps,
                              summary.prevAvgSteps,
                            ),
                          ),
                          _StatCard(
                            title: 'Sleep',
                            icon: Icons.nightlight_round,
                            numericValue: summary.avgSleep,
                            unit: 'h',
                            decimals: 1,
                            subtitle: 'Avg / night',
                            trendValue: _calculateTrendDouble(
                              summary.avgSleep,
                              summary.prevAvgSleep,
                            ),
                          ),
                          _StatCard(
                            title: 'Nutrition',
                            icon: Icons.local_fire_department_rounded,
                            numericValue: summary.avgCalories.toDouble(),
                            subtitle: 'Avg kcal / day',
                            trendValue: _calculateTrendInt(
                              summary.avgCalories,
                              summary.prevAvgCalories,
                              invertGoodness: true,
                            ),
                          ),
                          _StatCard(
                            title: 'Weight',
                            icon: Icons.monitor_weight_rounded,
                            primaryValue: summary.weightDelta != 0
                                ? (summary.weightDelta > 0
                                      ? '+${summary.weightDelta.toStringAsFixed(1)}'
                                      : summary.weightDelta.toStringAsFixed(1))
                                : '-',
                            subtitle: 'Delta this week',
                            trendValue: _calculateTrendDouble(
                              summary.weightDelta,
                              summary.prevWeightDelta,
                              invertGoodness: true,
                            ),
                          ),
                        ]
                        .animate(interval: 50.ms)
                        .fade(delay: 600.ms)
                        .scale(begin: const Offset(0.9, 0.9)),
              ),
              const SizedBox(height: 40),
              // Share Section
              _WeeklyShareSection(
                summary: summary,
                titleText: titleText,
              ).animate().fade(delay: 800.ms),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String? _calculateTrendInt(
    int current,
    int? prev, {
    bool invertGoodness = false,
  }) {
    if (prev == null || prev == 0) return null;
    final diff = current - prev;
    if (diff == 0) return null;
    final sign = diff > 0 ? '+' : '';
    return '$sign$diff';
  }

  String? _calculateTrendDouble(
    double current,
    double? prev, {
    bool isPercent = false,
    bool invertGoodness = false,
  }) {
    if (prev == null || prev == 0) return null;
    final diff = current - prev;
    if (diff.abs() < 0.1) return null; // Too small to care
    final sign = diff > 0 ? '+' : '';
    if (isPercent) {
      return '$sign${(diff * 100).toInt()}%';
    }
    return '$sign${diff.toStringAsFixed(1)}';
  }
}

class _ScoreHeroCard extends StatelessWidget {
  final int score;
  final int? prevScore;
  final List<int?> dailyScores;

  const _ScoreHeroCard({
    required this.score,
    required this.prevScore,
    required this.dailyScores,
  });

  @override
  Widget build(BuildContext context) {
    String message;
    if (score >= 90) {
      message = 'Crushing it!';
    } else if (score >= 70) {
      message = 'Great week!';
    } else if (score >= 50) {
      message = 'Good effort!';
    } else {
      message = 'Room to grow';
    }

    // Check for perfect week (all elapsed days >= 80)
    int elapsedDays = 0;
    int daysOver80 = 0;
    for (var s in dailyScores) {
      if (s != null) {
        elapsedDays++;
        if (s >= 80) daysOver80++;
      }
    }
    final isPerfectWeek = elapsedDays > 0 && daysOver80 == elapsedDays;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          if (isPerfectWeek)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'PERFECT WEEK ✨',
                style: context.text.micro.copyWith(color: context.colors.onPrimary),
              ),
            )
          else
            Text(
              'Week Score',
              style: context.text.body.copyWith(color: context.colors.textMedium),
            ),

          const SizedBox(height: 12),

          Builder(
            builder: (context) {
              final intScore = score;
              Color scoreColor = context.colors.green;
              if (intScore < 50) {
                scoreColor = context.colors.red;
              } else if (intScore < 80)
                scoreColor = context.colors.orange;

              if (isPerfectWeek) scoreColor = context.colors.green; // override

              return Column(
                children: [
                  Text(
                    '$intScore',
                    style: AppTheme.numeric(
                      context.text.metric.copyWith(color: scoreColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: context.text.cardTitle.copyWith(color: context.colors.textDark),
                  ),
                ],
              );
            },
          ),

          if (prevScore != null) ...[
            const SizedBox(height: 20),
            _DeltaChip(
              current: score,
              previous: prevScore!,
              label: 'vs last week',
            ),
          ],
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.current,
    required this.previous,
    required this.label,
  });

  final int current;
  final int previous;
  final String label;

  @override
  Widget build(BuildContext context) {
    final diff = current - previous;
    if (diff == 0) return const SizedBox.shrink();

    final isPositive = diff > 0;
    final color = isPositive ? context.colors.green : context.colors.red;
    final icon = isPositive
        ? Icons.arrow_drop_up_rounded
        : Icons.arrow_drop_down_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          Text(
            '${diff.abs()} $label',
            style: AppTheme.numeric(
              context.text.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsStrip extends StatelessWidget {
  final WeeklySummary summary;
  const _InsightsStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final insights = <String>[];

    if (summary.habitCompletionRate > 0.8) {
      insights.add("Incredible consistency with habits.");
    } else if (summary.habitCompletionRate < 0.4 && summary.workoutsTotal > 0) {
      insights.add("Habits need a little more focus.");
    }

    if (summary.workoutsCompleted == summary.workoutsTotal &&
        summary.workoutsTotal > 0) {
      insights.add("Hit every planned workout!");
    }

    if (summary.nightsUnder7h == 0 && summary.avgSleep >= 7) {
      insights.add("Excellent sleep hygiene.");
    }

    if (insights.isEmpty) {
      insights.add("Keep building your steady aura.");
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.lavender.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: context.colors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insights.first,
              style: context.text.caption.copyWith(color: context.colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyScoresChartCard extends ConsumerWidget {
  final List<int?> dailyScores;
  final DateTime startOfWeek;
  const _DailyScoresChartCard({
    required this.dailyScores,
    required this.startOfWeek,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: context.colors.textDark,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'DAILY SCORES',
                style: context.text.caption.copyWith(color: context.colors.textMedium),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (!event.isInterestedForInteractions ||
                        barTouchResponse == null ||
                        barTouchResponse.spot == null) {
                      return;
                    }
                    if (event is FlTapUpEvent) {
                      final index = barTouchResponse.spot!.touchedBarGroupIndex;
                      final d = startOfWeek.add(Duration(days: index));
                      if (d.isBefore(DateTime.now()) ||
                          d.isAtSameMomentAs(DateTime.now())) {
                        ref.read(selectedDateProvider.notifier).state = d;
                        context.pop();
                      }
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i > 6) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[i],
                            style: context.text.micro.copyWith(color: context.colors.textMedium),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final score = dailyScores[i];
                  Color barColor = context.colors.border; // Future
                  if (score != null) {
                    barColor = context.colors.green;
                    if (score < 50) {
                      barColor = context.colors.red;
                    } else if (score < 80)
                      barColor = context.colors.orange;
                  }

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (score ?? 0).toDouble(),
                        color: barColor,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 100,
                          color: context.colors.border.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitChartCard extends StatelessWidget {
  final List<double> rates;
  final List<int> totals;
  final DateTime startOfWeek;
  const _HabitChartCard({required this.rates, required this.totals, required this.startOfWeek});

  @override
  Widget build(BuildContext context) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: context.colors.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'HABIT COMPLETION',
                style: context.text.caption.copyWith(color: context.colors.textMedium),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 80,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.0,
                minY: 0,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i > 6) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[i],
                            style: context.text.micro.copyWith(color: context.colors.textMedium),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final d = startOfWeek.add(Duration(days: i));
                  final isFuture = d.isAfter(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
                  final isUnscheduled = totals[i] == 0;
                  
                  final barColor = (isFuture || isUnscheduled) 
                      ? context.colors.border 
                      : context.colors.primary;
                      
                  final backColor = (isFuture || isUnscheduled)
                      ? context.colors.border.withValues(alpha: 0.1)
                      : context.colors.primary.withValues(alpha: 0.1);

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: rates[i],
                        color: barColor,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 1.0,
                          color: backColor,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? primaryValue;
  final double? numericValue;
  final String? unit;
  final int decimals;
  final String subtitle;
  final String? trendValue;

  const _StatCard({
    required this.title,
    required this.icon,
    this.primaryValue,
    this.numericValue,
    this.unit,
    this.decimals = 0,
    required this.subtitle,
    this.trendValue,
  });

  @override
  Widget build(BuildContext context) {
    // Determine trend color
    Color? trendColor;
    if (trendValue != null) {
      if (trendValue!.startsWith('+')) {
        trendColor = context.colors.green;
        // Invert for weight or calories
        if (title == 'Weight' || title == 'Nutrition') {
          trendColor = context.colors.red;
        }
      } else if (trendValue!.startsWith('-')) {
        trendColor = context.colors.red;
        if (title == 'Weight' || title == 'Nutrition') {
          trendColor = context.colors.green;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.colors.lavender,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: context.colors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: context.text.caption.copyWith(color: context.colors.textMedium),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (numericValue != null) 
                Builder(
                  builder: (context) {
                    final display = '${numericValue!.toStringAsFixed(decimals)}${unit ?? ''}';
                    return Text(
                      display,
                      style: AppTheme.numeric(
                        context.text.screenTitle.copyWith(color: context.colors.textDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                )
              else
                Text(
                  primaryValue ?? '',
                  style: AppTheme.numeric(
                    context.text.screenTitle.copyWith(color: context.colors.textDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (trendValue != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: Text(
                    trendValue!,
                    style: AppTheme.numeric(
                      context.text.micro.copyWith(color: trendColor ?? context.colors.textMedium),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: context.text.micro.copyWith(color: context.colors.textLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _WeeklyShareSection extends ConsumerStatefulWidget {
  final WeeklySummary summary;
  final String titleText;

  const _WeeklyShareSection({
    required this.summary,
    required this.titleText,
  });

  @override
  ConsumerState<_WeeklyShareSection> createState() => _WeeklyShareSectionState();
}

class _WeeklyShareSectionState extends ConsumerState<_WeeklyShareSection> {
  bool _isSharing = false;

  void _shareImage(BuildContext context, WeeklySummary summary, String title, String name) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    
    try {
      Color baseColor = context.colors.green;
      if (summary.weekScore < 50) {
        baseColor = context.colors.red;
      } else if (summary.weekScore < 80) baseColor = context.colors.orange;
      
      final layout = WeeklyShareLayout(
        format: ShareFormat.post,
        userName: name,
        dateRange: title,
        weekScore: summary.weekScore,
        prevWeekScore: summary.previousWeekScore,
        dailyScores: summary.dailyScores,
        workoutsCompleted: summary.workoutsCompleted,
        workoutsTotal: summary.workoutsTotal,
        avgSteps: summary.avgSteps,
        habitCompletionPercent: (summary.habitCompletionRate * 100).toInt(),
        baseColor: baseColor,
      );

      final success = await ShareCardExporter.exportAndShareWidget(
        context: context,
        widget: layout,
        fileName: 'sthira_weekly_summary',
        text: summary.generateShareText(),
        format: ShareFormat.post,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Weekly summary shared successfully!')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(profileProvider).name;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isSharing ? null : () => _shareImage(context, widget.summary, widget.titleText, name),
          icon: _isSharing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.ios_share_rounded),
          label: Text(_isSharing ? 'Generating...' : 'Share Summary Image'),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: context.colors.onPrimary,
            elevation: 4,
            shadowColor: context.colors.primary.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            final text = widget.summary.generateShareText();
            // ignore: deprecated_member_use
            Share.share(text);
          },
          child: Text(
            'Share as text',
            style: context.text.body.copyWith(color: context.colors.textMedium),
          ),
        ),
      ],
    );
  }
}
