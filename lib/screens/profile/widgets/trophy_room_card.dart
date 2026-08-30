import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/badge_engine_provider.dart';
import '../../../theme/app_colors.dart';

class TrophyRoomCard extends ConsumerWidget {
  const TrophyRoomCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgesProvider);

    if (badges.isEmpty) return const SizedBox.shrink();

    // Calculate progression
    final unlocked = badges.where((b) => b.isUnlocked).length;
    final progress = badges.isEmpty ? 0.0 : unlocked / badges.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trophy Room',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textDark,
                      ),
                    ),
                    Text(
                      '$unlocked of ${badges.length} Unlocked',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              CircularProgressIndicator(
                value: progress,
                backgroundColor: context.colors.border,
                color: Colors.amber,
                strokeWidth: 4,
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: badges.map((badge) {
                  final itemWidth = (constraints.maxWidth - 24) / 3;
                  return _BadgeItem(badge: badge, width: itemWidth);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final badge;
  final double width;

  const _BadgeItem({required this.badge, required this.width});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = badge.isUnlocked;
    
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isUnlocked ? context.colors.lavenderCard : context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked ? context.colors.primary.withValues(alpha: 0.3) : context.colors.border,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: isUnlocked ? 1.0 : 0.3,
            child: Text(
              badge.iconEmoji,
              style: const TextStyle(fontSize: 28), // Slightly smaller emoji to save space
            ),
          ),
          const SizedBox(height: 8),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10, // Reduced from 11
              height: 1.1, // Tighter line height
              fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
              color: isUnlocked ? context.colors.textDark : context.colors.textMedium,
            ),
          ),
          const SizedBox(height: 4),
          if (!isUnlocked)
            Text(
              '${badge.currentProgress}/${badge.requiredProgress}',
              style: TextStyle(
                fontSize: 10,
                color: context.colors.textLight,
              ),
            )
          else 
            Text(
              DateFormat('MMM d').format(badge.unlockedAt!),
              style: TextStyle(
                fontSize: 10,
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
