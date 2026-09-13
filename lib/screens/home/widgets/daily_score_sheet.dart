import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/surface_card.dart';
import '../../../widgets/section_header.dart';

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

    int percentage = scoreData.totalMax > 0
        ? ((scoreData.totalScore / scoreData.totalMax) * 100).round()
        : 0;

    return AppSheet(
      title: 'Daily Score',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 2.2 Animated Score Card
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: scoreData.totalScore.toDouble(),
              ),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final intScore = value.round();

                int currentPercentage = scoreData.totalMax > 0
                    ? ((intScore / scoreData.totalMax) * 100).round()
                    : 0;

                // Color dynamically shifts during animation
                Color animColor = context.colors.green;
                if (currentPercentage < 50)
                  animColor = context.colors.red;
                else if (currentPercentage < 80)
                  animColor = context.colors.orange;

                return Column(
                  children: [
                    Text(
                      '$intScore',
                      style: AppTheme.numeric(
                        TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          color: intScore == scoreData.totalMax.toInt()
                              ? context.colors.green
                              : animColor,
                          height: 1.0,
                          letterSpacing: -2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'of ${scoreData.totalMax.toInt()}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textMedium,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        value: scoreData.totalMax > 0 ? value / scoreData.totalMax : 0.0,
                        backgroundColor: context.colors.border.withValues(alpha: 0.3),
                        color: intScore == scoreData.totalMax.toInt() ? context.colors.green : animColor,
                        minHeight: 2,
                      ),
                    ),
                  ],
                );
              },
            ),
          ).animate().fade().scale(begin: const Offset(0.95, 0.95)),

          const SizedBox(height: 16),

          // Delta Row
          if (scoreData.yesterdayScore != null ||
              scoreData.sevenDayAverage != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (scoreData.yesterdayScore != null) ...[
                  _DeltaChip(
                    current: scoreData.totalScore,
                    previous: scoreData.yesterdayScore!,
                    label: 'vs yesterday',
                  ),
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                ],
                if (scoreData.sevenDayAverage != null)
                  Text(
                    '7-day avg ${scoreData.sevenDayAverage}',
                    style: AppTheme.numeric(
                      TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textMedium,
                      ),
                    ),
                  ),
              ],
            ).animate().fade(delay: 400.ms),

          const SectionHeader(
            'Score breakdown',
            horizontalPadding: 0,
          ),
          const SizedBox(height: 12),

          // 2.3 Breakdown as progress bars (Staggered)
          SurfaceCard(
            padding: const EdgeInsets.all(12),
            border: null,
            child: Column(
              children: [
                _AnimatedProgressBarRow(
                  label: 'Habits',
                  score: scoreData.habitsScore,
                  max: scoreData.habitsMax,
                  icon: Icons.check_circle_outline_rounded,
                  color: context.colors.primary,
                  onTap: scoreData.remainingLabels.contains('habits')
                      ? () => Navigator.pop(context)
                      : null,
                ).animate().fade(delay: 100.ms).slideX(begin: 0.05),
                const SizedBox(height: 4),
                _AnimatedProgressBarRow(
                  label: 'Workouts',
                  score: scoreData.workoutsScore,
                  max: scoreData.workoutsMax,
                  icon: Icons.fitness_center_rounded,
                  color: context.colors.orange,
                  isRestDay:
                      scoreData.workoutsScore == scoreData.workoutsMax &&
                      scoreData.totalScore > 0 &&
                      ref.watch(workoutPlanProvider) != null,
                  onTap: scoreData.remainingLabels.contains('workout')
                      ? () {
                          Navigator.pop(context);
                          context.go('/workout');
                        }
                      : null,
                ).animate().fade(delay: 180.ms).slideX(begin: 0.05),
                const SizedBox(height: 4),
                _AnimatedProgressBarRow(
                  label: 'Meals',
                  score: scoreData.mealsScore,
                  max: scoreData.mealsMax,
                  icon: Icons.restaurant_rounded,
                  color: context.colors.green,
                  onTap: scoreData.remainingLabels.contains('meals')
                      ? () => Navigator.pop(context)
                      : null,
                ).animate().fade(delay: 260.ms).slideX(begin: 0.05),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 2.3a No categories scheduled state
          if (scoreData.totalMax <= 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.self_improvement_rounded,
                    color: context.colors.textMedium,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No categories scheduled today.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 340.ms),
          ]
          // 2.4 Perfect day state (retained)
          else if (scoreData.remainingLabels.isEmpty && scoreData.totalScore == scoreData.totalMax && scoreData.totalMax > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: context.colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Perfect day — everything done ✨',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 340.ms),
          ],

          const SizedBox(height: 24),

          // 2.5 Footer Disclosure
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'How scoring works',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textMedium,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Score is weighted proportionally based on scheduled categories (Habits up to 50, Workouts up to 30, Meals up to 20).',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textMedium,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
    this.onTap,
  });

  final String label;
  final double score;
  final double max;
  final IconData icon;
  final Color color;
  final bool isRestDay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = max > 0 ? (score / max).clamp(0.0, 1.0) : 0.0;
    final isConfigured = max > 0 || isRestDay;
    final isComplete = max > 0 && score >= max || isRestDay;

    String statusText;
    if (isRestDay) {
      statusText = 'Rest day';
    } else if (max <= 0) {
      statusText = 'Not configured';
    } else {
      statusText = '${score == score.toInt() ? score.toInt().toString() : score.toStringAsFixed(1)} / ${max.toStringAsFixed(0)}';
    }

    return Semantics(
      label: '$label category. $statusText. ${onTap != null ? 'Double tap to open' : ''}',
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: !isConfigured ? 0.5 : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
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
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textDark,
                              ),
                            ),
                            Row(
                              children: [
                                if (isRestDay) ...[
                                  Icon(
                                    Icons.spa_rounded,
                                    color: context.colors.green,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  statusText,
                                  style: AppTheme.numeric(
                                    TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.textMedium,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: isRestDay ? 1.0 : fraction),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, _) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: val,
                                backgroundColor: context.colors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isRestDay ? context.colors.green : color,
                                ),
                                minHeight: 2,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: context.colors.textMedium.withValues(alpha: 0.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
