import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../models/habit.dart';
import '../../utils/habit_icons.dart';

class ManageHabitsScreen extends ConsumerStatefulWidget {
  const ManageHabitsScreen({super.key});

  @override
  ConsumerState<ManageHabitsScreen> createState() => _ManageHabitsScreenState();
}

class _ManageHabitsScreenState extends ConsumerState<ManageHabitsScreen> {
  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Manage Habits',
          style: TextStyle(
            color: context.colors.textDark,
            fontFamily: 'Cabinet Grotesk',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: context.colors.scaffoldBg,
        foregroundColor: context.colors.textDark,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: context.colors.textDark,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_rounded,
              color: context.colors.primary,
            ),
            tooltip: 'Remind me daily',
            onPressed: () => context.go('/profile/reminders'),
          ),
        ],
      ),
      body: habits.isEmpty
          ? Center(
              child: Text(
                'No habits found. Add one!',
                style: TextStyle(color: context.colors.textMedium),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
              itemCount: habits.length,
              // ignore: deprecated_member_use
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final list = List<Habit>.from(habits);
                final item = list.removeAt(oldIndex);
                list.insert(newIndex, item);
                ref.read(habitRepoProvider).reorderHabits(list).then((_) {
                  ref.invalidate(habitsProvider);
                });
              },
              itemBuilder: (context, index) {
                final habit = habits[index];
                return _HabitListTile(key: ValueKey(habit.id), habit: habit);
              },
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () => _showEditorDialog(context, ref, null),
          backgroundColor: context.colors.primary,
          icon: Icon(Icons.add, color: context.colors.onPrimary),
          label: Text(
            'Add Habit',
            style: TextStyle(color: context.colors.onPrimary),
          ),
        ),
      ),
    );
  }

  void _showEditorDialog(BuildContext context, WidgetRef ref, Habit? habit) {
    showDialog(
      context: context,
      builder: (ctx) => _HabitEditorDialog(habit: habit),
    );
  }
}

class _HabitListTile extends ConsumerWidget {
  final Habit habit;
  const _HabitListTile({super.key, required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: key,
      // No border, floating item
      child: ListTile(
        leading: Icon(
          HabitIcons.resolve(habit.icon),
          color: context.colors.primary,
          size: 28,
        ),
        title: Text(
          habit.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.colors.textDark,
          ),
        ),
        subtitle: Text(
          _getTypeDescription(habit),
          style: TextStyle(color: context.colors.textMedium),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_rounded, color: context.colors.textMedium),
              tooltip: 'Edit habit',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => _HabitEditorDialog(habit: habit),
                );
              },
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: context.colors.textMedium,
              ),
              tooltip: 'Delete habit',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    bool isDeleting = false;
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return AlertDialog(
                          backgroundColor: context.colors.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          title: Text(
                            'Delete Habit?',
                            style: TextStyle(
                              fontFamily: 'Cabinet Grotesk',
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: context.colors.textDark,
                            ),
                          ),
                          content: Text(
                            'Are you sure you want to delete this habit? History will be kept for past days, but it won\'t appear anymore.',
                            style: TextStyle(color: context.colors.textMedium),
                          ),
                          actions: [
                            TextButton(
                              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: context.colors.textMedium,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: isDeleting
                                  ? null
                                  : () async {
                                      setState(() => isDeleting = true);
                                      try {
                                        await ref.read(habitRepoProvider).deleteHabit(habit.id);
                                        if (!ctx.mounted) return;
                                        ref.invalidate(habitsProvider);
                                        Navigator.pop(ctx);
                                      } catch (e) {
                                        if (!ctx.mounted) return;
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text('Failed to delete: $e')),
                                        );
                                      }
                                    },
                              child: isDeleting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: context.colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ],
                        );
                      }
                    );
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            Icon(Icons.drag_handle_rounded, color: context.colors.textMedium),
          ],
        ),
      ),
    );
  }

  String _getTypeDescription(Habit h) {
    switch (h.type) {
      case HabitType.checkbox:
        if (h.unit.isNotEmpty && h.target > 0) {
          final t = h.target == h.target.roundToDouble()
              ? h.target.toInt().toString()
              : h.target.toString();
          return 'Tap once · Goal: $t ${h.unit}';
        }
        return 'Tap once to complete';
      case HabitType.counter:
        return 'Counter (Target: ${h.target} ${h.unit})';
      case HabitType.autoSteps:
        return 'Auto from Steps (Target: ${h.target})';
      case HabitType.autoSleep:
        return 'From sleep log (Target: ${h.target} hrs)';
      case HabitType.autoFromScreenTime:
        return 'From screen time (Target: ${h.target} mins)';
      case HabitType.timer:
        return 'Timer (Target: ${h.target} mins)';
    }
  }
}

class _HabitEditorDialog extends ConsumerStatefulWidget {
  final Habit? habit;
  const _HabitEditorDialog({this.habit});

  @override
  ConsumerState<_HabitEditorDialog> createState() => _HabitEditorDialogState();
}

class _HabitEditorDialogState extends ConsumerState<_HabitEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _stepCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();

  String? _targetError;
  String? _stepError;
  String? _nameError;

  String _selectedIcon = 'check';
  HabitType _type = HabitType.checkbox;
  bool _isWaterHabit = false;
  List<int>? _activeDays;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.habit != null) {
      final h = widget.habit!;
      _isWaterHabit = h.id == 'water';
      _nameCtrl.text = h.name;
      _selectedIcon = HabitIcons.normalize(h.icon);
      _type = h.type;
      _targetCtrl.text = h.target.toString();
      _stepCtrl.text = h.step.toString();
      _unitCtrl.text = h.unit;
      _activeDays = h.activeDays != null ? List<int>.from(h.activeDays!) : null;
    } else {
      _targetCtrl.text = '1';
      _stepCtrl.text = '1';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _stepCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  void _syncWaterNameFromGoal() {
    if (!_isWaterHabit) return;
    final currentName = _nameCtrl.text.trim();
    if (currentName.isNotEmpty && !currentName.startsWith('Drink ') && !currentName.endsWith(' of water')) {
      // User has customized the name, don't overwrite it
      return;
    }
    
    final target = double.tryParse(_targetCtrl.text) ?? 3.0;
    final unit = _unitCtrl.text.trim().isEmpty ? 'L' : _unitCtrl.text.trim();
    final targetLabel = target == target.roundToDouble()
        ? target.toInt().toString()
        : target.toString();
    _nameCtrl.text = 'Drink $targetLabel $unit of water';
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    var name = _nameCtrl.text.trim();
    bool hasError = false;

    if (name.isEmpty && !_isWaterHabit) {
      setState(() => _nameError = 'Name is required');
      hasError = true;
    } else {
      setState(() => _nameError = null);
    }

    var target = 1.0;
    var step = 1.0;
    var unit = _unitCtrl.text.trim();

    if (_showGoalFields) {
      final pTarget = double.tryParse(_targetCtrl.text);
      if (pTarget == null || !pTarget.isFinite || pTarget <= 0) {
        setState(() => _targetError = 'Must be > 0');
        hasError = true;
      } else {
        target = pTarget;
        setState(() => _targetError = null);
      }
    } else {
      setState(() => _targetError = null);
    }
    
    if (_type == HabitType.counter && !_isWaterHabit) {
      final pStep = double.tryParse(_stepCtrl.text);
      if (pStep == null || !pStep.isFinite || pStep <= 0) {
        setState(() => _stepError = 'Must be > 0');
        hasError = true;
      } else {
        step = pStep;
        setState(() => _stepError = null);
      }
    } else {
      setState(() => _stepError = null);
    }

    if (hasError) return;

    // Water: always checkbox with customizable daily goal
    var type = _type;
    if (_isWaterHabit) {
      type = HabitType.checkbox;
      if (unit.isEmpty) unit = 'L';
      if (target <= 0) target = 3.0; // Fallback
      final targetLabel = target == target.roundToDouble()
          ? target.toInt().toString()
          : target.toString();
      name = 'Drink $targetLabel $unit of water';
    }

    final isNew = widget.habit == null;
    final id = isNew
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : widget.habit!.id;

    final updated = Habit(
      id: id,
      name: name,
      icon: HabitIcons.normalize(_selectedIcon),
      type: type,
      target: target,
      activeDays: (_activeDays != null && _activeDays!.isEmpty) ? [] : _activeDays,
      step: step,
      unit: unit,
      order: isNew ? ref.read(habitsProvider).length : widget.habit!.order,
    );

    setState(() => _isSaving = true);
    try {
      await ref.read(habitRepoProvider).saveHabit(updated);
      if (!mounted) return;
      ref.invalidate(habitsProvider);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  bool get _showGoalFields => _isWaterHabit || _type != HabitType.checkbox;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        widget.habit == null ? 'Add Habit' : 'Edit Habit',
        style: TextStyle(
          fontFamily: 'Cabinet Grotesk',
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: context.colors.textDark,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              style: TextStyle(color: context.colors.textDark),
              decoration: InputDecoration(
                labelText: _isWaterHabit ? 'Water habit name' : 'Habit name',
                errorText: _nameError,
                hintText: 'e.g. Meditate 10 min',
                filled: true,
                fillColor: context.colors.inputFill,
                labelStyle: TextStyle(color: context.colors.textMedium),
                hintStyle: TextStyle(color: context.colors.textLight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_isWaterHabit) ...[
              const SizedBox(height: 8),
              Text(
                'Daily water goal',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.colors.textMedium,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap once on Home to mark it done. Change how much you aim for below.',
                style: TextStyle(fontSize: 13, color: context.colors.textLight),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Icon',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.colors.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HabitIcons.options.map((opt) {
                final isSelected = opt.id == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = opt.id),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.colors.primary.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      opt.icon,
                      size: 22,
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.textMedium,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Active days',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.colors.textMedium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Leave all days unselected to pause this habit. Select all days to run every day.',
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textLight,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final day = index + 1;
                final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final isSelected = _activeDays == null || _activeDays!.contains(day);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_activeDays == null) {
                        _activeDays = [1, 2, 3, 4, 5, 6, 7];
                      }
                      if (isSelected) {
                        _activeDays!.remove(day);
                      } else {
                        _activeDays!.add(day);
                        if (_activeDays!.length == 7) {
                          _activeDays = null;
                        }
                      }
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? context.colors.primary.withValues(alpha: 0.15) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? context.colors.primary : context.colors.textMedium,
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (!_isWaterHabit) ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<HabitType>(
                initialValue: _type,
                dropdownColor: context.colors.card,
                style: TextStyle(color: context.colors.textDark, fontSize: 14),
                iconEnabledColor: context.colors.textMedium,
                decoration: InputDecoration(
                  labelText: 'Type',
                  labelStyle: TextStyle(color: context.colors.textMedium),
                  filled: true,
                  fillColor: context.colors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: HabitType.checkbox,
                    child: Text(
                      'Checkbox (Tap once)',
                      style: TextStyle(color: context.colors.textDark),
                    ),
                  ),
                  DropdownMenuItem(
                    value: HabitType.counter,
                    child: Text(
                      'Counter (+ / −)',
                      style: TextStyle(color: context.colors.textDark),
                    ),
                  ),
                  DropdownMenuItem(
                    value: HabitType.autoSteps,
                    child: Text(
                      'Auto from Steps',
                      style: TextStyle(color: context.colors.textDark),
                    ),
                  ),
                  DropdownMenuItem(
                    value: HabitType.autoSleep,
                    child: Text(
                      'Auto from Sleep',
                      style: TextStyle(color: context.colors.textDark),
                    ),
                  ),
                  DropdownMenuItem(
                    value: HabitType.autoFromScreenTime,
                    child: Text(
                      'Auto from Screen Time',
                      style: TextStyle(color: context.colors.textDark),
                    ),
                  ),
                  DropdownMenuItem(
                    value: HabitType.timer,
                    child: Text(
                      'Timer (Countdown)',
                      style: TextStyle(color: context.colors.textDark),
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _type = val);
                },
              ),
            ],
            if (_showGoalFields) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetCtrl,
                      style: TextStyle(color: context.colors.textDark),
                      decoration: InputDecoration(
                        labelText: _isWaterHabit ? 'Amount' : 'Target',
                        errorText: _targetError,
                        filled: true,
                        fillColor: context.colors.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) {
                        if (_isWaterHabit) {
                          setState(_syncWaterNameFromGoal);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unitCtrl,
                      style: TextStyle(color: context.colors.textDark),
                      decoration: InputDecoration(
                        labelText: _isWaterHabit ? 'Unit' : 'Unit (e.g. L)',
                        filled: true,
                        fillColor: context.colors.inputFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) {
                        if (_isWaterHabit) {
                          setState(_syncWaterNameFromGoal);
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (_isWaterHabit) ...[
                const SizedBox(height: 12),
                Text(
                  _nameCtrl.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
              ],
            ],
            if (_type == HabitType.counter && !_isWaterHabit) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _stepCtrl,
                style: TextStyle(color: context.colors.textDark),
                decoration: InputDecoration(
                  labelText: 'Increment step (e.g. 0.25)',
                  errorText: _stepError,
                  filled: true,
                  fillColor: context.colors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: context.colors.textMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: context.colors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
