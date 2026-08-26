import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../models/workout_plan.dart';
import '../../models/exercise_log.dart';
import '../../utils/exercise_log_save.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';

String parseRepTarget(String rep) {
  if (rep.contains('-')) {
    final parts = rep.split('-');
    if (parts.length == 2) return parts[1].trim();
  }
  return rep;
}

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
        text: parseRepTarget(widget.exercise.repsDisplay ?? ''),
      );
    });
    _weightControllers = List.generate(setCount, (i) {
      return TextEditingController(
        text: widget.exercise.weightKg?.toString() ?? '',
      );
    });

    _loadExistingData();
  }

  void _loadExistingData() {
    final dateStr = ref.read(dateStringProvider);
    final repo = ref.read(exerciseLogRepoProvider);
    final existing = repo.getLog(dateStr, widget.exercise.name ?? '');

    if (existing != null) {
      for (int i = 0; i < existing.sets.length && i < _repsControllers.length; i++) {
        _repsControllers[i].text = (existing.sets[i].reps ?? 0).toString();
        _weightControllers[i].text =
            (existing.sets[i].weight ?? 0.0) > 0 ? (existing.sets[i].weight ?? 0.0).toString() : '';
      }
    } else {
      _lastLog = repo.getLastLog(widget.exercise.name ?? '');
      if (_lastLog != null) {
        for (int i = 0; i < _lastLog!.sets.length && i < _weightControllers.length; i++) {
          final w = _lastLog!.sets[i].weight ?? 0.0;
          if (w > 0) {
            _weightControllers[i].text = w.toString();
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
      return 'Last time ($dateStr): ${weight > 0 ? '${weight}kg × ' : ''}$reps';
    } catch (_) {
      return null;
    }
  }

  void _fillFromPlan() {
    setState(() {
      for (int i = 0; i < widget.exercise.setCount; i++) {
        _repsControllers[i].text = parseRepTarget(widget.exercise.repsDisplay ?? '');
        final planned = widget.exercise.weightKg;
        if (planned != null && planned > 0) {
          _weightControllers[i].text = planned.toString();
        } else if (_lastLog != null && i < _lastLog!.sets.length && (_lastLog!.sets[i].weight ?? 0.0) > 0) {
          _weightControllers[i].text = (_lastLog!.sets[i].weight ?? 0.0).toString();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _getSubtitle();

    return AppSheet(
      title: 'Log: ${widget.exercise.name ?? ''}',
      subtitle: subtitle ??
          '${widget.exercise.setCount} set${widget.exercise.setCount > 1 ? 's' : ''}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: 40),
              Expanded(
                child: Text(
                  'REPS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textLight,
                    letterSpacing: 1,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'WEIGHT (kg)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textLight,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          ...List.generate(widget.exercise.setCount, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      'Set ${i + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textDark,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      label: 'Reps for set ${i + 1}',
                      child: TextField(
                        controller: _repsControllers[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      label: 'Weight in kg for set ${i + 1}',
                      child: TextField(
                        controller: _weightControllers[i],
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: _lastLog != null &&
                                  i < _lastLog!.sets.length
                              ? (_lastLog!.sets[i].weight ?? 0.0).toString()
                              : '0',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () async {
                _fillFromPlan();
                await _persistAndClose(
                  widget.exercise,
                );
              },
              child: Text('Log as planned'),
            ),
          ),
          SizedBox(height: 10),
          Semantics(
            label: 'Save Log Data',
            button: true,
            child: PrimaryButton(label: 'Save Log', onPressed: _save),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final sets = <SetLog>[];
    for (int i = 0; i < widget.exercise.setCount; i++) {
      final reps = int.tryParse(_repsControllers[i].text) ?? 0;
      final weight = double.tryParse(_weightControllers[i].text) ?? 0;
      sets.add(SetLog(setNumber: i + 1, reps: reps, weight: weight));
    }
    
    final repo = ref.read(exerciseLogRepoProvider);
    final dateStr = ref.read(dateStringProvider);
    final newLog = ExerciseLog(
      date: dateStr,
      exerciseName: widget.exercise.name ?? '',
      sets: sets,
    );
    await repo.saveLog(newLog);
    await _persistAndClose(widget.exercise);
  }

  Future<void> _persistAndClose(Exercise exercise) async {
    final prResult = await saveExerciseAsPlanned(
      ref: ref,
      exercise: exercise,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    _showResultSnack(prResult);
  }

  void _showResultSnack(PrUpdateResult prResult) {
    String msg = 'Logged ${widget.exercise.name ?? ''}';
    if (prResult.hasAnyNewPr) {
      if (prResult.isNewMaxWeight) {
        msg = 'New PR! ${prResult.newPr.maxWeight}kg';
      } else if (prResult.isNewMaxReps) {
        msg = 'New PR! ${prResult.newPr.maxReps} reps';
      } else if (prResult.isNewMaxVolume) {
        msg = 'New Volume PR!';
      } else if (prResult.isNew1RM) {
        msg = 'New 1RM PR!';
      }
    }

    final timerActive = ref.read(restTimerProvider).isActive;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            prResult.hasAnyNewPr ? context.colors.green : context.colors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 16,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
