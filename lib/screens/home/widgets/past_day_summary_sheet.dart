import 'package:trufit_bodamma/theme/app_typography.dart';
import 'package:trufit_bodamma/theme/app_colors.dart';
import 'package:trufit_bodamma/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../providers/app_providers.dart';
import '../../../models/habit.dart';
import '../../../router/app_router.dart';
import '../../../utils/workout_completion.dart';
import '../../../utils/meal_icons.dart';
import '../../../models/daily_stats_snapshot.dart';
import '../../../widgets/app_bottom_sheet.dart';
import 'day_feeling_card.dart';

class PastDaySummarySheet extends ConsumerWidget {
  final DateTime date;

  const PastDaySummarySheet({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Watch trigger for reactivity on updates
    ref.watch(dailyLogProvider);
    ref.watch(habitCompletionsProvider);
    ref.watch(dailyLogsUpdateProvider);
    ref.watch(dailyMealLogProvider);
    ref.watch(exerciseLogsUpdateProvider);

    // Synchronous reads from repos
    final dailyLog = ref.read(dailyLogRepoProvider).getOrCreate(dateStr);
    final mealLog = ref.read(mealRepoProvider).getDailyLog(dateStr);
    final allHabits = ref.read(habitRepoProvider).getHabits();
    final habitCompletions = ref
        .read(habitRepoProvider)
        .getCompletions(dateStr);

    final applicableHabits = allHabits.where((h) {
      final habitDate = DateTime(
        h.createdAt.year,
        h.createdAt.month,
        h.createdAt.day,
      );
      final sDate = DateTime(date.year, date.month, date.day);
      return !habitDate.isAfter(sDate);
    }).toList();

    final workoutPlan = ref.read(workoutPlanProvider);
    final mealPlan = ref.read(mealPlanProvider);
    final profile = ref.read(profileProvider);
    final logRepo = ref.read(exerciseLogRepoProvider);
    final dailyLogRepo = ref.read(dailyLogRepoProvider);

    final stats = DailyStatsSnapshot.compute(
      date: date,
      dateStr: dateStr,
      habits: applicableHabits,
      habitCompletions: habitCompletions,
      dailyLog: dailyLog,
      workoutPlan: workoutPlan,
      hasLog: (d, e) => logRepo.hasLog(d, e),
      mealPlan: mealPlan,
      mealLog: mealLog,
      targetWeight: profile.targetWeight ?? 0,
      dailyLogRepo: dailyLogRepo,
      profile: profile,
    );

    // 1) Compute workout status for UI
    String workoutDayName = "Rest Day";
    String? currentWorkoutDayId;

    if (workoutPlan != null && workoutPlan.days.isNotEmpty) {
      final workoutDay = WorkoutCompletion.resolveWorkoutDay(workoutPlan, date);
      if (!stats.isRestDay) {
        workoutDayName = workoutDay.label ?? 'Workout Day';
        currentWorkoutDayId = dailyLog.workoutDayId ?? workoutDay.dayId;
      }
    }

    // 2) Compute totals
    final loggedIds = mealLog.customSlots.keys.toSet();
    final List<IconData> loggedIcons = [];
    for (final slotId in loggedIds) {
      final log = mealLog.customSlots[slotId];
      if (log != null &&
          (log.items.isNotEmpty ||
              log.photoPath != null ||
              log.totalCalories > 0)) {
        if (log.emoji != null) {
          loggedIcons.add(MealIcons.resolve(log.emoji));
        } else {
          final profileSlot = profile.customMealSlots.firstWhere(
            (s) => s['id'] == slotId,
            orElse: () => <String, dynamic>{},
          );
          if (profileSlot.isNotEmpty) {
            loggedIcons.add(MealIcons.resolve(profileSlot['emoji'] as String?));
          }
        }
      }
    }

    final completedMeals = stats.mealsLogged;
    final totalMealsTarget = stats.mealsTotal;
    final completedHabits = stats.habitsDone;
    final totalHabitsTarget = stats.habitsTotal;
    final isRestDay = stats.isRestDay;
    final workoutDayDone = stats.workoutsDone >= stats.workoutsTotal;

    final totalThings = totalMealsTarget + totalHabitsTarget + (isRestDay ? 0 : 1);
    final totalDone = completedMeals + completedHabits + (isRestDay ? 0 : (workoutDayDone ? 1 : 0));

    // 3) Status pill logic
    String statusText = "Nothing logged";
    Color statusColor = context.colors.red;
    if (totalDone == 0) {
      if (isRestDay) {
        statusText = "Rest day";
        statusColor = context.colors.textMedium;
      }
    } else if (totalDone >= (totalThings * 0.75).round()) {
      statusText = "Great day";
      statusColor = context.colors.green;
    } else {
      statusText = "Partial";
      statusColor = context.colors.orange;
    }

    final missedHabits = applicableHabits
        .where((h) => !isHabitCompleted(h, habitCompletions, dailyLog))
        .map((h) => h.name)
        .join(', ');

    Habit? waterHabit;
    try {
      waterHabit = allHabits.firstWhere((h) => h.id == 'water');
    } catch (_) {}

    return AppSheet(
      title: DateFormat('EEE, dd MMM').format(date),
      subtitle: '$totalDone of $totalThings things completed',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: context.text.caption.copyWith(color: statusColor),
              ),
            ),
          ),
          const SizedBox(height: Spacing.section),

            // Rows
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Workout Row
                  _SummaryRow(
                    icon: Icons.fitness_center_rounded,
                    color: context.colors.primary,
                    titleWidget: Text(
                      workoutDayName,
                      style: context.text.bodyStrong.copyWith(color: context.colors.textDark),
                    ),
                    subtitle: isRestDay
                        ? 'Recovery day'
                        : '${stats.workoutsDone}/${stats.workoutsTotal} exercises done',
                    isDone: workoutDayDone,
                    onTap: () {
                      if (isRestDay || currentWorkoutDayId == null) return;
                      ref.read(selectedDateProvider.notifier).state = date;
                      final parentContext = rootNavigatorKey.currentContext!;
                      Navigator.of(context).pop();
                      parentContext.go('/home/workout/$currentWorkoutDayId');
                    },
                  ),
                  const SizedBox(height: Spacing.stack),

                  // Meals Row
                  _SummaryRow(
                    icon: Icons.restaurant_rounded,
                    color: context.colors.green,
                    titleWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (loggedIcons.isNotEmpty)
                          ...loggedIcons.map(
                            (ic) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                ic,
                                size: 16,
                                color: context.colors.textDark,
                              ),
                            ),
                          ),
                        if (loggedIcons.isNotEmpty)
                          Text(
                            '· ',
                            style: context.text.bodyStrong.copyWith(color: context.colors.textDark),
                          ),
                        Text(
                          '$completedMeals/$totalMealsTarget logged · ${mealLog.totalCalories} / ${profile.targetCalories} kcal',
                          style: context.text.bodyStrong.copyWith(color: context.colors.textDark),
                        ),
                      ],
                    ),
                    subtitle:
                        'P: ${mealLog.totalProtein}g   C: ${mealLog.totalCarbs}g   F: ${mealLog.totalFat}g',
                    isDone: completedMeals == totalMealsTarget,
                    onTap: () {
                      ref.read(selectedDateProvider.notifier).state = date;
                      final parentContext = rootNavigatorKey.currentContext!;
                      Navigator.of(context).pop();
                      parentContext.go('/home/meals');
                    },
                  ),
                  const SizedBox(height: Spacing.stack),

                  // Habits Row
                  _SummaryRow(
                    icon: Icons.checklist_rounded,
                    color: context.colors.primary,
                    titleWidget: Text(
                      'Habits ($completedHabits/$totalHabitsTarget)',
                      style: context.text.bodyStrong.copyWith(color: context.colors.textDark),
                    ),
                    subtitle: missedHabits.isNotEmpty
                        ? 'Missed: $missedHabits'
                        : 'All habits completed!',
                    isDone: completedHabits == totalHabitsTarget,
                    onTap: () {
                      ref.read(selectedDateProvider.notifier).state = date;
                      final parentContext = rootNavigatorKey.currentContext!;
                      Navigator.of(context).pop();
                      parentContext.go('/home');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.section),

            // Day Feeling Reflection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DayFeelingCard(
                dateStr: dateStr,
                initialFeeling: dailyLog.dayFeeling,
                initialNote: dailyLog.dayNote,
              ),
            ),
            const SizedBox(height: Spacing.section),

            // Metrics 2x2 Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _MetricBox(
                      icon: Icons.directions_walk_rounded,
                      label: 'Steps',
                      value: '${dailyLog.steps ?? 0}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricBox(
                      icon: Icons.bedtime_rounded,
                      label: 'Sleep',
                      value: dailyLog.sleepHours != null
                          ? '${dailyLog.sleepHours}h'
                          : '—',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _MetricBox(
                      icon: Icons.monitor_weight_rounded,
                      label: 'Weight',
                      value: dailyLog.weight != null
                          ? '${dailyLog.weight} kg'
                          : '—',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricBox(
                      icon: Icons.water_drop_rounded,
                      label: 'Water',
                      value: waterHabit == null
                          ? '—'
                          : (isHabitCompleted(
                                  waterHabit,
                                  habitCompletions,
                                  dailyLog,
                                )
                                ? 'Done · ${waterHabit.target == waterHabit.target.roundToDouble() ? waterHabit.target.toInt() : waterHabit.target} ${waterHabit.unit.isNotEmpty ? waterHabit.unit : 'L'}'
                                : 'Goal ${waterHabit.target == waterHabit.target.roundToDouble() ? waterHabit.target.toInt() : waterHabit.target} ${waterHabit.unit.isNotEmpty ? waterHabit.unit : 'L'}'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.major),

            // Action Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    ref.read(selectedDateProvider.notifier).state = date;
                    final parentContext = rootNavigatorKey.currentContext!;
                    Navigator.of(context).pop();
                    parentContext.go('/home');
                  },
                  child: Text(
                    'Open full day',
                    style: context.text.bodyStrong.copyWith(color: context.colors.onPrimary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Widget titleWidget;
  final String subtitle;
  final bool isDone;
  final VoidCallback onTap;

  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.titleWidget,
    required this.subtitle,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget,
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.text.caption.copyWith(color: context.colors.textLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isDone)
              Icon(
                Icons.check_circle_rounded,
                color: context.colors.green,
                )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textLight,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.colors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.micro.copyWith(color: context.colors.textLight),
                ),
                Text(
                  value,
                  style: context.text.body.copyWith(color: context.colors.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
