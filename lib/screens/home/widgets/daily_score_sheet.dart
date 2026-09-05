import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bottom_sheet.dart';

class DailyScoreSheet extends ConsumerStatefulWidget {
  const DailyScoreSheet({super.key});

  @override
  ConsumerState<DailyScoreSheet> createState() => _DailyScoreSheetState();
}

class _DailyScoreSheetState extends ConsumerState<DailyScoreSheet> {
  @override
  Widget build(BuildContext context) {
    final scoreData = ref.watch(dailyScoreProvider);

    if (scoreData.isFutureDate) {
      return AppSheet(
        title: 'Daily Score',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: Text(
              'Data not available for future dates.',
              style: TextStyle(color: context.colors.textLight, fontSize: 16),
            ),
          ),
        ),
      );
    }

    Color scoreColor = context.colors.green;
    if (scoreData.totalScore < 50) {
      scoreColor = context.colors.red;
    } else if (scoreData.totalScore < 80) {
      scoreColor = context.colors.orange;
    }

    return AppSheet(
      title: 'Daily Score',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 2.2 Animated Score Card
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: scoreData.totalScore.toDouble()),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final intScore = value.round();
                
                // Color dynamically shifts during animation
                Color animColor = context.colors.green;
                if (intScore < 50) animColor = context.colors.red;
                else if (intScore < 80) animColor = context.colors.orange;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                  decoration: BoxDecoration(
                    color: intScore == 100 ? null : animColor.withValues(alpha: 0.1),
                    gradient: intScore == 100 ? context.colors.primaryGradient : null,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$intScore',
                        style: AppTheme.numeric(
                          TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: intScore == 100 ? context.colors.onPrimary : animColor,
                            height: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'of 100',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: intScore == 100 
                            ? context.colors.onPrimary.withValues(alpha: 0.8) 
                            : animColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ).animate().fade().scale(begin: const Offset(0.9, 0.9)),
          
          const SizedBox(height: 16),
          
          // Delta Row
          if (scoreData.yesterdayScore != null || scoreData.sevenDayAverage != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (scoreData.yesterdayScore != null) ...[
                  _DeltaChip(
                    current: scoreData.totalScore,
                    previous: scoreData.yesterdayScore!,
                    label: 'vs yesterday',
                  ),
                  if (scoreData.sevenDayAverage != null) const SizedBox(width: 12),
                ],
                if (scoreData.sevenDayAverage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.border.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '7-day avg ${scoreData.sevenDayAverage}',
                      style: AppTheme.numeric(
                        TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textMedium,
                        ),
                      ),
                    ),
                  ),
              ],
            ).animate().fade(delay: 400.ms),

          const SizedBox(height: 32),
          Text(
            'Score Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.colors.textDark,
            ),
          ),
          const SizedBox(height: 16),

          // 2.3 Breakdown as progress bars (Staggered)
          _AnimatedProgressBarRow(
            label: 'Habits',
            score: scoreData.habitsScore,
            max: scoreData.habitsMax,
            icon: Icons.check_circle_outline_rounded,
            color: context.colors.primary,
          ).animate().fade(delay: 100.ms).slideX(begin: 0.05),
          
          const SizedBox(height: 16),
          
          _AnimatedProgressBarRow(
            label: 'Workouts',
            score: scoreData.workoutsScore,
            max: scoreData.workoutsMax,
            icon: Icons.fitness_center_rounded,
            color: context.colors.orange,
            isRestDay: scoreData.workoutsScore == scoreData.workoutsMax && scoreData.totalScore > 0 && ref.watch(workoutPlanProvider) != null,
          ).animate().fade(delay: 180.ms).slideX(begin: 0.05),
          
          const SizedBox(height: 16),
          
          _AnimatedProgressBarRow(
            label: 'Meals',
            score: scoreData.mealsScore,
            max: scoreData.mealsMax,
            icon: Icons.restaurant_rounded,
            color: context.colors.green,
          ).animate().fade(delay: 260.ms).slideX(begin: 0.05),

          const SizedBox(height: 32),

          // 2.4 "What's left" actionable row
          if (scoreData.remainingLabels.isNotEmpty) ...[
            Text(
              'Still to do',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.colors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: scoreData.remainingLabels.map((label) {
                return ActionChip(
                  label: Text(label.toUpperCase()),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.colors.primary,
                  ),
                  backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () {
                    Navigator.pop(context);
                    if (label == 'workout') {
                      context.go('/workout');
                    }
                  },
                );
              }).toList(),
            ).animate().fade(delay: 340.ms),
          ] else if (scoreData.totalScore == 100) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: context.colors.green, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Perfect day — everything done ✨',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.green,
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 340.ms),
          ],

          const SizedBox(height: 32),

          // 2.5 Footer
          Text(
            'Habits 50 · Workout 30 · Meals 20 — meals include an accuracy bonus.',
            style: TextStyle(
              fontSize: 12,
              color: context.colors.textLight,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
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
    final icon = isPositive ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          Text(
            '${diff.abs()} $label',
            style: AppTheme.numeric(
              TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedProgressBarRow extends StatelessWidget {
  const _AnimatedProgressBarRow({
    required this.label,
    required this.score,
    required this.max,
    required this.icon,
    required this.color,
    this.isRestDay = false,
  });

  final String label;
  final double score;
  final double max;
  final IconData icon;
  final Color color;
  final bool isRestDay;

  @override
  Widget build(BuildContext context) {
    final fraction = max > 0 ? (score / max).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textDark,
                    ),
                  ),
                  if (isRestDay)
                    Row(
                      children: [
                        Text(
                          'Rest day',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colors.green,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.spa_rounded, color: context.colors.green, size: 12),
                      ],
                    )
                  else
                    Text(
                      '${score == score.toInt() ? score.toInt().toString() : score.toStringAsFixed(1)} / ${max.toStringAsFixed(0)}',
                      style: AppTheme.numeric(
                        TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textMedium,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: isRestDay ? 1.0 : fraction),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, val, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: val,
                      backgroundColor: context.colors.border.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isRestDay ? context.colors.green : color,
                      ),
                      minHeight: 6,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
