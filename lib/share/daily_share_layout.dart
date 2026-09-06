import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import 'share_card_exporter.dart';

class DailyShareLayout extends StatelessWidget {
  final ShareFormat format;
  final String userName;
  final int score;
  final String subtitle;
  final int steps;
  final int mealsKcal;
  final bool workoutDone;
  final String habitsDone;
  final Color baseColor;

  const DailyShareLayout({
    super.key,
    required this.format,
    required this.userName,
    required this.score,
    required this.subtitle,
    required this.steps,
    required this.mealsKcal,
    required this.workoutDone,
    required this.habitsDone,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    // Sthira Export Layout: Opaque background covering edge to edge
    final isStory = format == ShareFormat.story;
    final topPadding = isStory ? 80.0 : 40.0;
    final bottomPadding = isStory ? 80.0 : 40.0;

    return Container(
      color: AppColors.dark.surface, // Sthira Dark Surface
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          // Radial aura backgrounds for premium aesthetic
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
                      style: TextStyle(
                        color: AppColors.dark.textMedium,
                        fontFamily: 'Cabinet Grotesk',
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d').format(DateTime.now()),
                      style: TextStyle(
                        color: AppColors.dark.textMedium,
                        fontFamily: 'General Sans',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isStory ? 60 : 32),

                // Greeting Row clamped to 1 line
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "$userName's Day",
                    style: TextStyle(
                      color: AppColors.dark.textDark,
                      fontFamily: 'Cabinet Grotesk',
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Hero Score
                Center(
                  child: Container(
                    width: isStory ? 220 : 180,
                    height: isStory ? 220 : 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: baseColor.withValues(alpha: 0.4),
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$score',
                        style: TextStyle(
                          color: baseColor,
                          fontFamily: 'Cabinet Grotesk',
                          fontSize: isStory ? 100 : 84,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.dark.textDark,
                      fontFamily: 'General Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const Spacer(),

                // 2x2 Stats Grid
                _StatsGrid(
                  steps: steps,
                  mealsKcal: mealsKcal,
                  workoutDone: workoutDone,
                  habitsDone: habitsDone,
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
                      style: TextStyle(
                        color: AppColors.dark.textLight,
                        fontFamily: 'General Sans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
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

class _StatsGrid extends StatelessWidget {
  final int steps;
  final int mealsKcal;
  final bool workoutDone;
  final String habitsDone;

  const _StatsGrid({
    required this.steps,
    required this.mealsKcal,
    required this.workoutDone,
    required this.habitsDone,
  });

  @override
  Widget build(BuildContext context) {
    // Only show valid targets
    final List<Widget> cards = [];
    
    if (steps > 0) {
      cards.add(_StatCard(
        icon: Icons.directions_walk_rounded,
        label: 'Steps',
        value: NumberFormat.decimalPattern().format(steps),
      ));
    }
    if (mealsKcal > 0) {
      cards.add(_StatCard(
        icon: Icons.restaurant_rounded,
        label: 'Meals',
        value: '$mealsKcal kcal',
      ));
    }
    if (workoutDone) {
      cards.add(const _StatCard(
        icon: Icons.fitness_center_rounded,
        label: 'Workout',
        value: 'Done',
      ));
    }
    cards.add(_StatCard(
      icon: Icons.checklist_rounded,
      label: 'Habits',
      value: habitsDone,
    ));

    // Reflow depending on count
    if (cards.length <= 2) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList(),
      );
    }
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards.length > 1 ? cards[1] : const SizedBox.shrink()),
          ],
        ),
        if (cards.length > 2) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards.length > 3 ? cards[3] : const SizedBox.shrink()),
            ],
          ),
        ]
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.dark.scaffoldBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.dark.textMedium.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.dark.textMedium, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: AppColors.dark.textDark,
              fontFamily: 'Cabinet Grotesk',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: AppColors.dark.textMedium,
              fontFamily: 'General Sans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
