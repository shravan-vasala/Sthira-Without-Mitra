import 'package:flutter/material.dart';
import '../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';

import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';

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

    return AppSheet(
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Log Sleep',
                style: TextStyle(
                  fontFamily: 'Cabinet Grotesk',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textDark,
                ),
              ),
              if (_hasExistingEntry)
                TextButton(
                  onPressed: () async {
                    await ref.read(dailyLogProvider.notifier).clearSleepForDate(_pinnedDateStr);
                    if (mounted) Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.pinkIcon,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                  ),
                  child: const Text('Clear entry'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Logging sleep for the night of $nightBeforeFormatted\n(Waking up on $dateFormatted)',
            style: TextStyle(fontSize: 14, color: context.colors.textMedium),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontFamily: 'Cabinet Grotesk',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: context.colors.textDark,
            ),
            textAlign: TextAlign.center,
            enabled: !isFuture,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
              // Clear time pickers to show manual entry takes precedence
              setState(() {
                _bedtime = null;
                _waketime = null;
              });
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: context.colors.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              hintText: '0.0',
              hintStyle: TextStyle(
                fontFamily: 'Cabinet Grotesk',
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: context.colors.textLight,
              ),
              suffixText: 'hrs',
              suffixStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textMedium,
              ),
            ),
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  _errorText!,
                  style: TextStyle(
                    color: context.colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Or calculate automatically from times:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textMedium,
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 24),
          PrimaryButton(
            label: isFuture ? 'Cannot log for future date' : 'Save Sleep',
            onPressed: isFuture
                ? null
                : () async {
                    final sleepHours = double.tryParse(_controller.text);
                    if (sleepHours != null &&
                        sleepHours >= 0 &&
                        sleepHours <= 24) {
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
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.colors.textMedium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time != null ? time!.format(context) : '--:--',
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: time != null
                    ? context.colors.textDark
                    : context.colors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
