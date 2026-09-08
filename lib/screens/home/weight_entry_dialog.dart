import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/haptics.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../services/widget_update_service.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';

class WeightEntryDialog extends ConsumerStatefulWidget {
  const WeightEntryDialog({super.key});

  @override
  ConsumerState<WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends ConsumerState<WeightEntryDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final log = ref.read(dailyLogProvider);
    if (log.weight != null) {
      _controller.text = log.weight!.toStringAsFixed(1);
      return;
    }

    final dateStr = ref.read(dateStringProvider);
    final end = DateTime.parse(dateStr).subtract(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 90));
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final logs = ref
        .read(dailyLogRepoProvider)
        .getLogsInRange(fmt(start), fmt(end));
    for (int i = logs.length - 1; i >= 0; i--) {
      final w = logs[i].weight;
      if (w != null) {
        _controller.text = w.toStringAsFixed(1);
        break;
      }
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
    final dateFormatted = DateFormat('EEE, d MMM').format(selectedDate);
    
    final profile = ref.watch(profileProvider);
    final unit = profile.useKg ? 'kg' : 'lbs';

    return AppSheet(
      title: 'Log Body Weight',
      subtitle: 'Enter your weight for $dateFormatted',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: context.colors.textDark,
            ),
            textAlign: TextAlign.center,
            cursorColor: context.colors.primary,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
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
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: context.colors.textLight,
              ),
              suffixText: unit,
              suffixStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textMedium,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
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
            label: 'Save Weight',
            onPressed: () {
              final weight = double.tryParse(_controller.text);
              if (weight != null && weight > 0 && weight < 500) {
                Haptics.toggle();
                ref.read(dailyLogProvider.notifier).updateWeight(weight);
                Navigator.of(context).pop();
              } else {
                Haptics.error();
                setState(() {
                  _errorText = 'Please enter a valid weight.';
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
