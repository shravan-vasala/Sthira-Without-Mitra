import 'package:trufit_bodamma/theme/app_typography.dart';
import '../../theme/app_motion.dart';

import 'package:trufit_bodamma/theme/app_colors.dart';
import 'package:trufit_bodamma/theme/app_spacing.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/layout_insets.dart';
import '../../providers/app_providers.dart';
import '../../models/daily_meal_log.dart';
import '../../models/food_nutrition.dart';
import '../../models/meal_plan.dart';
import '../../utils/meal_plan_complete.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/surface_card.dart';
import '../../widgets/primary_button.dart';
import '../../utils/meal_icons.dart';
import 'widgets/photo_calorie_scanner_sheet.dart';
import 'widgets/add_meal_slot_dialog.dart';
import 'widgets/ai_meal_suggestion_card.dart';
import '../meals/widgets/plate_calculator_sheet.dart';
import '../../theme/app_theme.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';
import '../../theme/app_motion.dart';


class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key});

  void _openAddSlotDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const AddMealSlotDialog());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyLog = ref.watch(dailyMealLogProvider);
    final profile = ref.watch(profileProvider);
    final mealPlan = ref.watch(mealPlanProvider);
    final planName = "${profile.name}'s ${mealPlan?.planName ?? 'Meal Plan'}";

    final targetCalories = profile.targetCalories;
    final isOverTarget =
        targetCalories > 0 && dailyLog.totalCalories > targetCalories;
    final progressRatio = targetCalories > 0
        ? (dailyLog.totalCalories / targetCalories).clamp(0.0, 1.0)
        : (dailyLog.totalCalories > 0 ? 1.0 : 0.0);

    final pinnedDateStr = ref.watch(dateStringProvider);
    final pinnedDate = DateTime.parse(pinnedDateStr);
    final isToday =
        pinnedDateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final titleText = isToday
        ? "Today's meals"
        : "${DateFormat('MMM d, yyyy').format(pinnedDate)} meals";

    final List<({String id, String name, String emoji})> slotsToDisplay = [];
    final recurringIds = <String>{};

    for (final s in profile.customMealSlots) {
      final id = s['id'] as String;
      recurringIds.add(id);
      slotsToDisplay.add((
        id: id,
        name: s['name'] as String,
        emoji: s['emoji'] as String,
      ));
    }

    for (final entry in dailyLog.customSlots.entries) {
      if (!recurringIds.contains(entry.key)) {
        final log = entry.value;
        slotsToDisplay.add((
          id: entry.key,
          name: log.name ?? 'Meal',
          emoji: log.emoji ?? '🍽️',
        ));
      }
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titleText),
            Text(
              planName,
              style: context.text.caption.copyWith(
                color: context.colors.textMedium,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          kShellScrollBottomPadding,
        ),
        itemCount: slotsToDisplay.length + 4,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              children: [
                _CalorieHeader(
                  eaten: dailyLog.totalCalories,
                  target: targetCalories,
                  progress: progressRatio,
                  isOverTarget: isOverTarget,
                  protein: dailyLog.totalProtein,
                  carbs: dailyLog.totalCarbs,
                  fat: dailyLog.totalFat,
                  proteinTarget: profile.targetProteinG.toDouble(),
                  carbsTarget: profile.targetCarbsG.toDouble(),
                  fatTarget: profile.targetFatG.toDouble(),
                ),
                const SizedBox(height: 24),
              ],
            );
          } else if (index <= slotsToDisplay.length) {
            final s = slotsToDisplay[index - 1];
            final shouldAnimate = !MediaQuery.disableAnimationsOf(context);
            return _MealSlotCard(
                  key: ValueKey(s.id),
                  slotId: s.id,
                  slotName: s.name,
                  slotEmoji: s.emoji,
                  slotLog: dailyLog.customSlots[s.id],
                  plannedMeal: MealPlanComplete.plannedForSlot(mealPlan, s.id),
                )
                .animate()
                .fadeIn(
                  duration: shouldAnimate ? Motion.deliberate : Motion.instant,
                  curve: Motion.enter,
                )
                .slideY(
                  begin: 0.05,
                  end: 0,
                  duration: shouldAnimate ? Motion.deliberate : Motion.instant,
                  curve: Motion.enter,
                );
          } else if (index == slotsToDisplay.length + 1) {
            final unloggedSlots = slotsToDisplay.where((s) {
              final slotLog = dailyLog.customSlots[s.id];
              return slotLog == null || slotLog.items.isEmpty;
            }).toList();
            final mealsLeft = unloggedSlots.length;
            final mealName = unloggedSlots.isNotEmpty
                ? unloggedSlots.first.name
                : null;

            return AIMealSuggestionCard(
              remainingCalories: targetCalories - dailyLog.totalCalories,
              remainingProtein:
                  profile.targetProteinG.toDouble() - dailyLog.totalProtein,
              remainingCarbs:
                  profile.targetCarbsG.toDouble() - dailyLog.totalCarbs,
              remainingFat: profile.targetFatG.toDouble() - dailyLog.totalFat,
              mealName: mealName,
              mealsLeft: mealsLeft,
            );
          } else if (index == slotsToDisplay.length + 2) {
            return const SizedBox(height: 16);
          } else {
            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openAddSlotDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Flexible(
                      child: Text(
                        'Add another meal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyStrong,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      backgroundColor: context.colors.primary.withValues(
                        alpha: 0.12,
                      ),
                      side: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showAppBottomSheet(
                      context: context,
                      builder: (_) => const PlateCalculatorSheet(),
                    ),
                    icon: const Icon(Icons.pie_chart_outline_rounded, size: 20),
                    label: Flexible(
                      child: Text(
                        'Visual Plate Calculator',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyStrong,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.indigo,
                      backgroundColor: context.colors.indigo.withValues(
                        alpha: 0.12,
                      ),
                      side: BorderSide.none,
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

class _CalorieHeader extends StatelessWidget {
  const _CalorieHeader({
    required this.eaten,
    required this.target,
    required this.progress,
    required this.isOverTarget,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinTarget,
    required this.carbsTarget,
    required this.fatTarget,
  });

  final int eaten;
  final int target;
  final double progress;
  final bool isOverTarget;
  final double protein;
  final double carbs;
  final double fat;
  final double proteinTarget;
  final double carbsTarget;
  final double fatTarget;

  @override
  Widget build(BuildContext context) {
    final accent = isOverTarget
        ? context.colors.orange
        : context.colors.primary;
    final shouldAnimate = !MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(
                  begin: shouldAnimate ? 0 : eaten.toInt(),
                  end: eaten.toInt(),
                ),
                duration: shouldAnimate
                    ? const Motion.deliberate
                    : Duration.zero,
                curve: Motion.enter,
                builder: (context, val, child) {
                  return Text(
                    '$val',
                    style: context.text.metric.copyWith(
                      color: context.colors.textDark,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              if (target == 0)
                Text(
                  ' kcal',
                  style: context.text.body.copyWith(
                    color: context.colors.textMedium,
                  ),
                )
              else if (isOverTarget)
                Text(
                  '+${(eaten - target).toInt()} over target',
                  style: context.text.body.copyWith(
                    color: context.colors.orange,
                  ),
                )
              else
                Text(
                  '/ ${target.toInt()} kcal',
                  style: context.text.body.copyWith(
                    color: context.colors.textMedium,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.colors.border,
              color: accent,
              minHeight: 2,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MinimalMacroStat(
                  label: 'Protein',
                  current: protein,
                  target: proteinTarget,
                ),
              ),
              Container(width: 1, height: 24, color: context.colors.border),
              Expanded(
                child: _MinimalMacroStat(
                  label: 'Carbs',
                  current: carbs,
                  target: carbsTarget,
                ),
              ),
              Container(width: 1, height: 24, color: context.colors.border),
              Expanded(
                child: _MinimalMacroStat(
                  label: 'Fat',
                  current: fat,
                  target: fatTarget,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MinimalMacroStat extends StatelessWidget {
  const _MinimalMacroStat({
    required this.label,
    required this.current,
    required this.target,
  });

  final String label;
  final double current;
  final double target;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: context.text.micro.copyWith(color: context.colors.textMedium),
        ),
        const SizedBox(height: 4),
        if (target == 0)
          Text(
            '${current.toInt()}g',
            style: AppTheme.numeric(
              context.text.body.copyWith(color: context.colors.textDark),
            ),
          )
        else
          Text(
            '${current.toInt()} / ${target.toInt()}g',
            style: AppTheme.numeric(
              context.text.body.copyWith(color: context.colors.textDark),
            ),
          ),
      ],
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.current,
    required this.target,
    required this.color,
  });

  final String label;
  final double current;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = (current / (target > 0 ? target : 1)).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: context.text.micro.copyWith(
                  color: context.colors.textMedium,
                ),
              ),
            ),
            if (target == 0)
              Text(
                '${current.toStringAsFixed(0)}g',
                style: AppTheme.numeric(
                  context.text.micro.copyWith(color: context.colors.textDark),
                ),
              )
            else
              Text(
                '${current.toStringAsFixed(0)}/${target.toStringAsFixed(0)}g',
                style: AppTheme.numeric(
                  context.text.micro.copyWith(color: context.colors.textDark),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: context.colors.primary.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _MealSlotCard extends ConsumerStatefulWidget {
  const _MealSlotCard({
    super.key,
    required this.slotId,
    required this.slotName,
    required this.slotEmoji,
    this.slotLog,
    this.plannedMeal,
  });

  final String slotId;
  final String slotName;
  final String slotEmoji;
  final MealSlotLog? slotLog;
  final Meal? plannedMeal;

  @override
  ConsumerState<_MealSlotCard> createState() => _MealSlotCardState();
}

class _MealSlotCardState extends ConsumerState<_MealSlotCard> {
  bool _showSuggestions = false;

  bool _isSaving = false;

  bool get _hasLog => MealPlanComplete.isSlotLogged(widget.slotLog);

  bool get _isPlannedComplete =>
      MealPlanComplete.isPlannedComplete(widget.slotLog);

  void _repeatMeal() async {
    final oldLog = widget.slotLog;
    if (oldLog == null || oldLog.items.isEmpty) return;

    final repo = ref.read(mealRepoProvider);
    final targetDateStr = ref.read(dateStringProvider);

    // Check if current day's same slot is empty
    final targetLog = repo.getDailyLog(targetDateStr);
    String targetSlotId = widget.slotId;

    if (targetLog.customSlots[targetSlotId] != null &&
        targetLog.customSlots[targetSlotId]!.items.isNotEmpty) {
      final profile = ref.read(profileProvider);
      final recurringIds = profile.customMealSlots
          .map((s) => s['id'] as String)
          .toList();
      String? nextEmpty;
      for (final id in recurringIds) {
        final slot = targetLog.customSlots[id];
        if (slot == null || slot.items.isEmpty) {
          nextEmpty = id;
          break;
        }
      }
      if (nextEmpty != null) {
        targetSlotId = nextEmpty;
      } else {
        // If all are full, we just use a fallback slot
        targetSlotId = 'repeated_${DateTime.now().millisecondsSinceEpoch}';
      }
    }

    final newItems = oldLog.items.map((i) {
      return MealItemLog(
        name: i.name,
        portion: i.portion,
        computedNutrition: i.computedNutrition != null
            ? FoodNutrition(
                kcal: i.computedNutrition!.kcal,
                proteinG: i.computedNutrition!.proteinG,
                carbsG: i.computedNutrition!.carbsG,
                fatG: i.computedNutrition!.fatG,
              )
            : null,
        baseNutrition: i.baseNutrition != null
            ? FoodNutrition(
                kcal: i.baseNutrition!.kcal,
                proteinG: i.baseNutrition!.proteinG,
                carbsG: i.baseNutrition!.carbsG,
                fatG: i.baseNutrition!.fatG,
              )
            : null,
        resolved: i.resolved,
        provenance: i.provenance,
        isPer100g: i.isPer100g,
        servingGrams: i.servingGrams,
        consumedGrams: i.consumedGrams,
      );
    }).toList();

    final newSlotLog = MealSlotLog(
      name: widget.slotName,
      emoji: widget.slotEmoji,
      items: newItems,
      totalCalories: oldLog.totalCalories,
      totalProtein: oldLog.totalProtein,
      totalCarbs: oldLog.totalCarbs,
      totalFat: oldLog.totalFat,
      photoPath: oldLog.photoPath,
    );

    await repo.saveMealSlot(targetDateStr, targetSlotId, newSlotLog);
    ref.read(dailyMealLogProvider.notifier).state = repo.getDailyLog(
      ref.read(dateStringProvider),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meal duplicated!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planned = widget.plannedMeal;
    final slotLog = widget.slotLog;
    final shouldAnimate = !MediaQuery.disableAnimationsOf(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SurfaceCard(
        margin: EdgeInsets.zero,
        child: AnimatedSize(
          duration: shouldAnimate ? Motion.standard : Motion.instant,
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      MealIcons.resolve(widget.slotEmoji),
                      color: context.colors.textDark,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.slotName,
                            style: context.text.cardTitle.copyWith(
                              color: context.colors.textDark,
                            ),
                          ),
                          if (_hasLog)
                            TweenAnimationBuilder<double>(
                              key: ValueKey(slotLog!.totalCalories),
                              tween: Tween(
                                begin: shouldAnimate ? 0.0 : 1.0,
                                end: 1.0,
                              ),
                              duration: shouldAnimate
                                  ? const Motion.deliberate
                                  : Duration.zero,
                              curve: Motion.enter,
                              builder: (context, val, _) {
                                final cal = (slotLog.totalCalories * val)
                                    .toInt();
                                final p = (slotLog.totalProtein * val).toInt();
                                final c = (slotLog.totalCarbs * val).toInt();
                                final f = (slotLog.totalFat * val).toInt();

                                return Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$cal kcal',
                                        style: context.text.body.copyWith(
                                          color: context.colors.primary,
                                        ),
                                      ),
                                      const TextSpan(text: '   '),
                                      TextSpan(
                                        text: 'P: ',
                                        style: context.text.micro.copyWith(
                                          color: context.colors.green
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                      TextSpan(text: '${p}g   '),
                                      TextSpan(
                                        text: 'C: ',
                                        style: context.text.micro.copyWith(
                                          color: context.colors.orange
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                      TextSpan(text: '${c}g   '),
                                      TextSpan(
                                        text: 'F: ',
                                        style: context.text.micro.copyWith(
                                          color: context.colors.primary
                                              .withValues(alpha: 0.9),
                                        ),
                                      ),
                                      TextSpan(text: '${f}g'),
                                    ],
                                  ),
                                  style: AppTheme.numeric(
                                    context.text.caption.copyWith(
                                      color: context.colors.textMedium,
                                    ),
                                  ),
                                );
                              },
                            )
                          else if (planned != null && planned.calories > 0)
                            Text(
                              'Target ~${planned.calories} kcal',
                              style: context.text.caption.copyWith(
                                color: context.colors.textMedium,
                              ),
                            )
                          else
                            Text(
                              'Tap to log',
                              style: context.text.caption.copyWith(
                                color: context.colors.textMedium,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_hasLog)
                      TweenAnimationBuilder<double>(
                        key: const ValueKey('check'),
                        tween: Tween(
                          begin: shouldAnimate ? 0.0 : 1.0,
                          end: 1.0,
                        ),
                        duration: shouldAnimate
                            ? const Motion.deliberate
                            : Duration.zero,
                        curve: Motion.enter,
                        builder: (context, val, child) {
                          return Transform.scale(
                            scale: val,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: context.colors.green,
                              size: 20,
                            ),
                          );
                        },
                      ),
                  ],
                ),

                // State dependent body
                AnimatedSwitcher(
                  duration: const Motion.standard,
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  child: KeyedSubtree(
                    key: ValueKey(_hasLog),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_hasLog) ...[
                          const SizedBox(height: 20),

                          // Logged Items
                          if (slotLog!.photoPath != null) ...[
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    backgroundColor: context.colors.card
                                        .withValues(alpha: 0),
                                    insetPadding: EdgeInsets.zero,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        InteractiveViewer(
                                          child: kIsWeb
                                              ? Image.network(
                                                  slotLog.photoPath!,
                                                )
                                              : Image.file(
                                                  File(
                                                    ref
                                                        .read(mediaRepoProvider)
                                                        .getAbsolutePath(
                                                          slotLog.photoPath!,
                                                        ),
                                                  ),
                                                ),
                                        ),
                                        Positioned(
                                          top:
                                              MediaQuery.paddingOf(
                                                context,
                                              ).top +
                                              16,
                                          right: 16,
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.close_rounded,
                                              color: context.colors.onPrimary,
                                              size: 32,
                                            ),
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb
                                    ? Image.network(
                                        slotLog.photoPath!,
                                        width: double.infinity,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(
                                          ref
                                              .read(mediaRepoProvider)
                                              .getAbsolutePath(
                                                slotLog.photoPath!,
                                              ),
                                        ),
                                        width: double.infinity,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (slotLog.items.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 8),
                              child: Text.rich(
                                TextSpan(
                                  children: slotLog.items.asMap().entries.expand(
                                    (entry) {
                                      final isLast =
                                          entry.key == slotLog.items.length - 1;
                                      final item = entry.value;
                                      return <InlineSpan>[
                                        TextSpan(
                                          text:
                                              '• ${item.portion} ${item.name} ',
                                          style: context.text.caption.copyWith(
                                            color: context.colors.textMedium,
                                          ),
                                        ),
                                        if (item.provenance != null)
                                          WidgetSpan(
                                            alignment:
                                                PlaceholderAlignment.middle,
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: isLast ? 0 : 12,
                                              ),
                                              child: _ProvenanceBadge(
                                                provenance: item.provenance,
                                              ),
                                            ),
                                          )
                                        else if (!isLast)
                                          const TextSpan(text: '   '),
                                      ];
                                    },
                                  ).toList(),
                                ),
                              ),
                            ),

                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: context.colors.primary,
                                  minimumSize: const Size(44, 44),
                                ),
                                onPressed: () =>
                                    _openScanner(context, false, append: true),
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: IconSize.inline,
                                ),
                                label: Text(
                                  'Add Serving',
                                  style: context.text.caption,
                                ),
                              ),
                              const SizedBox(width: Spacing.block),
                              if (ref.watch(dateStringProvider) !=
                                  DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(DateTime.now()))
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: context.colors.textMedium,
                                    minimumSize: const Size(44, 44),
                                  ),
                                  onPressed: _repeatMeal,
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: IconSize.inline,
                                  ),
                                  label: Text(
                                    'Repeat',
                                    style: context.text.caption,
                                  ),
                                )
                              else
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: context.colors.textMedium,
                                    minimumSize: const Size(44, 44),
                                  ),
                                  onPressed: () => _openScanner(context, false),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: IconSize.inline,
                                  ),
                                  label: Text(
                                    'Replace',
                                    style: context.text.caption,
                                  ),
                                ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: context.colors.textMedium,
                                  size: 20,
                                ),
                                onPressed: () {
                                  final targetDateStr = ref.read(
                                    dateStringProvider,
                                  );
                                  final oldLog = widget.slotLog;
                                  ref
                                      .read(dailyMealLogProvider.notifier)
                                      .clearMealSlot(
                                        widget.slotId,
                                        targetDate: targetDateStr,
                                      );

                                  ScaffoldMessenger.of(
                                    context,
                                  ).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${widget.slotName} removed',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        textColor: context.colors.primary,
                                        onPressed: () {
                                          if (oldLog != null) {
                                            ref
                                                .read(
                                                  dailyMealLogProvider.notifier,
                                                )
                                                .saveMealSlot(
                                                  widget.slotId,
                                                  oldLog,
                                                  targetDate: targetDateStr,
                                                );
                                          }
                                        },
                                      ),
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ] else ...[
                          // NOT logged actions
                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                child: CompactButton(
                                  label: 'Take photo',
                                  icon: Icons.camera_alt_outlined,
                                  filled: true,
                                  onPressed: () => _openScanner(context, false),
                                ),
                              ),
                              const SizedBox(width: Spacing.stack),
                              Expanded(
                                child: CompactButton(
                                  label: 'Describe',
                                  icon: Icons.notes_rounded,
                                  filled: false,
                                  onPressed: () => _openScanner(context, true),
                                ),
                              ),
                            ],
                          ),
                          if (planned != null) ...[
                            const SizedBox(height: 20),
                            Center(
                              child: InkWell(
                                onTap: () => _toggleCompletedAsPlanned(planned),
                                child: Text(
                                  'Or mark completed as planned',
                                  style: context.text.caption.copyWith(
                                    color: context.colors.textMedium,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                // Suggestions
                if (planned != null && planned.suggestions.isNotEmpty)
                  _buildSuggestions(context, planned),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context, Meal planned) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _showSuggestions = !_showSuggestions);
              Haptics.tap();
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Plan Guidelines',
                  style: context.text.body.copyWith(
                    color: context.colors.textDark,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showSuggestions
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: context.colors.textMedium,
                  size: 20,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: Motion.standard,
            curve: Motion.enter,
            alignment: Alignment.topCenter,
            child: !_showSuggestions
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      ...planned.suggestions.expand((suggestion) {
                        final items = suggestion
                            .split('•')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty);
                            
                        return items.map((item) {
                          String qty = '';
                          String name = item;
                          final words = item.split(' ');
                          int splitIndex = -1;
                          for (int i = 0; i < words.length; i++) {
                            final w = words[i];
                            // Find first capitalized word that isn't just numbers/symbols
                            if (w.isNotEmpty && 
                                w[0] == w[0].toUpperCase() && 
                                w[0] != w[0].toLowerCase() && 
                                !w.contains(RegExp(r'[0-9]'))) {
                              splitIndex = i;
                              break;
                            }
                          }
                          
                          if (splitIndex > 0) {
                            qty = words.sublist(0, splitIndex).join(' ');
                            name = words.sublist(splitIndex).join(' ');
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, right: 12),
                                  child: Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: context.colors.primary.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        if (qty.isNotEmpty)
                                          TextSpan(
                                            text: '$qty  ',
                                            style: context.text.caption.copyWith(
                                              color: context.colors.primary.withValues(alpha: 0.9),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        TextSpan(
                                          text: name,
                                          style: context.text.caption.copyWith(
                                            color: context.colors.textMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        });
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCompletedAsPlanned(Meal planned) async {
    if (_isSaving) return;

    final targetDateStr = ref.read(dateStringProvider);
    final notifier = ref.read(dailyMealLogProvider.notifier);

    if (_isPlannedComplete) {
      setState(() => _isSaving = true);
      try {
        Haptics.tap();
        await notifier.clearMealSlot(widget.slotId, targetDate: targetDateStr);
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }

    if (_hasLog) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Overwrite Meal?'),
          content: const Text(
            'This will remove your scanned photos and macros and replace them with the planned meal. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Overwrite',
                style: context.text.body.copyWith(color: context.colors.red),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (!mounted) return;

    setState(() => _isSaving = true);
    try {
      final profile = ref.read(profileProvider);
      final log = MealPlanComplete.buildSlotLog(
        planned: planned,
        slotName: widget.slotName,
        slotEmoji: widget.slotEmoji,
        profile: profile,
      );

      Haptics.toggle();
      await notifier.saveMealSlot(
        widget.slotId,
        log,
        targetDate: targetDateStr,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openScanner(
    BuildContext context,
    bool isManualEntry, {
    bool append = false,
  }) {
    showAppBottomSheet(
      context: context,
      builder: (_) => PhotoCalorieScannerSheet(
        slotId: widget.slotId,
        slotDisplayName: widget.slotName,
        isManualEntry: isManualEntry,
        appendToLog: append ? widget.slotLog : null,
      ),
    );
  }
}

class _ProvenanceBadge extends StatelessWidget {
  const _ProvenanceBadge({this.provenance});
  final String? provenance;

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color color;
    final validProvenance = (provenance != null && provenance!.isNotEmpty)
        ? provenance!
        : 'unknown';
    String label = validProvenance;

    switch (validProvenance) {
      case 'verified':
        iconData = Icons.verified_outlined;
        color = context.colors.textMedium;
        break;
      case 'estimated':
      case 'ai_estimate':
        iconData = Icons.auto_awesome_rounded;
        color = context.colors.primary.withValues(alpha: 0.8);
        label = 'estimated';
        break;
      case 'database':
        iconData = Icons.storage_rounded;
        color = context.colors.textMedium;
        break;
      case 'legacy':
        iconData = Icons.history_rounded;
        color = context.colors.textLight;
        break;
      case 'yours':
        iconData = Icons.edit_outlined;
        color = context.colors.textLight;
        break;
      case 'expert_plan':
        iconData = Icons.verified_user_rounded;
        color = context.colors.indigo;
        label = 'nutritionist';
        break;
      default:
        iconData = Icons.info_outline_rounded;
        color = context.colors.textLight;
        label = 'unknown';
    }

    return GestureDetector(
      onTap: () {
        Haptics.tap();
        showAppBottomSheet(
          context: context,
          builder: (ctx) => _ProvenanceExplanationSheet(provenance: provenance),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label.substring(0, 1).toUpperCase() + label.substring(1),
              style: context.text.micro.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvenanceExplanationSheet extends StatelessWidget {
  const _ProvenanceExplanationSheet({this.provenance});
  final String? provenance;

  @override
  Widget build(BuildContext context) {
    String title, desc;
    IconData headerIcon;
    Color headerColor;

    final validProvenance = (provenance != null && provenance!.isNotEmpty)
        ? provenance!
        : 'unknown';

    if (validProvenance == 'verified') {
      title = 'Verified Local Food';
      headerIcon = Icons.verified_outlined;
      headerColor = context.colors.textMedium;
      desc =
          'This item was matched against your personal food database. The base macros are exact, but the consumed portion may vary.';
    } else if (validProvenance == 'estimated' || validProvenance == 'ai_estimate') {
      title = 'AI Estimated';
      headerIcon = Icons.auto_awesome_rounded;
      headerColor = context.colors.primary.withValues(alpha: 0.8);
      desc =
          'Gemini estimated the macros for this food based on its nutritional profile. The values are an AI approximation and not exact.';
    } else if (validProvenance == 'database') {
      title = 'Database Match';
      headerIcon = Icons.storage_rounded;
      headerColor = context.colors.textMedium;
      desc =
          'This item was matched against standard food databases for precise macros.';
    } else if (validProvenance == 'legacy') {
      title = 'Legacy Item';
      headerIcon = Icons.history_rounded;
      headerColor = context.colors.textLight;
      desc =
          'This item was recorded before provenance tracking was introduced.';
    } else if (validProvenance == 'yours') {
      title = 'Yours';
      headerIcon = Icons.edit_outlined;
      headerColor = context.colors.textLight;
      desc = 'You manually adjusted the macros or portion size for this item.';
    } else if (validProvenance == 'expert_plan') {
      title = 'Clinical Protocol';
      headerIcon = Icons.verified_user_rounded;
      headerColor = context.colors.indigo;
      desc = 'This item is a verified clinical protocol designed by an expert nutritionist. It is highly recommended.';
    } else {
      title = 'Unknown Origin';
      headerIcon = Icons.info_outline_rounded;
      headerColor = context.colors.textLight;
      desc = 'This is a legacy item with no recorded provenance or origin.';
    }

    return AppSheet(
      title: title,
      subtitle: desc,
      scrollable: true,
      child: const SizedBox(height: 28),
    );
  }
}
