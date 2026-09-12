import 'package:flutter/material.dart';
import '../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';

class StepsEntryDialog extends ConsumerStatefulWidget {

  const StepsEntryDialog({super.key});

  @override
  ConsumerState<StepsEntryDialog> createState() => _StepsEntryDialogState();
}

class _StepsEntryDialogState extends ConsumerState<StepsEntryDialog> {
  final _controller = TextEditingController();
  String? _errorText;
  late String _pinnedDateStr;
  bool _hasExistingEntry = false;
  bool _isHealthConnect = false;

  @override
  void initState() {
    super.initState();
    _pinnedDateStr = ref.read(dateStringProvider);
    final log = ref.read(dailyLogProvider);
    if (log.steps != null && log.steps! >= 0) {
      _controller.text = log.steps.toString();
      _hasExistingEntry = true;
    }
    if (log.stepsSource == 'healthConnect') {
      _isHealthConnect = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateStr = ref.watch(dateStringProvider);
    final selectedDate = DateTime.parse(selectedDateStr);
    final isToday = DateTime.now().year == selectedDate.year &&
        DateTime.now().month == selectedDate.month &&
        DateTime.now().day == selectedDate.day;

    final monthStr = const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][selectedDate.month - 1];
    final dateFormatted = '${selectedDate.day} $monthStr';

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
                'Log Steps',
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
                    await ref.read(dailyLogProvider.notifier).clearStepsForDate(_pinnedDateStr);
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
            isToday ? 'Enter your step count for today' : 'Enter your step count for $dateFormatted',
            style: TextStyle(
              fontSize: 16,
              color: context.colors.textMedium,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: TextStyle(
              fontFamily: 'Cabinet Grotesk',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: context.colors.textDark,
            ),
            textAlign: TextAlign.center,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: context.colors.inputFill,
              hintText: '0',
              hintStyle: TextStyle(
                fontFamily: 'Cabinet Grotesk',
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: context.colors.textLight,
              ),
              suffixText: 'steps',
              suffixStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textMedium,
              ),
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
            ),
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _errorText!,
                style: TextStyle(
                  color: context.colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (_isHealthConnect)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.health_and_safety, size: 16, color: context.colors.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Synced from Health Connect. Manual saves will override sync for this day.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textMedium,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Save Steps',
            onPressed: () async {
              if (_controller.text.trim().isEmpty) {
                Haptics.toggle();
                await ref.read(dailyLogProvider.notifier).clearStepsForDate(_pinnedDateStr);
                if (mounted) Navigator.of(context).pop();
                return;
              }

              final steps = int.tryParse(_controller.text);
              if (steps != null && steps >= 0) {
                Haptics.toggle();
                await ref.read(dailyLogProvider.notifier).updateStepsForDate(_pinnedDateStr, steps);
                if (mounted) Navigator.of(context).pop();
              } else {
                Haptics.error();
                setState(() => _errorText = 'Please enter a valid number (≥ 0)');
              }
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
