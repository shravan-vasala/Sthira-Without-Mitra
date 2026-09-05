import 'package:flutter/material.dart';
import '../../../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/layout_insets.dart';
import '../../../theme/app_theme.dart';
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
    final planName = mealPlan?.planName ?? 'Daily Meal Plan';

    final selectedDateStr = ref.watch(dateStringProvider);
    final selectedDate = DateTime.parse(selectedDateStr);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final isFuture = selectedDate.isAfter(today);
    final isToday = selectedDate.isAtSameMomentAs(today);

    final defaultIds = profile.customMealSlots
        .where((s) => s['isDefault'] == true)
        .map((s) => s['id'] as String)
        .toSet();
    final loggedIds = dailyLog.customSlots.keys.toSet();

    int totalMeals = defaultIds.length;
    if (isFuture || isToday) {
      final recurringIds = profile.customMealSlots
          .map((s) => s['id'] as String)
          .toSet();
      totalMeals = recurringIds.union(loggedIds).length;
    } else {
      final customLoggedCount = loggedIds.difference(defaultIds).length;
      totalMeals = defaultIds.length + customLoggedCount;
    }

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
      child: SurfaceCard(
        margin: const EdgeInsets.symmetric(horizontal: kScreenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Haptics.tap();
                context.go('/home/meals');
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Meals",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          planName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.textLight,
                  ),
                ],
              ),
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
            Text(
                  '$completedMeals/$totalMeals meals  ·  $completedCal/$totalCal kcal',
                  style: AppTheme.numeric(
                    Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.textMedium,
                        ) ??
                        const TextStyle(),
                  ),
                )
                .animate(key: ValueKey('$completedMeals-$completedCal'))
                .fade()
                .scale(begin: const Offset(0.95, 0.95)),
            const SizedBox(height: 8),
            Row(
              children: [
                _MacroPill(
                      label: 'P',
                      value: '${dailyLog.totalProtein.toStringAsFixed(0)}g',
                      color: context.colors.green,
                    )
                    .animate(key: ValueKey(dailyLog.totalProtein))
                    .scale(begin: const Offset(0.9, 0.9)),
                const SizedBox(width: 6),
                _MacroPill(
                      label: 'C',
                      value: '${dailyLog.totalCarbs.toStringAsFixed(0)}g',
                      color: context.colors.orange,
                    )
                    .animate(key: ValueKey(dailyLog.totalCarbs))
                    .scale(begin: const Offset(0.9, 0.9)),
                const SizedBox(width: 6),
                _MacroPill(
                      label: 'F',
                      value: '${dailyLog.totalFat.toStringAsFixed(0)}g',
                      color: context.colors.primary,
                    )
                    .animate(key: ValueKey(dailyLog.totalFat))
                    .scale(begin: const Offset(0.9, 0.9)),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
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
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $value',
        style: AppTheme.numeric(
          TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}
