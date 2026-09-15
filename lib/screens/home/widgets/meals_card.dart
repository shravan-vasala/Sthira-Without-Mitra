import 'package:flutter/material.dart';
import '../../../utils/meal_completion.dart';
import '../../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/layout_insets.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/surface_card.dart';
import 'photo_calorie_scanner_sheet.dart';

class MealsCard extends ConsumerWidget {
  const MealsCard({super.key});

  // ignore: unused_element
  void _openLogSheet(
    BuildContext context, {
    required String slotId,
    required String slotName,
    required bool describe,
  }) {
    Haptics.tap();
    showAppBottomSheet(
      context: context,
      builder: (_) => PhotoCalorieScannerSheet(
        slotId: slotId,
        slotDisplayName: slotName,
        isManualEntry: describe,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyLog = ref.watch(dailyMealLogProvider);
    final profile = ref.watch(profileProvider);
    final mealPlan = ref.watch(mealPlanProvider);
    final planName = "${profile.name}'s ${mealPlan?.planName ?? 'Meal Plan'}";

    final selectedDateStr = ref.watch(dateStringProvider);
    final selectedDate = DateTime.parse(selectedDateStr);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final isFuture = selectedDate.isAfter(today);
    final isToday = selectedDate.isAtSameMomentAs(today);

    final int totalMeals = MealCompletion.calculateTotalMeals(profile, dailyLog);

    final slots = <({String id, String name, String emoji})>[];
    for (final s in profile.customMealSlots) {
      slots.add((
        id: s['id'] as String,
        name: s['name'] as String,
        emoji: s['emoji'] as String,
      ));
    }

    final completedMeals = dailyLog.loggedSlotsCount;
    final completedCal = dailyLog.totalCalories;
    final totalCal = profile.targetCalories;
    final progress = (completedCal / totalCal).clamp(0.0, 1.0);
    final isOverTarget = completedCal > totalCal;

    return Semantics(
      label:
          'Meals Card. $completedMeals of $totalMeals meals logged. $completedCal of $totalCal calories consumed.',
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Haptics.tap();
              context.go('/home/meals');
            },
            behavior: HitTestBehavior.opaque,
            child: SurfaceCard(
              margin: const EdgeInsets.symmetric(horizontal: kScreenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isToday ? "Today's Meals" : (isFuture ? "Upcoming Meals" : "Meals"),
                              style: context.text.cardTitle.copyWith(color: context.colors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              planName,
                              style: context.text.caption.copyWith(color: context.colors.textMedium),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.colors.textLight,
                        size: 16,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: context.colors.primary.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOverTarget ? context.colors.orange : context.colors.green,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: completedCal),
                    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 1400),
                    curve: Curves.easeOutQuart,
                    builder: (context, val, child) {
                      return Text(
                        '$completedMeals/$totalMeals meals  ·  $val/$totalCal kcal',
                        style: AppTheme.numeric(
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.colors.textMedium,
                              ) ??
                              context.text.body,
                        ),
                      );
                    }
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _MacroPill(
                            label: 'P',
                            value: dailyLog.totalProtein,
                            color: context.colors.green,
                          ),
                      const SizedBox(width: 6),
                      _MacroPill(
                            label: 'C',
                            value: dailyLog.totalCarbs,
                            color: context.colors.orange,
                          ),
                      const SizedBox(width: 6),
                      _MacroPill(
                            label: 'F',
                            value: dailyLog.totalFat,
                            color: context.colors.primary,
                          ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isFuture || isToday
                        ? (isOverTarget
                            ? '${completedCal - totalCal} kcal above target'
                            : '${totalCal - completedCal} kcal remaining · ${(profile.targetProteinG - dailyLog.totalProtein).clamp(0, 999).toStringAsFixed(0)}g protein to target')
                        : (isOverTarget
                            ? '${completedCal - totalCal} kcal above target'
                            : 'Below target by ${totalCal - completedCal} kcal'),
                    style: context.text.micro.copyWith(color: context.colors.textMedium),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15), // Bumped alpha slightly after removing border
        borderRadius: BorderRadius.circular(6),
        // Sthira: Borders eradicated
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value),
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 1400),
        curve: Curves.easeOutQuart,
        builder: (context, val, child) {
          return Text(
            '$label: ${val.toStringAsFixed(0)}g',
            style: AppTheme.numeric(
              context.text.micro.copyWith(color: color),
            ),
          );
        }
      ),
    );
  }
}
