import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../providers/weekly_summary_provider.dart';
import '../../providers/app_providers.dart';
import '../../share/share_card_exporter.dart';
import '../../share/weekly_share_layout.dart';

class WeeklySummaryScreen extends ConsumerWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(weeklySummaryProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    // Get week bounds for title
    final weekday = selectedDate.weekday;
    final startOfWeek = selectedDate.subtract(Duration(days: weekday - 1));
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.colors.lavender,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: context.colors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textMedium,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                primaryValue,
                style: AppTheme.numeric(
                  TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: context.colors.textDark,
                    height: 1.0,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (trendValue != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: Text(
                    trendValue!,
                    style: AppTheme.numeric(
                      TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: trendColor ?? context.colors.textMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: context.colors.textLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _WeeklyShareSection extends ConsumerStatefulWidget {
  final WeeklySummary summary;
  final String titleText;

  const _WeeklyShareSection({
    required this.summary,
    required this.titleText,
  });

  @override
  ConsumerState<_WeeklyShareSection> createState() => _WeeklyShareSectionState();
}

class _WeeklyShareSectionState extends ConsumerState<_WeeklyShareSection> {
  bool _isSharing = false;

  void _shareImage(BuildContext context, WeeklySummary summary, String title) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    
    try {
      final name = ref.read(profileProvider).name;
      
      Color baseColor = context.colors.green;
      if (summary.weekScore < 50) baseColor = context.colors.red;
      else if (summary.weekScore < 80) baseColor = context.colors.orange;
      
      final layout = WeeklyShareLayout(
        format: ShareFormat.post,
        userName: name,
        dateRange: title,
        weekScore: summary.weekScore,
        prevWeekScore: summary.previousWeekScore,
        dailyScores: summary.dailyScores,
        workoutsCompleted: summary.workoutsCompleted,
        workoutsTotal: summary.workoutsTotal,
        avgSteps: summary.avgSteps,
        habitCompletionPercent: (summary.habitCompletionRate * 100).toInt(),
        baseColor: baseColor,
      );

      await ShareCardExporter.exportAndShareWidget(
        context: context,
        widget: layout,
        fileName: 'sthira_weekly_summary',
        text: summary.generateShareText(),
        format: ShareFormat.post,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _isSharing ? null : () => _shareImage(context, widget.summary, widget.titleText),
          icon: _isSharing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.ios_share_rounded),
          label: Text(_isSharing ? 'Generating...' : 'Share Summary Image'),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: context.colors.onPrimary,
            elevation: 4,
            shadowColor: context.colors.primary.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            final text = widget.summary.generateShareText();
            // ignore: deprecated_member_use
            Share.share(text);
          },
          child: Text(
            'Share as text',
            style: TextStyle(
              color: context.colors.textMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
