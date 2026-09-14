import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/daily_log.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/layout_insets.dart';
import 'daily_checkin_sheet.dart';
import 'dart:math' as math;

class DailyCheckInRow extends ConsumerWidget {
  const DailyCheckInRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    final selectedDate = ref.watch(selectedDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final isToday = dateStr == todayStr;
    
    final dailyLog = ref.watch(dailyLogProvider);
    final hasCheckIn = dailyLog.dayFeeling != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
      child: _CheckInCard(
        dateStr: dateStr, 
        isToday: isToday, 
        dailyLog: dailyLog, 
        hasCheckIn: hasCheckIn,
        colors: colors,
      ),
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        DailyCheckInSheet.show(context, dateStr, dailyLog);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CloverIcon(color: colors.green, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily check-in',
                    style: TextStyle(
                      fontFamily: 'Cabinet Grotesk',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasCheckIn 
                        ? '${_feelingLabel(dailyLog!.dayFeeling!)} · Tap to edit'
                        : (isToday ? 'How did today feel?' : 'How did this day feel?'),
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: 13,
                      color: colors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textLight,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// CustomPainter for the Four-Leaf Clover
class CloverIcon extends StatelessWidget {
  const CloverIcon({super.key, required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CloverPainter(color: color),
      ),
    );
  }
}

class _CloverPainter extends CustomPainter {
  final Color color;
  _CloverPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 5;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Draw the 4 leaves (rotated to fit gracefully)
    for (int i = 0; i < 4; i++) {
        canvas.save();
        canvas.rotate((math.pi / 2) * i + math.pi / 4);
        
        final path = Path();
        path.moveTo(0, 0);
        path.cubicTo(
            radius * 1.5, -radius * 0.5,
            radius * 1.5, -radius * 2.5,
            0, -radius * 2
        );
        path.cubicTo(
            -radius * 1.5, -radius * 2.5,
            -radius * 1.5, -radius * 0.5,
            0, 0
        );
        
        canvas.drawPath(path, paint);
        canvas.restore();
    }

    // Draw a small stem
    final stemPath = Path();
    stemPath.moveTo(0, radius);
    stemPath.quadraticBezierTo(
        -radius * 0.5, radius * 2,
        -radius * 0.2, radius * 2.5
    );
    paint.style = PaintingStyle.stroke;
    canvas.drawPath(stemPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CloverPainter oldDelegate) => color != oldDelegate.color;
}
