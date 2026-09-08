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

  @override
  void initState() {
    super.initState();
    final log = ref.read(dailyLogProvider);
    if (log.steps != null) {
      _controller.text = log.steps.toString();
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
      title: 'Log Steps',
      subtitle: isToday ? 'Enter your step count for today' : 'Enter your step count for $dateFormatted',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: TextStyle(
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
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Save Steps',
            onPressed: () {
              final steps = int.tryParse(_controller.text);
              if (steps != null && steps > 0 && steps < 100000) {
                Haptics.toggle();
                ref
                    .read(dailyLogProvider.notifier)
                    .updateSteps(steps, source: 'manual');
                Navigator.of(context).pop();
              } else {
                Haptics.error();
                setState(() {
                  _errorText = 'Please enter a valid step count.';
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
