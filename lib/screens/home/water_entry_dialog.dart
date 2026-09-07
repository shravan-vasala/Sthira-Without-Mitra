import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/widget_update_service.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';

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

  @override
  void initState() {
    super.initState();
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
      final currentTextAmount = int.tryParse(_controller.text) ?? 0;
      _currentAmount = currentTextAmount + amount;
      _controller.text = _currentAmount.toString();
    });
  }

  void _onTextChanged(String val) {
    if (_isSaving) return;
    setState(() {
      _currentAmount = int.tryParse(val) ?? 0;
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Water Intake',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.colors.lavenderCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  dateFormatted,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

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
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isGoalReached ? context.colors.green : context.colors.primary,
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasTarget)
                      Text(
                        'Goal: ${targetInMl.toInt()} ml',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textMedium,
                        ),
                      )
                    else
                      Text(
                        'No goal set',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
                      backgroundColor: context.colors.primary.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isGoalReached ? context.colors.green : context.colors.primary,
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
                      style: TextStyle(
                        color: context.colors.textDark,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              'Total (ml)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    enabled: !_isSaving,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textDark,
                    ),
                    onChanged: _onTextChanged,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.colors.card,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      suffixText: 'ml',
                      suffixStyle: TextStyle(
                        fontSize: 16,
                        color: context.colors.textMedium,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: context.colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: context.colors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      '+ 250ml',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _addAmount(500),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      side: BorderSide(
                        color: context.colors.primary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      '+ 500ml',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _addAmount(1000),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      side: BorderSide(
                        color: context.colors.primary.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      '+ 1L',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (_hasExistingEntry) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              setState(() => _isSaving = true);
                              try {
                                await ref.read(dailyLogProvider.notifier).clearWater();

                                if (waterHabit != null) {
                                  // ignore: unawaited_futures
                                  ref
                                      .read(habitCompletionsProvider.notifier)
                                      .setOverride(waterHabit.id, 'none');
                                }
                                if (context.mounted) Navigator.of(context).pop();
                              } catch (e) {
                                setState(() => _isSaving = false);
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.red,
                        side: BorderSide(
                          color: context.colors.red.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: 'Save Intake',
                    isLoading: _isSaving,
                    onPressed: () async {
                      if (_isSaving) return;
                      setState(() => _isSaving = true);

                      try {
                        if (_currentAmount > 0) {
                          await ref
                              .read(dailyLogProvider.notifier)
                              .updateWater(_currentAmount);

                          if (waterHabit != null) {
                            if (isGoalReached) {
                              // ignore: unawaited_futures
                              ref
                                  .read(habitCompletionsProvider.notifier)
                                  .setOverride(waterHabit.id, 'done');
                            } else {
                              // ignore: unawaited_futures
                              ref
                                  .read(habitCompletionsProvider.notifier)
                                  .setOverride(waterHabit.id, 'none');
                            }
                          }
                        } else {
                          // Clear water if saved with 0
                          await ref.read(dailyLogProvider.notifier).clearWater();
                          if (waterHabit != null) {
                            // ignore: unawaited_futures
                            ref
                                .read(habitCompletionsProvider.notifier)
                                .setOverride(waterHabit.id, 'none');
                          }
                        }

                        if (context.mounted) Navigator.of(context).pop();
                      } catch (e) {
                        setState(() => _isSaving = false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
