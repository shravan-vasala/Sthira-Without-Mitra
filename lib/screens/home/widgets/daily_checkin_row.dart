import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/daily_log.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import 'daily_checkin_sheet.dart';

class DailyCheckInRow extends ConsumerWidget {
  const DailyCheckInRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    // We observe the selected day's log
    final selectedDate = ref.watch(selectedDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final isToday = dateStr == todayStr;
    
    final dailyLogAsync = ref.watch(dailyLogProvider(dateStr));
    
    return dailyLogAsync.when(
      data: (dailyLog) {
        final hasCheckIn = dailyLog?.dayFeeling != null;
        return _CheckInCard(
          dateStr: dateStr, 
          isToday: isToday, 
          dailyLog: dailyLog, 
          hasCheckIn: hasCheckIn,
          colors: colors,
        );
      },
      loading: () => const SizedBox(height: 72), // Placeholder height
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({
    required this.dateStr,
    required this.isToday,
    required this.dailyLog,
    required this.hasCheckIn,
    required this.colors,
  });

  final String dateStr;
  final bool isToday;
  final DailyLog? dailyLog;
  final bool hasCheckIn;
  final AppColorsPalette colors;

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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        DailyCheckInSheet.show(context, dateStr, dailyLog);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasCheckIn 
                    ? colors.orange.withValues(alpha: 0.15)
                    : colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasCheckIn ? _feelingIcon(dailyLog!.dayFeeling!) : Icons.sentiment_satisfied_alt_rounded,
                color: hasCheckIn ? colors.orange : colors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasCheckIn 
                        ? 'Felt ${_feelingLabel(dailyLog!.dayFeeling!).toLowerCase()}'
                        : (isToday ? 'How are you feeling today?' : 'How did this day feel?'),
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textDark,
                    ),
                  ),
                  if (hasCheckIn && dailyLog!.dayNote != null && dailyLog!.dayNote!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      dailyLog!.dayNote!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'General Sans',
                        fontSize: 13,
                        color: colors.textDark.withValues(alpha: 0.6),
                      ),
                    ),
                  ] else if (!hasCheckIn) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tap to check in',
                      style: TextStyle(
                        fontFamily: 'General Sans',
                        fontSize: 13,
                        color: colors.textDark.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textDark.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
