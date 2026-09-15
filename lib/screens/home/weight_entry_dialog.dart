import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/haptics.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';

import '../../utils/format_units.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class WeightEntryDialog extends ConsumerStatefulWidget {
  const WeightEntryDialog({super.key});

  @override
  ConsumerState<WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends ConsumerState<WeightEntryDialog> {
  final _controller = TextEditingController();
  String? _errorText;
  late String _pinnedDateStr;
  bool _isPastValue = false;
  String? _pastValueDateStr;

  @override
  void initState() {
    super.initState();
    _pinnedDateStr = ref.read(dateStringProvider);
    final log = ref.read(dailyLogProvider);
    final profile = ref.read(profileProvider);
    if (log.weight != null) {
      final w = convertFromKg(profile, log.weight!);
      _controller.text = w.toStringAsFixed(1);
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
        final wConverted = convertFromKg(profile, w);
        _controller.text = wConverted.toStringAsFixed(1);
        _isPastValue = true;
        _pastValueDateStr = logs[i].date;
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
      scrollable: true,
      title: 'Log Body Weight',
      subtitle: 'Enter your weight for $dateFormatted',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: context.text.display.copyWith(color: context.colors.textDark),
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
              hintText: '0.0',
              hintStyle: context.text.display.copyWith(color: context.colors.textLight),
              suffixText: unit,
              suffixStyle: context.text.cardTitle.copyWith(color: context.colors.textMedium),
            ),
          ),
          if (_isPastValue && _pastValueDateStr != null && _errorText == null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Recent from ${DateFormat('MMM d').format(DateTime.parse(_pastValueDateStr!))}',
                style: context.text.body.copyWith(color: context.colors.textMedium),
              ),
            ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _errorText!,
                style: context.text.body.copyWith(color: context.colors.red),
              ),
            ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Save Weight',
            onPressed: () async {
              final weightDisplay = double.tryParse(_controller.text);
              if (weightDisplay != null && weightDisplay > 0 && weightDisplay.isFinite) {
                final weightKg = convertToKg(profile, weightDisplay);
                if (weightKg < 500) {
                  Haptics.toggle();
                  await ref.read(dailyLogProvider.notifier).updateWeightForDate(_pinnedDateStr, weightKg);
                  if (mounted) Navigator.of(context).pop();
                } else {
                  Haptics.error();
                  setState(() => _errorText = 'Value too high');
                }
              } else {
                Haptics.error();
                setState(() => _errorText = 'Please enter a valid weight');
              }
            },
          ),
        ],
      ),
    );
  }
}
