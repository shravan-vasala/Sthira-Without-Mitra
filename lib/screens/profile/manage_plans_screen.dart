import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../utils/meal_icons.dart';
import '../../utils/target_calculator.dart';
import '../../widgets/surface_card.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class ManagePlansScreen extends ConsumerWidget {
  const ManagePlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final workoutRepo = ref.watch(workoutRepoProvider);
    final mealRepo = ref.watch(mealRepoProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: context.colors.scaffoldBg,
        appBar: AppBar(
          title: const Text('Manage Plans'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: TabBar(
            labelColor: context.colors.primary,
            unselectedLabelColor: context.colors.textMedium,
            indicatorColor: context.colors.primary,
            isScrollable: true,
            tabs: [
              const Tab(text: 'Workout Plans'),
              const Tab(text: 'Meal Plans'),
              const Tab(text: 'Meal Slots'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Active Plans Selection
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: context.colors.card,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Workout',
                          style: context.text.micro.copyWith(color: context.colors.textMedium),
                        ),
                        DropdownButton<String>(
                          value: profile.activeWorkoutPlan,
                          isExpanded: true,
                          hint: const Text(
                            'Select Plan',
                            style: context.text.body,
                          ),
                          items: workoutRepo
                              .getPlanKeys()
                              .map(
                                (k) => DropdownMenuItem(
                                  value: k,
                                  child: Text(
                                    k,
                                    style: context.text.body,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref
                                  .read(profileProvider.notifier)
                                  .updateProfile(
                                    profile.copyWith(activeWorkoutPlan: val),
                                  );
                            }
                          },
                        ),
                        if (profile.planStartDate != null)
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(profileProvider.notifier)
                                  .updateProfile(
                                    profile.copyWith(
                                      clearPlanStart: true,
                                      currentPhaseWeek: 1,
                                    ),
                                  );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 30),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Text(
                              'Reset phase progress',
                              style: context.text.micro.copyWith(color: context.colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Meals',
                          style: context.text.micro.copyWith(color: context.colors.textMedium),
                        ),
                        DropdownButton<String>(
                          value: profile.activeMealPlan,
                          isExpanded: true,
                          hint: const Text(
                            'Select Plan',
                            style: context.text.body,
                          ),
                          items: mealRepo
                              .getPlanKeys()
                              .map(
                                (k) => DropdownMenuItem(
                                  value: k,
                                  child: Text(
                                    k,
                                    style: context.text.body,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref
                                  .read(profileProvider.notifier)
                                  .updateProfile(
                                    profile.copyWith(activeMealPlan: val),
                                  );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
              color: context.colors.card,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Targets',
                        style: context.text.micro.copyWith(color: context.colors.textMedium),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${profile.targetCalories} kcal (P:${profile.targetProteinG} C:${profile.targetCarbsG} F:${profile.targetFatG})',
                        style: context.text.body,
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final targets = TargetCalculator.calculate(
                        heightCm: profile.height,
                        weightKg: profile.currentWeight ?? profile.targetWeight,
                        age: profile.age,
                        gender: profile.gender,
                        goal: profile.primaryGoal,
                        activityLevel: 'Sedentary',
                      );
                      ref
                          .read(profileProvider.notifier)
                          .updateProfile(
                            profile.copyWith(
                              targetCalories: targets.calories.round(),
                              targetProteinG: targets.proteinG.round(),
                              targetCarbsG: targets.carbsG.round(),
                              targetFatG: targets.fatG.round(),
                            ),
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Targets recalculated: ${targets.calories} kcal',
                          ),
                          backgroundColor: context.colors.primary,
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('Recalculate'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      backgroundColor: context.colors.primary.withValues(
                        alpha: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _PlanEditor(
                    type: 'workout',
                    getKeys: () => workoutRepo.getPlanKeys(),
                    getRawJson: (key) => workoutRepo.getRawPlanJson(key),
                    saveJson: (key, json) =>
                        workoutRepo.savePlanJson(key, json),
                  ),
                  _PlanEditor(
                    type: 'meal',
                    getKeys: () => mealRepo.getPlanKeys(),
                    getRawJson: (key) => mealRepo.getRawPlanJson(key),
                    saveJson: (key, json) => mealRepo.savePlanJson(key, json),
                  ),
                  const _MealSlotsEditor(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealSlotsEditor extends ConsumerStatefulWidget {
  const _MealSlotsEditor();
  @override
  ConsumerState<_MealSlotsEditor> createState() => _MealSlotsEditorState();
}

class _MealSlotsEditorState extends ConsumerState<_MealSlotsEditor> {
  Future<void> _deleteSlot(Map<String, dynamic> slot) async {
    final profile = ref.read(profileProvider);
    final updatedSlots = List<Map<String, dynamic>>.from(
      profile.customMealSlots,
    );
    updatedSlots.removeWhere((s) => s['id'] == slot['id']);
    await ref.read(profileProvider.notifier).updateProfile(
      profile.copyWith(customMealSlots: updatedSlots),
    );
  }

  void _editSlot(Map<String, dynamic> slot, int index) {
    final nameCtrl = TextEditingController(text: slot['name'] as String);
    String selectedEmoji = MealIcons.normalize(slot['emoji'] as String?);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Edit Meal Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              const Text('Icon:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MealIcons.options.map((opt) {
                  final isSelected = opt.id == selectedEmoji;
                  return GestureDetector(
                    onTap: () => setStateDialog(() => selectedEmoji = opt.id),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected
                            ? context.colors.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                      ),
                      child: Icon(
                        opt.icon,
                        size: 24,
                        color: isSelected
                            ? context.colors.primary
                            : context.colors.textMedium,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: nameCtrl,
              builder: (context, value, child) {
                final isValid = value.text.trim().isNotEmpty;
                return ElevatedButton(
                  onPressed: isValid ? () async {
                    final profile = ref.read(profileProvider);
                    final updatedSlots = List<Map<String, dynamic>>.from(
                      profile.customMealSlots,
                    );
                    updatedSlots[index] = {
                      ...slot,
                      'name': nameCtrl.text.trim(),
                      'emoji': selectedEmoji,
                    };
                    await ref
                        .read(profileProvider.notifier)
                        .updateProfile(
                          profile.copyWith(customMealSlots: updatedSlots),
                        );
                    if (context.mounted) Navigator.pop(ctx);
                  } : null,
                  child: const Text('Save'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final slots = profile.customMealSlots;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isDefault = slot['isDefault'] == true;

        return SurfaceCard(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.zero,
          elevation: SurfaceCardElevation.nested,
          child: ListTile(
            leading: Icon(
              MealIcons.resolve(slot['emoji'] as String?),
              size: 24,
              color: context.colors.primary,
            ),
            title: Text(
              slot['name'] as String,
              style: context.text.body,
            ),
            subtitle: Text(
              isDefault ? 'Default Slot' : 'Custom Recurring Slot',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit_rounded, color: context.colors.primary),
                  onPressed: () => _editSlot(slot, index),
                ),
                if (!isDefault)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: context.colors.red,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Slot?'),
                          content: const Text(
                            'This will remove the slot from your daily template.\n\nAny meals you have already logged under this slot on past or current days will not be erased.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await _deleteSlot(slot);
                                if (context.mounted) Navigator.pop(ctx);
                              },
                              child: Text(
                                'Delete',
                                style: context.text.body.copyWith(color: context.colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlanEditor extends StatefulWidget {
  const _PlanEditor({
    required this.type,
    required this.getKeys,
    required this.getRawJson,
    required this.saveJson,
  });

  final String type;
  final List<String> Function() getKeys;
  final String? Function(String) getRawJson;
  final Future<void> Function(String, String) saveJson;

  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  String? _selectedKey;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final keys = widget.getKeys();
    if (keys.isNotEmpty) {
      _selectedKey = keys.first;
      _loadJson();
    }
  }

  void _loadJson() {
    if (_selectedKey != null) {
      final json = widget.getRawJson(_selectedKey!);
      _controller.text = json ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.getKeys();

    if (keys.isEmpty) {
      return const Center(child: Text('No plans found'));
    }

    return Column(
      children: [
        // Plan selector
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.colors.lavender,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedKey,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: keys.map((k) {
                      return DropdownMenuItem(
                        value: k,
                        child: Text(k, style: context.text.body),
                      );
                    }).toList(),
                    onChanged: (v) async {
                      if (v != null && v != _selectedKey) {
                        final rawJson = widget.getRawJson(_selectedKey!) ?? '';
                        if (_controller.text != rawJson) {
                          final discard = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Unsaved Changes'),
                              content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text('Discard', style: context.text.body.copyWith(color: context.colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (discard != true) return;
                        }
                        setState(() {
                          _selectedKey = v;
                          _loadJson();
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        // JSON editor
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: context.text.micro.copyWith(color: context.colors.textDark),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                  hintText: 'Paste JSON here...',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_selectedKey == null) return;
    try {
      final decoded = jsonDecode(_controller.text);
      final newPlanName = decoded['planName']?.toString();
      
      if (newPlanName != null && newPlanName != _selectedKey) {
        final confirmRename = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Rename Plan?'),
            content: Text('You changed the plan name from "$_selectedKey" to "$newPlanName". Do you want to save it as a new plan or rename it?\n\n(Renaming will delete "$_selectedKey")'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Save as New'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Rename'),
              ),
            ],
          ),
        );
        
        if (confirmRename == null) return;
        
        if (confirmRename == true) {
          // Rename logic
          if (widget.type == 'workout') {
            final repo = ProviderScope.containerOf(context).read(workoutRepoProvider);
            await repo.renamePlan(_selectedKey!, newPlanName, _controller.text);
            
            final profileNotifier = ProviderScope.containerOf(context).read(profileProvider.notifier);
            final profile = ProviderScope.containerOf(context).read(profileProvider);
            if (profile.activeWorkoutPlan == _selectedKey) {
              profileNotifier.updateProfile(profile.copyWith(activeWorkoutPlan: newPlanName));
            }
          } else if (widget.type == 'meal') {
            final repo = ProviderScope.containerOf(context).read(mealRepoProvider);
            await repo.renamePlan(_selectedKey!, newPlanName, _controller.text);
            
            final profileNotifier = ProviderScope.containerOf(context).read(profileProvider.notifier);
            final profile = ProviderScope.containerOf(context).read(profileProvider);
            if (profile.activeMealPlan == _selectedKey) {
              profileNotifier.updateProfile(profile.copyWith(activeMealPlan: newPlanName));
            }
          }
          
          setState(() {
            _selectedKey = newPlanName;
          });
        } else {
          // Save as new
          await widget.saveJson(newPlanName, _controller.text);
          setState(() {
            _selectedKey = newPlanName;
          });
        }
      } else {
        await widget.saveJson(_selectedKey!, _controller.text);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Plan saved successfully'),
            backgroundColor: context.colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('FormatException: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validation Error: $errorMsg'),
            backgroundColor: context.colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}
