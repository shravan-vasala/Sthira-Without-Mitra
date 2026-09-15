import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'share_card_exporter.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class WeeklyShareLayout extends StatelessWidget {
  final ShareFormat format;
  final String userName;
  final String dateRange;
  final int weekScore;
  final int? prevWeekScore;
  final List<int?> dailyScores;
  final int workoutsCompleted;
  final int workoutsTotal;
  final int avgSteps;
  final int habitCompletionPercent;
  final Color baseColor;

  const WeeklyShareLayout({
    super.key,
    required this.format,
    required this.userName,
    required this.dateRange,
    required this.weekScore,
    required this.prevWeekScore,
    required this.dailyScores,
    required this.workoutsCompleted,
    required this.workoutsTotal,
    required this.avgSteps,
    required this.habitCompletionPercent,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    final isStory = format == ShareFormat.story;
    final topPadding = isStory ? 80.0 : 40.0;
    final bottomPadding = isStory ? 80.0 : 40.0;

    return Container(
      color: AppColors.dark.surface,
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          // Radial aura backgrounds
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.dark.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.dark.primary.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          Padding(
            padding: EdgeInsets.only(
              left: 28,
              right: 28,
              top: topPadding,
              bottom: bottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STHIRA',
                      style: context.text.micro.copyWith(color: AppColors.dark.textMedium),
                    ),
                    Text(
                      dateRange,
                      style: context.text.caption.copyWith(color: AppColors.dark.textMedium),
                    ),
                  ],
                ),
                SizedBox(height: isStory ? 50 : 24),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "$userName's Week",
                    style: context.text.metric.copyWith(color: AppColors.dark.textDark),
                  ),
                ),
                
                const Spacer(),
                
                // Hero Score Block
                Center(
                  child: Column(
                    children: [
                      Text(
                        '$weekScore',
                        style: context.text.body.copyWith(color: baseColor),
                      ),
                      if (prevWeekScore != null && prevWeekScore != weekScore) ...[
                        const SizedBox(height: 12),
                        _DeltaChip(
                          current: weekScore,
                          previous: prevWeekScore!,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: isStory ? 40 : 24),

                // 7-day Mini Chart
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.dark.scaffoldBg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1.0,
                    ),
                  ),
                  child: _MiniChart(dailyScores: dailyScores),
                ),

                const Spacer(),

                // Weekly Stats
                Row(
                  children: [
                    Expanded(
                      child: _WeeklyStatBox(
                        icon: Icons.fitness_center_rounded,
                        label: 'Workouts',
                        value: '$workoutsCompleted/$workoutsTotal',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _WeeklyStatBox(
                        icon: Icons.directions_walk_rounded,
                        label: 'Avg Steps',
                        value: avgSteps > 0 ? '${(avgSteps / 1000).toStringAsFixed(1)}k' : '-',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _WeeklyStatBox(
                        icon: Icons.checklist_rounded,
                        label: 'Habits',
                        value: '$habitCompletionPercent%',
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isStory ? 40 : 24),
                
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.dark.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tracked with Sthira',
                      style: context.text.caption.copyWith(color: AppColors.dark.textLight),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final int current;
  final int previous;

  const _DeltaChip({required this.current, required this.previous});

  @override
  Widget build(BuildContext context) {
    final diff = current - previous;
    final isPositive = diff > 0;
    final color = isPositive ? AppColors.dark.green : AppColors.dark.red;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, 
            color: color, 
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '${diff.abs()} pts',
            style: context.text.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  final List<int?> dailyScores;
  
  const _MiniChart({required this.dailyScores});

  @override
  Widget build(BuildContext context) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final score = i < dailyScores.length ? dailyScores[i] : null;
        final heightRatio = score == null ? 0.0 : (score / 100.0).clamp(0.0, 1.0);
        
        Color barColor = AppColors.dark.border;
        if (score != null) {
          barColor = AppColors.dark.green;
          if (score < 50) {
            barColor = AppColors.dark.red;
          } else if (score < 80) barColor = AppColors.dark.orange;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.dark.border.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 16,
                height: 60 * heightRatio,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              days[i],
              style: context.text.micro.copyWith(color: AppColors.dark.textMedium),
            ),
          ],
        );
      }),
    );
  }
}

class _WeeklyStatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeeklyStatBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dark.scaffoldBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.dark.textMedium, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: context.text.cardTitle.copyWith(color: AppColors.dark.textDark),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.text.micro.copyWith(color: AppColors.dark.textMedium),
          ),
        ],
      ),
    );
  }
}
