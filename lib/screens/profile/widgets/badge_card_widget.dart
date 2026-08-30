import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/achievement_badge.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/badge_provider.dart';

class BadgeCardWidget extends ConsumerWidget {
  const BadgeCardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgeProvider);

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
           child: Row(
             children: [
               Icon(Icons.emoji_events_rounded, color: context.colors.orange, size: 20),
               const SizedBox(width: 8),
               Text(
                 'Achievements',
                 style: TextStyle(
                   fontSize: 16,
                   fontWeight: FontWeight.w700,
                   color: context.colors.textDark,
                 ),
               ),
             ],
           ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: badges.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final badge = badges[index];
              return _buildBadgeItem(context, badge);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeItem(BuildContext context, AchievementBadge badge) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.card.withValues(alpha: badge.isUnlocked ? 1.0 : 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            badge.emoji,
            style: TextStyle(
              fontSize: 28,
              color: badge.isUnlocked ? Colors.white : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.textDark.withValues(alpha: badge.isUnlocked ? 1.0 : 0.5),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
