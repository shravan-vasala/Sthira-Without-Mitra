import 'package:flutter/material.dart';
import '../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../providers/app_providers.dart';

import '../../widgets/numeric_entry_sheet.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class SleepEntryDialog extends ConsumerStatefulWidget {
  const SleepEntryDialog({super.key});

  @override
  ConsumerState<SleepEntryDialog> createState() => _SleepEntryDialogState();
}

class _SleepEntryDialogState extends ConsumerState<SleepEntryDialog> {
  final _controller = TextEditingController();
  TimeOfDay? _bedtime;
  TimeOfDay? _waketime;
  bool _hasExistingEntry = false;
  String? _errorText;
  late String _pinnedDateStr;

  @override
  void initState() {
    super.initState();
    _pinnedDateStr = ref.read(dateStringProvider);
    final log = ref.read(dailyLogProvider);
    if (log.sleepHours != null) {
      _controller.text = log.sleepHours!.toStringAsFixed(1);
      _hasExistingEntry = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateDurationFromTimes() {
    if (_bedtime == null || _waketime == null) return;

    // Compute duration
    final double bedHours = _bedtime!.hour + _bedtime!.minute / 60.0;
    final double wakeHours = _waketime!.hour + _waketime!.minute / 60.0;

    double duration = wakeHours - bedHours;
    if (duration < 0) {
      duration += 24.0;
    }

    _controller.text = duration.toStringAsFixed(1);
  }

  Future<void> _pickTime(bool isBedtime) async {
    final initialTime = isBedtime
        ? (_bedtime ?? const TimeOfDay(hour: 22, minute: 0))
        : (_waketime ?? const TimeOfDay(hour: 6, minute: 0));
    final parentTheme = Theme.of(context);

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (ctx, child) {
        if (child == null) return const SizedBox.shrink();
        return Theme(
          data: parentTheme.copyWith(
            colorScheme: parentTheme.colorScheme.copyWith(
              primary: context.colors.primary,
              onPrimary: context.colors.onPrimary,
              onSurface: context.colors.textDark,
            ),
          ),
          child: child,
        );
      },
    );

    if (!mounted) return;

    if (time != null) {
      setState(() {
        if (isBedtime) {
          _bedtime = time;
        } else {
          _waketime = time;
        }
      });
      _updateDurationFromTimes();
    }
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
    final nightBeforeFormatted = DateFormat('EEE, d MMM').format(selectedDate.subtract(const Duration(days: 1)));

    return NumericEntrySheet(
      title: 'Log Sleep',
      subtitle: 'Logging sleep for the night of $nightBeforeFormatted\n(Waking up on $dateFormatted)',
      controller: _controller,
      suffixText: 'hrs',
      hintText: '0.0',
      errorText: _errorText,
      autofocus: true,
      onChanged: (_) {
        if (_errorText != null) {
          setState(() => _errorText = null);
        }
        setState(() {
          _bedtime = null;
          _waketime = null;
        });
      },
      saveLabel: isFuture ? 'Cannot log for future date' : 'Save Sleep',
      onSave: isFuture
          ? null
          : () async {
              final sleepHours = double.tryParse(_controller.text);
              if (sleepHours != null && sleepHours >= 0 && sleepHours <= 24) {
                Haptics.toggle();
                await ref.read(dailyLogProvider.notifier).updateSleepForDate(_pinnedDateStr, sleepHours);
                if (mounted) Navigator.of(context).pop();
              } else {
                Haptics.error();
                setState(() {
                  _errorText = 'Please enter a value between 0 and 24 hours.';
                });
              }
            },
      onClear: _hasExistingEntry
          ? () async {
              await ref.read(dailyLogProvider.notifier).clearSleepForDate(_pinnedDateStr);
              if (mounted) Navigator.of(context).pop();
            }
          : null,
      extraContentBuilder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Or calculate automatically from times:',
            style: context.text.body.copyWith(color: context.colors.textMedium),
          ),
          const SizedBox(height: Spacing.stack),
          Row(
            children: [
              Expanded(
                child: _TimePickerCard(
                  title: 'Bedtime',
                  time: _bedtime,
                  onTap: isFuture ? null : () => _pickTime(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePickerCard(
                  title: 'Wake up',
                  time: _waketime,
                  onTap: isFuture ? null : () => _pickTime(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimePickerCard extends StatelessWidget {
  const _TimePickerCard({
    required this.title,
    required this.time,
    required this.onTap,
  });

  final String title;
  final TimeOfDay? time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.text.caption.copyWith(color: context.colors.textMedium),
            ),
            const SizedBox(height: 4),
            Text(
              time != null ? time!.format(context) : '--:--',
              style: context.text.cardTitle.copyWith(color: time != null
                    ? context.colors.textDark
                    : context.colors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}
