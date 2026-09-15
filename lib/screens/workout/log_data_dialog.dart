import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_units.dart';
import '../../providers/app_providers.dart';
import '../../models/workout_plan.dart';
import '../../models/exercise_log.dart';
import '../../utils/exercise_log_save.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';
import '../../theme/layout_insets.dart';
import '../../theme/app_spacing.dart';


import '../../utils/target_parser.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class LogDataDialog extends ConsumerStatefulWidget {
  const LogDataDialog({super.key, required this.exercise});

  final Exercise exercise;

  @override
  ConsumerState<LogDataDialog> createState() => _LogDataDialogState();
}

class _LogDataDialogState extends ConsumerState<LogDataDialog> {
  late List<TextEditingController> _repsControllers;
  late List<TextEditingController> _weightControllers;
  ExerciseLog? _lastLog;

  @override
  void initState() {
    super.initState();
    final setCount = widget.exercise.setCount;
    _repsControllers = List.generate(setCount, (i) {
      return TextEditingController(
        // ignore: dead_code, dead_null_aware_expression
        text: TargetParser.parseRepTarget(widget.exercise.repsDisplay ?? '').toString(),
      );
    });
    final profile = ref.read(profileProvider);
    _weightControllers = List.generate(setCount, (i) {
      final planned = widget.exercise.weightKg;
      return TextEditingController(
        text: planned != null && planned > 0 
          ? convertFromKg(profile, planned).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '') 
          : '',
      );
    });

    _loadExistingData();
  }

  void _loadExistingData() {
    final dateStr = ref.read(dateStringProvider);
    final repo = ref.read(exerciseLogRepoProvider);
    final profile = ref.read(profileProvider);
    final existing = repo.getLog(dateStr, widget.exercise.instanceId ?? widget.exercise.name ?? '');

    if (existing != null) {
      for (
        int i = 0;
        i < existing.sets.length && i < _repsControllers.length;
        i++
      ) {
        _repsControllers[i].text = (existing.sets[i].reps ?? 0).toString();
        final w = existing.sets[i].weight ?? 0.0;
        _weightControllers[i].text = w > 0
            ? convertFromKg(profile, w).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')
            : '';
      }
    } else {
      _lastLog = repo.getLastLog(widget.exercise.name ?? '', beforeDate: dateStr);
      if (_lastLog != null) {
        for (
          int i = 0;
          i < _lastLog!.sets.length && i < _weightControllers.length;
          i++
        ) {
          final w = _lastLog!.sets[i].weight ?? 0.0;
          if (w > 0) {
            _weightControllers[i].text = convertFromKg(profile, w).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
          }
          final r = _lastLog!.sets[i].reps ?? 0;
          if (r > 0) {
            _repsControllers[i].text = r.toString();
          }
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _repsControllers) {
      c.dispose();
    }
    for (final c in _weightControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String? _getSubtitle() {
    if (_lastLog == null || _lastLog!.sets.isEmpty) return null;
    try {
      final dt = DateTime.parse(_lastLog!.date);
      final dateStr = DateFormat('MMM d').format(dt);
      final weight = _lastLog!.sets.first.weight ?? 0.0;
      final reps = _lastLog!.sets.map((s) => s.reps ?? 0).join(', ');
      return 'Last time ($dateStr): ${weight > 0 ? '${formatWeight(ref.watch(profileProvider), weight)} × ' : ''}$reps';
    } catch (_) {
      return null;
    }
  }

  void _fillFromPlan() {
    setState(() {
      for (int i = 0; i < widget.exercise.setCount; i++) {
        // ignore: dead_code, dead_null_aware_expression
        _repsControllers[i].text = TargetParser.parseRepTarget(
          widget.exercise.repsDisplay ?? '',
        ).toString();
        final planned = widget.exercise.weightKg;
        if (planned != null && planned > 0) {
          _weightControllers[i].text = planned.toString();
        } else if (_lastLog != null &&
            i < _lastLog!.sets.length &&
            (_lastLog!.sets[i].weight ?? 0.0) > 0) {
          _weightControllers[i].text = (_lastLog!.sets[i].weight ?? 0.0)
              .toString();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _getSubtitle();

    return AppSheet(
      title: 'Log: ${widget.exercise.name ?? ''}',
      subtitle:
          subtitle ??
          '${widget.exercise.setCount} set${widget.exercise.setCount > 1 ? 's' : ''}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: Text(
                  'Reps',
                  textAlign: TextAlign.center,
                  style: context.text.micro.copyWith(color: context.colors.textLight),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Weight (${ref.watch(profileProvider).useKg ? 'kg' : 'lb'})',
                  textAlign: TextAlign.center,
                  style: context.text.micro.copyWith(color: context.colors.textLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(widget.exercise.setCount, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      'Set ${i + 1}',
                      style: AppTheme.numeric(
                        context.text.body.copyWith(color: context.colors.textDark),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      label: 'Reps for set ${i + 1}',
                      child: _StepperField(
                        controller: _repsControllers[i],
                        isWeight: false,
                        hint: '0',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      label: 'Weight in kg for set ${i + 1}',
                      child: _StepperField(
                        controller: _weightControllers[i],
                        isWeight: true,
                        hint: _lastLog != null && i < _lastLog!.sets.length
                            ? (_lastLog!.sets[i].weight ?? 0.0).toString()
                            : '0',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: kPrimaryButtonHeight,
            child: OutlinedButton(
              onPressed: () async {
                _fillFromPlan();
                await _persistAndClose(widget.exercise);
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kButtonRadius),
                ),
              ),
              child: const Text('Log as planned'),
            ),
          ),
          const SizedBox(height: Spacing.stack),
          Semantics(
            label: 'Save Log Data',
            button: true,
            child: PrimaryButton(label: 'Save Log', onPressed: _save),
          ),
          SizedBox(
            height: MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.paddingOf(context).bottom,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final sets = <SetLog>[];
    final profile = ref.read(profileProvider);
    
    for (int i = 0; i < widget.exercise.setCount; i++) {
      final reps = int.tryParse(_repsControllers[i].text);
      final weightRaw = double.tryParse(_weightControllers[i].text);
      
      if (reps == null || reps <= 0) continue;
      if (weightRaw == null || weightRaw < 0) continue;
      
      final weightKg = convertToKg(profile, weightRaw);
      sets.add(SetLog(setNumber: sets.length + 1, reps: reps, weight: weightKg));
    }

    final repo = ref.read(exerciseLogRepoProvider);
    final dateStr = ref.read(dateStringProvider);

    if (sets.isEmpty) {
      await repo.deleteLog(dateStr, widget.exercise.instanceId ?? widget.exercise.name ?? '');
    } else {
      final newLog = ExerciseLog(
        date: dateStr,
        instanceId: widget.exercise.instanceId ?? widget.exercise.name ?? '',
        exerciseName: widget.exercise.name ?? '',
        sets: sets,
      );
      await repo.saveLog(newLog);
    }
    
    ref.read(exerciseLogsUpdateProvider.notifier).state++;

    final prResult = await checkAndSavePr(
      ref: ref,
      exerciseName: widget.exercise.name ?? '',
      sets: sets,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    _showResultSnack(prResult);
  }

  Future<void> _persistAndClose(Exercise exercise) async {
    final prResult = await saveExerciseAsPlanned(ref: ref, exercise: exercise);

    if (!mounted) return;
    Navigator.of(context).pop();
    _showResultSnack(prResult);
  }

  void _showResultSnack(PrUpdateResult prResult) {
    String msg = 'Logged ${widget.exercise.name ?? ''}';
    if (prResult.hasAnyNewPr) {
      if (prResult.isNewMaxWeight) {
        msg =
            'New PR! ${formatWeight(ref.watch(profileProvider), prResult.newPr.maxWeight)}';
      } else if (prResult.isNewMaxReps) {
        msg = 'New PR! ${prResult.newPr.maxReps} reps';
      } else if (prResult.isNewMaxVolume) {
        msg = 'New Volume PR!';
      } else if (prResult.isNew1RM) {
        msg = 'New 1RM PR!';
      }
    }


    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: prResult.hasAnyNewPr
            ? context.colors.green
            : context.colors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.controller,
    required this.isWeight,
    this.hint,
  });

  final TextEditingController controller;
  final bool isWeight;
  final String? hint;

  void _increment(double amount) {
    final val = double.tryParse(controller.text) ?? 0.0;
    final newVal = val + amount;
    if (newVal < 0) return;
    if (isWeight) {
      controller.text = newVal
          .toStringAsFixed(1)
          .replaceAll(RegExp(r'\.0$'), '');
    } else {
      controller.text = newVal.toInt().toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = isWeight ? 2.5 : 1.0;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.inputFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _increment(-step),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(13.0),
              child: Icon(
                Icons.remove_rounded,
                size: 18,
                color: context.colors.primary,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: isWeight),
              textAlign: TextAlign.center,
              style: AppTheme.numeric(
                context.text.bodyStrong.copyWith(color: context.colors.textDark),
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: hint,
                hintStyle: context.text.body.copyWith(color: context.colors.textLight),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _increment(step),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(13.0),
              child: Icon(
                Icons.add_rounded,
                size: 18,
                color: context.colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
