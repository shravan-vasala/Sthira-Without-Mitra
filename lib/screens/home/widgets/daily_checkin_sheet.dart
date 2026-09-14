import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/layout_insets.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../models/daily_log.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class DailyCheckInSheet extends ConsumerStatefulWidget {
  const DailyCheckInSheet({
    super.key,
    required this.dateStr,
    this.existingLog,
  });

  final String dateStr;
  final DailyLog? existingLog;

  static Future<void> show(BuildContext context, String dateStr, DailyLog? existingLog) {
    return showAppBottomSheet(
      context: context,
      isScrollControlled: true,
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
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
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
            child: Text('Remove', style: TextStyle(color: context.colors.red)),
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
    final initialNote = widget.existingLog?.dayNote ?? '';
    final currentNote = _noteController.text;
    final initialFeeling = widget.existingLog?.dayFeeling;
    
    if (initialNote == currentNote && initialFeeling == _selectedFeeling) {
      return true; // no actual changes
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
            child: Text('Discard', style: TextStyle(color: context.colors.red)),
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

    final disableAnimations = MediaQuery.disableAnimationsOf(context);

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Use AppSheet wrapper style without padding inside so we maintain our own padding rhythm here
              const SizedBox(height: 8),
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
              const SizedBox(height: 24),

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
              
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - (8 * 4)) / 5;
                  final useRow = itemWidth >= 56; // Threshold adjusted to 56 as per requirement

                  return Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    children: _feelings.map((f) {
                      final isSelected = _selectedFeeling == f;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFeeling = f;
                            _hasChanges = true;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 160),
                          curve: Curves.easeInOut,
                          width: useRow ? itemWidth : constraints.maxWidth, // Stretch to full width if not enough space
                          padding: EdgeInsets.symmetric(
                            horizontal: useRow ? 0 : 16, 
                            vertical: useRow ? 16 : 14
                          ),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? colors.orange.withValues(alpha: 0.2) 
                                : colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? colors.orange : colors.border,
                              width: 1.5,
                            ),
                          ),
                          child: useRow
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        BotanicalIcon(
                                          feeling: f,
                                          color: isSelected ? colors.orange : (colors.green),
                                          size: 24,
                                        ),
                                        if (isSelected)
                                          Positioned(
                                            right: -2,
                                            bottom: -2,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: colors.orange,
                                                shape: BoxShape.circle,
                                              ),
                                              padding: const EdgeInsets.all(2),
                                              child: Icon(Icons.check, size: 8, color: colors.onPrimary),
                                            ),
                                          )
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _feelingLabel(f),
                                      style: TextStyle(
                                        fontFamily: 'General Sans',
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? colors.orange : colors.textMedium,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                )
                              : Row( // Compact full-width row design
                                  children: [
                                    BotanicalIcon(
                                      feeling: f,
                                      color: isSelected ? colors.orange : (colors.green),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        _feelingLabel(f),
                                        style: TextStyle(
                                          fontFamily: 'General Sans',
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? colors.orange : colors.textMedium,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle_rounded, color: colors.orange, size: 20),
                                  ],
                                ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              
              const SizedBox(height: 24),

              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Anything you\'d like to note? ',
                      style: TextStyle(
                        fontFamily: 'General Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textDark,
                      ),
                    ),
                    TextSpan(
                      text: ' (Optional)',
                      style: TextStyle(
                        fontFamily: 'General Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: colors.textDark.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLength: 500,
                maxLines: 4,
                minLines: 2,
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
              const SizedBox(height: 24),

              _CheckInSaveButton(
                label: isExisting ? 'Save changes' : 'Save check-in',
                onPressed: canSave ? _save : null,
                isLoading: _isSaving,
                icon: Icons.check_rounded,
                colors: colors,
              ),
              if (isExisting) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSaving ? null : _remove,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.red,
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

// Dedicated CheckIn Save action explicitly enforcing custom disabled colors.
class _CheckInSaveButton extends StatelessWidget {
  const _CheckInSaveButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.icon,
    required this.colors,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData icon;
  final AppColorsPalette colors;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;

    final content = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.onPrimary,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: disabled ? colors.textMedium : colors.onPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: disabled ? colors.textMedium : colors.onPrimary,
                ),
              ),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: kPrimaryButtonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          disabledBackgroundColor: colors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kButtonRadius),
            side: disabled ? BorderSide(color: colors.border.withValues(alpha: 0.5)) : BorderSide.none,
          ),
        ),
        child: content,
      ),
    );
  }
}

class BotanicalIcon extends StatelessWidget {
  const BotanicalIcon({super.key, required this.feeling, required this.color, required this.size});
  final String feeling;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BotanicalPainter(feeling: feeling, color: color),
      ),
    );
  }
}

class _BotanicalPainter extends CustomPainter {
  final String feeling;
  final Color color;
  _BotanicalPainter({required this.feeling, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
      
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 4;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    switch(feeling) {
      case 'veryLow':
        // healthy single leaf
        final path = Path();
        path.moveTo(0, radius);
        path.quadraticBezierTo(-radius, 0, 0, -radius*1.2);
        path.quadraticBezierTo(radius, 0, 0, radius);
        canvas.drawPath(path, paint);
        canvas.drawLine(Offset(0, radius), Offset(0, -radius*1.2), paint); // leaf vein
        canvas.drawLine(Offset(0, radius), Offset(0, radius * 1.5), paint); // stem
        break;
      case 'low':
        // two-leaf sprout
        paint.style = PaintingStyle.stroke;
        // left leaf
        final path = Path();
        path.moveTo(0, radius * 0.5);
        path.quadraticBezierTo(-radius * 1.2, radius * 0.2, -radius * 0.8, -radius * 0.6);
        path.quadraticBezierTo(-radius * 0.1, -radius * 0.1, 0, radius * 0.5);
        canvas.drawPath(path, paint);
        // right leaf
        final path2 = Path();
        path2.moveTo(0, radius * 0.5);
        path2.quadraticBezierTo(radius * 1.2, radius * 0.2, radius * 0.8, -radius * 0.6);
        path2.quadraticBezierTo(radius * 0.1, -radius * 0.1, 0, radius * 0.5);
        canvas.drawPath(path2, paint);
        canvas.drawLine(Offset(0, radius * 0.5), Offset(0, radius * 1.5), paint);
        break;
      case 'okay':
        // closed flower bud
        final path = Path();
        path.moveTo(0, -radius * 1.2);
        path.quadraticBezierTo(-radius*1.2, -radius * 0.2, 0, radius * 0.8);
        path.quadraticBezierTo(radius*1.2, -radius * 0.2, 0, -radius * 1.2);
        canvas.drawPath(path, paint);
        // inner petals hinting
        canvas.drawLine(Offset(0, radius * 0.8), Offset(0, -radius * 0.4), paint);
        canvas.drawLine(Offset(0, radius * 0.8), Offset(0, radius * 1.5), paint);
        break;
      case 'good':
        // simple open flower
        final leafPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
        for (int i = 0; i < 5; i++) {
          canvas.save();
          canvas.rotate((math.pi * 2 / 5) * i);
          final path = Path();
          path.moveTo(0, radius * 0.2);
          path.quadraticBezierTo(-radius * 0.8, -radius * 0.5, 0, -radius * 1.4);
          path.quadraticBezierTo(radius * 0.8, -radius * 0.5, 0, radius * 0.2);
          canvas.drawPath(path, leafPaint);
          canvas.restore();
        }
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(const Offset(0, 0), radius * 0.35, paint);
        break;
      case 'great':
        // small sunflower
        final leafPaint = Paint()..color = color..style = PaintingStyle.fill;
        for (int i = 0; i < 12; i++) {
          canvas.save();
          canvas.rotate((math.pi * 2 / 12) * i);
          final path = Path();
          path.moveTo(0, 0);
          path.quadraticBezierTo(-radius * 0.4, -radius * 0.8, 0, -radius * 1.3);
          path.quadraticBezierTo(radius * 0.4, -radius * 0.8, 0, 0);
          canvas.drawPath(path, leafPaint);
          canvas.restore();
        }
        canvas.drawCircle(const Offset(0, 0), radius * 0.55, paint);
        break;
      default:
        break;
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BotanicalPainter oldDelegate) => 
    feeling != oldDelegate.feeling || color != oldDelegate.color;
}
