import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/insight.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/insights_provider.dart';
import '../../../widgets/surface_card.dart';

class DailyInsightCard extends ConsumerWidget {
  const DailyInsightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider);
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    // Pick top insight (most relevant). The provider sorts internally.
    final insight = insights.first;

    final (bgColor, iconColor) = switch (insight.severity) {
      InsightSeverity.positive => (
        context.colors.green.withValues(alpha: 0.1),
        context.colors.green,
      ),
      InsightSeverity.warning => (
        context.colors.orange.withValues(alpha: 0.1),
        context.colors.orange,
      ),
      InsightSeverity.neutral => (
        context.colors.primary.withValues(alpha: 0.1),
        context.colors.primary,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SurfaceCard(
        color: context.colors.card,
        border: null, // Sthira: No borders!
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(insight.icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insight.type == InsightType.trend ? 'TREND' : 'INSIGHT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textMedium,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              insight.title,
              style: TextStyle(
                fontFamily: 'Cabinet Grotesk',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              insight.description,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.colors.textMedium,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 400.ms, curve: Curves.easeOut)
    .slideY(begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}
