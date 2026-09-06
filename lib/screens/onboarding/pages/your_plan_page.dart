import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../models/habit.dart';
import '../../../utils/habit_icons.dart';
import '../../../utils/target_calculator.dart';
import 'package:flutter_animate/flutter_animate.dart';

class YourPlanPage extends StatefulWidget {
  final double initialCalories;
  final double heightCm;
  final double? weightKg;
  final List<String> selectedHabitIds;
  final ValueChanged<double> onCaloriesChanged;
  final void Function(String id, bool selected) onHabitToggled;

  const YourPlanPage({
    super.key,
    required this.initialCalories,
    required this.heightCm,
    this.weightKg,
    required this.selectedHabitIds,
    required this.onCaloriesChanged,
    required this.onHabitToggled,
  });

  @override
  State<YourPlanPage> createState() => _YourPlanPageState();
}

class _YourPlanPageState extends State<YourPlanPage> with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  late double _currentCalories;
  TargetMacros? _macroPreview;

  @override
  void initState() {
    super.initState();
    _currentCalories = widget.initialCalories;
    _staggerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _staggerController.forward();
    _updateMacroPreview();
  }

  void _updateMacroPreview() {
    if (widget.weightKg != null) {
      _macroPreview = TargetCalculator.calculate(
        heightCm: widget.heightCm,
        weightKg: widget.weightKg!,
        age: 30, // Default assumption since not asked
        gender: 'M',
        goal: 'Maintain',
        activityLevel: 'Sedentary',
      );
    }
  }

  void _suggestMacros() {
    if (_macroPreview != null) {
      setState(() {
        _currentCalories = _macroPreview!.calories.toDouble();
        widget.onCaloriesChanged(_currentCalories);
      });
    }
  }

  Widget _buildAnimEntrance(int index, Widget child) {
    final start = index * 0.1;
    final end = (start + 0.5).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, animChild) {
        final slide = CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ).value;
        final fade = CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end - 0.2, curve: Curves.easeIn),
        ).value;
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - slide)),
            child: animChild,
          ),
        );
      },
      child: child,
    );
  }

  TargetMacros? _getDynamicMacrosForCalories(double cal) {
    if (_macroPreview == null) return null;
    final factor = cal / _macroPreview!.calories;
    return TargetMacros(
      calories: cal.round(),
      proteinG: (_macroPreview!.proteinG * factor).round(),
      carbsG: (_macroPreview!.carbsG * factor).round(),
      fatG: (_macroPreview!.fatG * factor).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dynamicMacros = _getDynamicMacrosForCalories(_currentCalories);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 64),
          _buildAnimEntrance(
            0,
            Column(
              children: [
                Icon(
                  Icons.track_changes_outlined,
                  size: 48,
                  color: context.colors.primary,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your Plan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cabinet Grotesk',
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildAnimEntrance(
            1,
            Column(
              children: [
                Text(
                  '${_currentCalories.round()} kcal',
                  style: TextStyle(
                    fontFamily: 'Cabinet Grotesk',
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: context.colors.primary,
                  ),
                ),
                if (_macroPreview != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: ActionChip(
                      label: const Text('Suggest for me'),
                      avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                      backgroundColor: context.colors.primary.withOpacity(0.15),
                      labelStyle: TextStyle(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'General Sans'),
                      side: BorderSide(
                          color: context.colors.primary.withOpacity(0.3)),
                      onPressed: _suggestMacros,
                    ),
                  ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: context.colors.primary,
                    thumbColor: context.colors.primary,
                    inactiveTrackColor: Colors.white.withOpacity(0.1),
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: _currentCalories,
                    min: 1200,
                    max: 4000,
                    divisions: (4000 - 1200) ~/ 50,
                    onChanged: (v) {
                      setState(() => _currentCalories = v);
                      widget.onCaloriesChanged(v);
                    },
                  ),
                ),
                if (dynamicMacros != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MacroChip(label: '${dynamicMacros.proteinG}g', color: context.colors.red),
                        const SizedBox(width: 8),
                        _MacroChip(label: '${dynamicMacros.carbsG}g', color: context.colors.orange),
                        const SizedBox(width: 8),
                        _MacroChip(label: '${dynamicMacros.fatG}g', color: context.colors.primary),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildAnimEntrance(
            2,
            Column(
              children: [
                Text(
                  'Select Habits',
                  style: TextStyle(
                    fontFamily: 'General Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
                ...Habit.defaults.map((habit) {
                  final selected = widget.selectedHabitIds.contains(habit.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HabitTile(
                      habit: habit,
                      selected: selected,
                      onToggle: (s) => widget.onHabitToggled(habit.id, s),
                    ),
                  );
                }),
                if (widget.selectedHabitIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Please select at least one habit to track.',
                      style: TextStyle(
                        fontFamily: 'General Sans',
                        color: context.colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MacroChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'General Sans',
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  final Habit habit;
  final bool selected;
  final ValueChanged<bool> onToggle;

  const _HabitTile({
    required this.habit,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!selected),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? context.colors.primary.withOpacity(0.15) : context.colors.inputFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              HabitIcons.resolve(habit.icon),
              size: 24,
              color: selected ? context.colors.primary : context.colors.textMedium,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                habit.name,
                style: TextStyle(
                  fontFamily: 'General Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : context.colors.textDark,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: context.colors.primary, size: 24),
          ],
        ),
      ).animate(target: selected ? 1 : 0)
       .scale(
         begin: const Offset(1, 1), 
         end: const Offset(0.97, 0.97), 
         duration: 100.ms, 
         curve: Curves.easeOutCubic,
       )
       .then()
       .scale(
         begin: const Offset(0.97, 0.97), 
         end: const Offset(1, 1), 
         duration: 200.ms, 
         curve: Curves.easeOutBack,
       )
       .shimmer(duration: 500.ms, color: Colors.white.withValues(alpha: 0.2)),
    );
  }
}
