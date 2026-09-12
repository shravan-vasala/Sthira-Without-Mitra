import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../providers/habit_providers.dart';
import '../../models/habit.dart';
import '../../share/share_card_exporter.dart';
import '../../share/daily_share_layout.dart';

class SharePreviewSheet extends ConsumerStatefulWidget {
  const SharePreviewSheet({super.key});

  @override
  ConsumerState<SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends ConsumerState<SharePreviewSheet> {
  ShareFormat _format = ShareFormat.post;
  bool _isSharing = false;

  void _shareImage(Widget layout, String subtitle) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final success = await ShareCardExporter.exportAndShareWidget(
        context: context,
        widget: layout,
        fileName: 'sthira_daily_status',
        text: subtitle,
        format: _format,
      );
      if (success && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _getSubtitle(int totalScore) {
    if (totalScore >= 100) return 'Crushed all daily goals! 🔥';
    if (totalScore >= 80) return 'Almost perfect today! ⭐';
    if (totalScore >= 50) return 'Making steady progress 🌿';
    if (totalScore >= 20) return 'Getting moving today 🏃';
    return 'Just getting started 🌅';
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(profileProvider.select((p) => p.name));
    final scoreData = ref.watch(dailyScoreProvider);
    final score = scoreData.totalScore;
    final selectedDate = ref.watch(selectedDateProvider);
    
    final dailyLog = ref.watch(dailyLogProvider);
    final mealsLog = ref.watch(dailyMealLogProvider);
    final habitsCount = ref.watch(habitsProvider).length;
    final habitsCompleted = ref.watch(habitCompletionsProvider).completions.values.where((c) => c.status == HabitStatus.completed).length;

    final steps = dailyLog.steps ?? 0;
    final mealsKcal = mealsLog.totalCalories;
    final workoutDone = dailyLog.workoutCompleted;
    final habitsDone = habitsCount > 0 ? '$habitsCompleted/$habitsCount' : '0/0';

    final subtitle = _getSubtitle(score);
    // Base color tied to score
    Color baseColor = context.colors.green;
    if (score < 50) {
      baseColor = context.colors.red;
    } else if (score < 80) {
      baseColor = context.colors.orange;
    }

    final layout = DailyShareLayout(
      format: _format,
      userName: name,
      score: score,
      subtitle: subtitle,
      steps: steps,
      mealsKcal: mealsKcal,
      workoutDone: workoutDone,
      habitsDone: habitsDone,
      baseColor: baseColor,
      date: selectedDate,
    );

    final previewWidth = 360.0;
    final previewHeight = _format == ShareFormat.post ? 450.0 : 640.0;

    return SafeArea(
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: context.colors.scaffoldBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share Your Progress',
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.colors.textDark,
              ),
            ),
            const SizedBox(height: 16),

            // Format Toggle Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FormatChip(
                  label: 'Post 4:5',
                  isSelected: _format == ShareFormat.post,
                  onTap: () => setState(() => _format = ShareFormat.post),
                ),
                const SizedBox(width: 8),
                _FormatChip(
                  label: 'Story 9:16',
                  isSelected: _format == ShareFormat.story,
                  onTap: () => setState(() => _format = ShareFormat.story),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Live Preview Box bounded by constraints
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: AspectRatio(
                    aspectRatio: previewWidth / previewHeight,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: previewWidth,
                        height: previewHeight,
                        child: layout,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 4,
                  shadowColor: context.colors.primary.withValues(alpha: 0.4),
                ),
                onPressed: _isSharing ? null : () => _shareImage(layout, subtitle),
                icon: _isSharing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.ios_share_rounded),
                label: Text(
                  _isSharing ? 'Preparing...' : 'Share Image',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : context.colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? context.colors.onPrimary : context.colors.textMedium,
          ),
        ),
      ),
    );
  }
}
