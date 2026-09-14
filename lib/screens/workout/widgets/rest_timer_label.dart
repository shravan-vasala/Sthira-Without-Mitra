import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_providers.dart';

class RestTimerLabel extends ConsumerWidget {
  const RestTimerLabel({
    super.key,
    required this.seconds,
    required this.exerciseName,
  });

  final int seconds;
  final String exerciseName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (seconds <= 0) return const SizedBox.shrink();

    final timerState = ref.watch(restTimerProvider);
    final isActive =
        timerState.isActive && timerState.exerciseName == exerciseName;
    final displaySeconds = isActive ? timerState.remainingSeconds : seconds;

    final display = displaySeconds >= 60
        ? '${displaySeconds ~/ 60} min${displaySeconds % 60 > 0 ? ' ${displaySeconds % 60} sec' : ''}'
        : '$displaySeconds sec';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: isActive ? context.colors.orange : context.colors.border,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: isActive
                      ? context.colors.orange
                      : context.colors.textLight,
                ),
                const SizedBox(width: 4),
                Text(
                  isActive
                      ? 'Resting for $display'
                      : 'Rest for $display after set',
                  style: AppTheme.numeric(
                    TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? context.colors.orange
                          : context.colors.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: isActive ? context.colors.orange : context.colors.border,
            ),
          ),
        ],
      ),
    );
  }
}
