import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/app_providers.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class JourneyStatsStrip extends ConsumerWidget {
  const JourneyStatsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Collect stats
    final logRepo = ref.watch(dailyLogRepoProvider);
    final badgeRepo = ref.watch(badgeRepoProvider);

    final allLogs = logRepo.getAllLogs();
    final mealRepo = ref.watch(mealRepoProvider);
    final allMealLogs = mealRepo.getAllLogs();
    final earnedBadges = badgeRepo
        .getAllBadges()
        .where((b) => b.isUnlocked)
        .length;

    int totalWorkouts = 0;

    final activeDates = <String>{};
    for (final log in allLogs) {
      if (log.workoutCompleted == true) {
        totalWorkouts++;
      }
      if (log.hasAnyActivity) {
        activeDates.add(log.date);
      }
    }
    for (final mLog in allMealLogs) {
      if (mLog.loggedSlotsCount > 0) {
        activeDates.add(mLog.date);
      }
    }

    final int daysTracked = activeDates.length;
    DateTime? firstTrackedDate;
    if (activeDates.isNotEmpty) {
      final sortedDates = activeDates.toList()..sort();
      firstTrackedDate = DateTime.tryParse(sortedDates.first);
    }

    // Calculate streak
    int currentStreak = 0;
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    bool streakActive = true;
    DateTime ptr = today;

    if (activeDates.isNotEmpty) {
      // Calculate active streak by walking backward from today
      while (streakActive) {
        final dateStr = DateFormat('yyyy-MM-dd').format(ptr);
        if (activeDates.contains(dateStr)) {
          currentStreak++;
          ptr = ptr.subtract(const Duration(days: 1));
        } else {
          // If we are checking today and it's empty, streak might still be maintained by yesterday
          if (dateStr == todayStr) {
            ptr = ptr.subtract(const Duration(days: 1));
          } else {
            streakActive = false;
          }
        }
      }
    }

    final memberSinceStr = firstTrackedDate != null
        ? DateFormat('MMMM yyyy').format(firstTrackedDate)
        : DateFormat('MMMM yyyy').format(DateTime.now());

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Streak',
                value: currentStreak,
                unit: 'Days',
                icon: Icons.local_fire_department_rounded,
                color: context.colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Workouts',
                value: totalWorkouts,
                unit: 'Total',
                icon: Icons.fitness_center_rounded,
                color: context.colors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Tracked',
                value: daysTracked,
                unit: 'Days',
                icon: Icons.calendar_month_rounded,
                color: context.colors.mint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Badges',
                value: earnedBadges,
                unit: 'Earned',
                icon: Icons.military_tech_rounded,
                color: context.colors.pink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Member since $memberSinceStr',
          style: context.text.micro.copyWith(color: context.colors.textMedium),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String title;
  final int value;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Mimic the faded appearance in the screenshot for lower-tier stats when zero
    final bool isZero = value == 0;
    final bool isTopTier = title == 'Streak' || title == 'Workouts';
    final Color effectiveColor = (!isTopTier && isZero)
        ? color.withValues(alpha: 0.3)
        : color;

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final duration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 1200);

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
              Icon(icon, size: 16, color: effectiveColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: context.text.micro.copyWith(color: effectiveColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: value),
                duration: duration,
                curve: Curves.easeOutExpo,
                builder: (context, val, _) {
                  return Text(
                    val.toString(),
                    style: context.text.screenTitle.copyWith(
                      color: context.colors.textDark,
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: context.text.micro.copyWith(
                    color: context.colors.textMedium,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
