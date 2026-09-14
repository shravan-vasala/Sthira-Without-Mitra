import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/layout_insets.dart';
import '../../../widgets/primary_button.dart';
import '../../../models/daily_log.dart';
import 'package:intl/intl.dart';

class DailyCheckInSheet extends ConsumerStatefulWidget {
  const DailyCheckInSheet({
    super.key,
    required this.dateStr,
    this.existingLog,
  });

  final String dateStr;
  final DailyLog? existingLog;

  static Future<void> show(BuildContext context, String dateStr, DailyLog? existingLog) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DailyCheckInSheet(
        dateStr: dateStr,
        existingLog: existingLog,
      ),
    );
  }

  @override
  ConsumerState<DailyCheckInSheet> createState() => _DailyCheckInSheetState();
}

class _DailyCheckInSheetState extends ConsumerState<DailyCheckInSheet> {
  String? _selectedFeeling;
  late TextEditingController _noteController;
  bool _isSaving = false;
  bool _hasChanges = false;

  final List<String> _feelings = ['veryLow', 'low', 'okay', 'good', 'great'];
  
  String _feelingLabel(String feeling) {
    switch (feeling) {
      case 'veryLow': return 'Very low';
      case 'low': return 'Low';
      case 'okay': return 'Okay';
      case 'good': return 'Good';
      case 'great': return 'Great';
      default: return 'Unknown';
    }
  }

  IconData _feelingIcon(String feeling) {
    switch (feeling) {
      case 'veryLow': return Icons.sentiment_very_dissatisfied_rounded;
      case 'low': return Icons.sentiment_dissatisfied_rounded;
      case 'okay': return Icons.sentiment_neutral_rounded;
      case 'good': return Icons.sentiment_satisfied_rounded;
      case 'great': return Icons.sentiment_very_satisfied_rounded;
      default: return Icons.sentiment_neutral_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFeeling = widget.existingLog?.dayFeeling;
    _noteController = TextEditingController(text: widget.existingLog?.dayNote ?? '');
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  String _formatDate() {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    if (widget.dateStr == todayStr) {
      return 'Today, ${DateFormat('MMM d').format(now)}';
    }
    final d = DateTime.parse(widget.dateStr);
    return DateFormat('EEEE, MMM d').format(d);
  }

  bool _isToday() {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    return widget.dateStr == todayStr;
  }

  Future<void> _save() async {
    if (_selectedFeeling == null) return;
    setState(() => _isSaving = true);
    try {
      final note = _noteController.text.trim();
      await ref.read(dailyLogRepoProvider).updateCheckIn(
        widget.dateStr,
        _selectedFeeling!,
        note.isEmpty ? null : note,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save check-in. Try again.')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _remove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove check-in?'),
        content: const Text('This will clear your feeling and note for this day.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: context.colors.textDark)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(dailyLogRepoProvider).removeCheckIn(widget.dateStr);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove check-in.')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges && _selectedFeeling == widget.existingLog?.dayFeeling) {
      return true;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Editing', style: TextStyle(color: context.colors.textDark)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isExisting = widget.existingLog?.dayFeeling != null;
    final canSave = _selectedFeeling != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Daily check-in',
                style: TextStyle(
                  fontFamily: 'Cabinet Grotesk',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(),
                style: TextStyle(
                  fontFamily: 'General Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textDark.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),

              // Feelings Prompt
              Text(
                _isToday() ? 'How did today feel?' : 'How did this day feel?',
                style: TextStyle(
                  fontFamily: 'General Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textDark,
                ),
              ),
              const SizedBox(height: 16),
              
              // Feelings row
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    children: _feelings.map((f) {
                      final isSelected = _selectedFeeling == f;
                      // Determine width (try fit 5 in a row if wide enough, else wrap)
                      // If constraints < 300, it'll naturally wrap
                      final itemWidth = (constraints.maxWidth - (8 * 4)) / 5;
                      final useRow = itemWidth >= 50;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFeeling = f;
                            _hasChanges = true;
                          });
                        },
                        child: Container(
                          width: useRow ? itemWidth : null,
                          padding: EdgeInsets.symmetric(
                            horizontal: useRow ? 0 : 16, 
                            vertical: 12
                          ),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? colors.orange.withValues(alpha: 0.15) 
                                : colors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? colors.orange : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _feelingIcon(f),
                                color: isSelected ? colors.orange : colors.primary,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _feelingLabel(f),
                                style: TextStyle(
                                  fontFamily: 'General Sans',
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? colors.orange : colors.primary,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              
              const SizedBox(height: 32),

              // Note field
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Anything you\'d like to note?',
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textDark,
                    ),
                  ),
                  Text(
                    'Optional',
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textDark.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLength: 500,
                maxLines: 3,
                minLines: 3,
                style: TextStyle(
                  fontFamily: 'General Sans',
                  fontSize: 15,
                  color: colors.textDark,
                ),
                decoration: InputDecoration(
                  hintText: 'Add a private note about today...',
                  hintStyle: TextStyle(
                    color: colors.textDark.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: colors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: TextStyle(
                    fontFamily: 'General Sans',
                    fontSize: 12,
                    color: colors.textDark.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Actions
              PrimaryButton(
                label: isExisting ? 'Save changes' : 'Save check-in',
                onPressed: canSave ? _save : null,
                isLoading: _isSaving,
                icon: Icons.check_rounded,
              ),
              if (isExisting) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSaving ? null : _remove,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.error,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Remove check-in',
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
