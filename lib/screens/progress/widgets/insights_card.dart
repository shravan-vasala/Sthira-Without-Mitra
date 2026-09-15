import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/insight.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/insights_provider.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';
import '../../../widgets/section_header.dart';

class InsightsCard extends ConsumerWidget {
  const InsightsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider);

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'Insights',
          icon: Icons.lightbulb_outline_rounded,
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: insights.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final insight = insights[index];
              return _buildInsightItem(context, insight);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInsightItem(BuildContext context, Insight insight) {
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

    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        // Sthira: No borders!
      ),
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
                  insight.type == InsightType.trend ? 'Trend' : 'Correlation',
                  style: context.text.micro.copyWith(color: context.colors.textLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.title,
            style: context.text.bodyStrong.copyWith(color: context.colors.textDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              insight.description,
              style: context.text.caption.copyWith(color: context.colors.textMedium),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
