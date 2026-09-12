import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';

class BodyFatEntryDialog extends ConsumerStatefulWidget {
  const BodyFatEntryDialog({super.key});

  @override
  ConsumerState<BodyFatEntryDialog> createState() => _BodyFatEntryDialogState();
}

class _BodyFatEntryDialogState extends ConsumerState<BodyFatEntryDialog> {
  final _controller = TextEditingController();
  String? _errorText;
  late String _pinnedDateStr;
  bool _isExistingEntry = false;
  bool _isPrefill = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pinnedDateStr = ref.read(dateStringProvider);
    final log = ref.read(dailyLogProvider);
    if (log.bodyFat != null) {
      _controller.text = log.bodyFat!.toStringAsFixed(1);
      _isExistingEntry = true;
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
      final bf = logs[i].bodyFat;
      if (bf != null) {
        _controller.text = bf.toStringAsFixed(1);
        _isPrefill = true;
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
                'Log Body Fat',
                style: TextStyle(
                  fontFamily: 'Cabinet Grotesk',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textDark,
                ),
              ),
              if (_isExistingEntry)
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          try {
                            await ref.read(dailyLogProvider.notifier).clearBodyFatForDate(_pinnedDateStr);
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (_) {
                            setState(() {
                              _isSaving = false;
                              _errorText = 'Failed to clear. Try again.';
                            });
                          }
                       },
                  style: TextButton.styleFrom(foregroundColor: context.colors.red),
                  child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your body fat percentage for $dateFormatted',
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textMedium,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            enabled: !_isSaving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: TextStyle(
              fontFamily: 'Cabinet Grotesk',
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: context.colors.textDark,
            ),
            textAlign: TextAlign.center,
            cursorColor: context.colors.primary,
            decoration: InputDecoration(
              filled: true,
              fillColor: context.colors.inputFill,
              errorText: _errorText,
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
              suffixText: '%',
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
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Save Body Fat',
            isLoading: _isSaving,
            onPressed: () async {
              if (_isSaving) return;
              final bf = double.tryParse(_controller.text);
              if (bf != null && bf > 0 && bf <= 100) {
                setState(() => _isSaving = true);
                Haptics.toggle();
                try {
                  await ref.read(dailyLogProvider.notifier).updateBodyFatForDate(_pinnedDateStr, bf);
                  if (mounted) Navigator.of(context).pop();
                } catch (e) {
                  setState(() {
                    _isSaving = false;
                    _errorText = 'Failed to save. Try again.';
                  });
                }
              } else {
                Haptics.error();
                setState(() => _errorText = 'Please enter a valid percentage (0.1-100)');
              }
            },
          ),
          if (_isPrefill)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Center(
                child: Text(
                  'Prefilled from a previous measurement',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textMedium,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
