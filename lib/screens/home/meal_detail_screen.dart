import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/layout_insets.dart';
import '../../providers/app_providers.dart';
import '../../models/daily_meal_log.dart';
import '../../models/meal_plan.dart';
import '../../utils/meal_plan_complete.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/surface_card.dart';
import '../../utils/meal_icons.dart';
import 'widgets/photo_calorie_scanner_sheet.dart';
import 'widgets/add_meal_slot_dialog.dart';
import 'widgets/ai_meal_suggestion_card.dart';
import '../meals/widgets/plate_calculator_sheet.dart';
import '../../theme/app_theme.dart';

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
    final planName = mealPlan?.planName ?? 'Daily Meal Plan';

    final targetCalories = profile.targetCalories;
    final isOverTarget = dailyLog.totalCalories > targetCalories;
    final progressRatio =
        (dailyLog.totalCalories / (targetCalories > 0 ? targetCalories : 1))
            .clamp(0.0, 1.0);

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
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Today's meals"),
            Text(
              planName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.colors.textMedium,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          kShellScrollBottomPadding + MediaQuery.paddingOf(context).bottom,
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
            return _MealSlotCard(
              slotId: s.id,
              slotName: s.name,
              slotEmoji: s.emoji,
              slotLog: dailyLog.customSlots[s.id],
              plannedMeal: MealPlanComplete.plannedForSlot(mealPlan, s.id),
            )
            .animate(delay: ((index - 1) * 80).ms)
            .fadeIn(duration: 400.ms, curve: Curves.easeOut)
            .slideY(begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOut);
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
                    label: const Text(
                      'Add another meal',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      backgroundColor: context.colors.primary.withValues(
                        alpha: 0.08,
                      ),
                      side: BorderSide(
                        color: context.colors.primary.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                    label: const Text(
                      'Visual Plate Calculator',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.indigo,
                      backgroundColor: context.colors.indigo.withValues(
                        alpha: 0.08,
                      ),
                      side: BorderSide(
                        color: context.colors.indigo.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
    final accent = isOverTarget ? context.colors.orange : context.colors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${eaten.toInt()}',
                style: TextStyle(
                  fontFamily: 'CabinetGrotesk',
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1.0,
                  color: context.colors.textDark,
                ),
              ),
              const SizedBox(width: 8),
              if (isOverTarget)
                Text(
                  '+${(eaten - target).toInt()} over target',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.orange,
                  ),
                )
              else
                Text(
                  '/ ${target.toInt()} kcal',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.colors.textMedium,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${current.toInt()} / ${target.toInt()}g',
          style: AppTheme.numeric(
            TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.colors.textDark,
            ),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textMedium,
                ),
              ),
            ),
            Text(
              '${current.toStringAsFixed(0)}/${target.toStringAsFixed(0)}g',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.colors.textDark,
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
  bool get _hasLog => MealPlanComplete.isSlotLogged(widget.slotLog);

  bool get _isPlannedComplete =>
      MealPlanComplete.isPlannedComplete(widget.slotLog);

  @override
  Widget build(BuildContext context) {
    final planned = widget.plannedMeal;
    final slotLog = widget.slotLog;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SurfaceCard(
        child: AnimatedSize(
          duration: 300.ms,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      MealIcons.resolve(widget.slotEmoji),
                      size: 24,
                      color: context.colors.textDark,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.slotName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textDark,
                            ),
                          ),
                          if (_hasLog)
                            Text(
                              '${slotLog!.totalCalories} kcal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.colors.primary,
                              ),
                            )
                          else if (planned != null && planned.calories > 0)
                            Text(
                              'Target ~${planned.calories} kcal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: context.colors.textMedium,
                              ),
                            )
                          else
                            Text(
                              'Tap to log',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: context.colors.textMedium,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_hasLog)
                      Icon(Icons.check_circle_rounded, color: context.colors.green, size: 20),
                  ],
                ),

                // If logged, show items
                if (_hasLog) ...[
                  const SizedBox(height: 24),
                  
                  // Logged Items
                  if (slotLog!.photoPath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.network(
                              slotLog.photoPath!,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(slotLog.photoPath!),
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (slotLog.items.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: slotLog.items.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.colors.scaffoldBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Text(
                            '${item.name} · ${item.portion}',
                            style: TextStyle(fontSize: 12, color: context.colors.textDark, fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                    ),
                  
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colors.primary,
                            side: BorderSide(color: context.colors.primary.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _openScanner(context, false, append: true),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                          label: const Text('Add Serving', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colors.textMedium,
                            side: BorderSide(color: context.colors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _openScanner(context, false),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Replace', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: context.colors.textMedium),
                        onPressed: () => ref.read(dailyMealLogProvider.notifier).clearMealSlot(widget.slotId),
                      ),
                    ],
                  ),
                ] else ...[
                   // NOT logged actions 
                   const SizedBox(height: 24),
                   
                   Row(
                     children: [
                       Expanded(
                         child: ElevatedButton.icon(
                           style: ElevatedButton.styleFrom(
                             backgroundColor: context.colors.primary,
                             foregroundColor: context.colors.onPrimary,
                             elevation: 0,
                             padding: const EdgeInsets.symmetric(vertical: 14),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           ),
                           onPressed: () => _openScanner(context, false),
                           icon: const Icon(Icons.camera_alt_outlined, size: 18),
                           label: const Text('Take photo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: OutlinedButton.icon(
                           style: OutlinedButton.styleFrom(
                             foregroundColor: context.colors.primary,
                             side: BorderSide(color: context.colors.primary.withValues(alpha: 0.5)),
                             padding: const EdgeInsets.symmetric(vertical: 14),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           ),
                           onPressed: () => _openScanner(context, true),
                           icon: const Icon(Icons.notes_rounded, size: 18),
                           label: const Text('Describe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
                           style: TextStyle(
                             fontSize: 13,
                             fontWeight: FontWeight.w600,
                             color: context.colors.textMedium,
                           ),
                         ),
                       ),
                     ),
                   ],
                ],

                // Suggestions
                if (planned != null && planned.suggestions.isNotEmpty)
                  _buildSuggestions(context, planned)
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context, Meal planned) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Icon(Icons.lightbulb_outline_rounded, size: 16, color: context.colors.primary),
               const SizedBox(width: 8),
               Text(
                 'Suggestions',
                 style: TextStyle(
                   fontSize: 14,
                   fontWeight: FontWeight.w700,
                   color: context.colors.textDark,
                 ),
               ),
            ],
          ),
          const SizedBox(height: 16),
          ...planned.suggestions.map((suggestion) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 12),
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
                    child: Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textMedium,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _toggleCompletedAsPlanned(Meal planned) async {
    final notifier = ref.read(dailyMealLogProvider.notifier);
    if (_isPlannedComplete) {
      // ignore: unawaited_futures
      Haptics.tap();
      await notifier.clearMealSlot(widget.slotId);
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
              child: const Text(
                'Overwrite',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final profile = ref.read(profileProvider);
    final log = MealPlanComplete.buildSlotLog(
      planned: planned,
      slotName: widget.slotName,
      slotEmoji: widget.slotEmoji,
      profile: profile,
    );

    // ignore: unawaited_futures
    Haptics.toggle();
    await notifier.saveMealSlot(widget.slotId, log);
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
