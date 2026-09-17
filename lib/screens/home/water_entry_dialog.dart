import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/app_providers.dart';

import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class WaterEntryDialog extends ConsumerStatefulWidget {
  const WaterEntryDialog({super.key});

  @override
  ConsumerState<WaterEntryDialog> createState() => _WaterEntryDialogState();
}

class _WaterEntryDialogState extends ConsumerState<WaterEntryDialog> {
  final _controller = TextEditingController();
  bool _hasExistingEntry = false;
  int _currentAmount = 0;
  bool _isSaving = false;
  late String _pinnedDateStr;

  @override
  void initState() {
    super.initState();
    _pinnedDateStr = ref.read(dateStringProvider);
    final log = ref.read(dailyLogProvider);
    if (log.waterMl != null && log.waterMl! > 0) {
      _currentAmount = log.waterMl!;
      _controller.text = _currentAmount.toString();
      _hasExistingEntry = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addAmount(int amount) {
    if (_isSaving) return;
    setState(() {
      int currentTextAmount = int.tryParse(_controller.text) ?? 0;
      if (currentTextAmount < 0) currentTextAmount = 0;
      _currentAmount = currentTextAmount + amount;
      _controller.text = _currentAmount.toString();
    });
  }

  void _onTextChanged(String val) {
    if (_isSaving) return;
    setState(() {
      int parsed = int.tryParse(val) ?? 0;
      if (parsed < 0) parsed = 0;
      _currentAmount = parsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateStr = ref.watch(dateStringProvider);
    final selectedDate = DateTime.parse(selectedDateStr);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final isFuture = selectedDate.isAfter(today);
    final dateFormatted = DateFormat('EEE, d MMM').format(selectedDate);

    // Fetch Target
    final habits = ref.watch(habitsProvider);
    final waterHabit = habits
        .where((h) => h.name.toLowerCase().contains('water'))
        .firstOrNull;

    double? targetInMl;
    if (waterHabit != null && waterHabit.target > 0) {
      targetInMl = waterHabit.target.toDouble();
      if (waterHabit.unit.toLowerCase() == 'l' ||
          waterHabit.unit.toLowerCase() == 'liters') {
        targetInMl *= 1000;
      }
    }

    final hasTarget = targetInMl != null && targetInMl > 0;
    final progressFraction = hasTarget
        ? (_currentAmount / targetInMl).clamp(0.0, 1.0)
        : 0.0;
    final isGoalReached = hasTarget && _currentAmount >= targetInMl;

    return AppSheet(
      title: 'Water Intake',
      subtitle: dateFormatted,
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress Display
          if (!isFuture) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_currentAmount ml',
                      style: context.text.display.copyWith(
                        color: isGoalReached
                            ? context.colors.green
                            : context.colors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasTarget)
                      Text(
                        'Goal: ${targetInMl.toInt()} ml',
                        style: context.text.body.copyWith(
                          color: context.colors.textMedium,
                        ),
                      )
                    else
                      Text(
                        'No goal set',
                        style: context.text.body.copyWith(
                          color: context.colors.textMedium,
                        ),
                      ),
                  ],
                ),
                if (isGoalReached)
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: context.colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Goal reached',
                        style: context.text.caption.copyWith(
                          color: context.colors.green,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasTarget)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: progressFraction),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: context.colors.primary.withValues(
                        alpha: 0.1,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isGoalReached
                            ? context.colors.green
                            : context.colors.primary,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
          ],

          if (isFuture)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: context.colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You cannot log water for future dates.',
                      style: context.text.caption.copyWith(
                        color: context.colors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              enabled: !_isSaving,
              style: context.text.display.copyWith(
                color: context.colors.textDark,
              ),
              textAlign: TextAlign.center,
              onChanged: _onTextChanged,
              decoration: InputDecoration(
                filled: true,
                fillColor: context.colors.inputFill,
                hintText: '0',
                hintStyle: context.text.display.copyWith(
                  color: context.colors.textLight,
                ),
                suffixText: 'ml',
                suffixStyle: context.text.cardTitle.copyWith(
                  color: context.colors.textMedium,
                ),
              ),
            ),
            const SizedBox(height: Spacing.block),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _addAmount(250),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      side: BorderSide(
                        color: context.colors.primary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.control),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('+ 250ml', style: context.text.bodyStrong),
                  ),
                ),
                const SizedBox(width: Spacing.inline),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _addAmount(500),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      side: BorderSide(
                        color: context.colors.primary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.control),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('+ 500ml', style: context.text.bodyStrong),
                  ),
                ),
                const SizedBox(width: Spacing.inline),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _addAmount(1000),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      side: BorderSide(
                        color: context.colors.primary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.control),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('+ 1L', style: context.text.bodyStrong),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.section),
            if (_hasExistingEntry) ...[
              Center(
                child: TextButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          try {
                            await ref
                                .read(dailyLogProvider.notifier)
                                .clearWaterForDate(_pinnedDateStr);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          } catch (e) {
                            setState(() => _isSaving = false);
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.red,
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(
                    'Clear entry',
                    style: context.text.bodyStrong.copyWith(
                      color: context.colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.stack),
            ],
            PrimaryButton(
              label: 'Save Intake',
              isLoading: _isSaving,
              onPressed: () async {
                if (_isSaving) return;
                setState(() => _isSaving = true);

                try {
                  if (_currentAmount > 0) {
                    await ref
                        .read(dailyLogProvider.notifier)
                        .updateWaterForDate(
                          _pinnedDateStr,
                          _currentAmount,
                        );
                  } else {
                    await ref
                        .read(dailyLogProvider.notifier)
                        .clearWaterForDate(_pinnedDateStr);
                  }

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  setState(() => _isSaving = false);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
