import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../providers/badge_engine_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../models/badge.dart';

class TrophyRoomCard extends ConsumerWidget {
  const TrophyRoomCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgesProvider);
    if (badges.isEmpty) return const SizedBox.shrink();

    // Calculate progression
    final unlocked = badges.where((b) => b.isUnlocked).length;
    final progress = badges.isEmpty ? 0.0 : unlocked / badges.length;

    // Sorting
    final sortedBadges = List<Badge>.from(badges);
    sortedBadges.sort((a, b) {
      if (a.isUnlocked && !b.isUnlocked) return -1;
      if (!a.isUnlocked && b.isUnlocked) return 1;
      if (a.isUnlocked && b.isUnlocked) {
        return b.unlockedAt!.compareTo(a.unlockedAt!);
      }
      final progA = a.currentProgress / a.requiredProgress;
      final progB = b.currentProgress / b.requiredProgress;
      return progB.compareTo(progA);
    });

    final lockedBadges = sortedBadges.where((b) => !b.isUnlocked).toList();
    final nextUpBadge = lockedBadges.isNotEmpty ? lockedBadges.first : null;

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
                  color: context.colors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: context.colors.gold,
                  size: 20,
                ),
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
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: unlocked),
                      duration: 1.seconds,
                      builder: (context, value, child) {
                        return Text(
                          '$value of ${badges.length} Unlocked',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textMedium,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: progress),
                duration: 1.seconds,
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      value: value,
                      backgroundColor: context.colors.border,
                      color: context.colors.gold,
                      strokeWidth: 4,
                    ),
                  );
                },
              ),
            ],
          ),

          if (nextUpBadge != null) ...[
            const SizedBox(height: 24),
            _NextUpSpotlight(badge: nextUpBadge),
          ],

          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: sortedBadges.map((badge) {
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

class _NextUpSpotlight extends StatelessWidget {
  final Badge badge;
  const _NextUpSpotlight({required this.badge});

  @override
  Widget build(BuildContext context) {
    final progressFraction = badge.currentProgress / badge.requiredProgress;
    final remaining = badge.requiredProgress - badge.currentProgress;

    return GestureDetector(
      onTap: () => _BadgeItem.showDetailSheet(context, badge),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.scaffoldBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.surface,
                border: Border.all(color: context.colors.border),
              ),
              alignment: Alignment.center,
              child: Opacity(
                opacity: 0.5,
                child: Text(
                  badge.iconEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Next Up: ${badge.title}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textDark,
                        ),
                      ),
                      Text(
                        '$remaining more',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: progressFraction),
                      duration: 1.seconds,
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: context.colors.border,
                          color: context.colors.primary,
                          minHeight: 6,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final Badge badge;
  final double width;

  const _BadgeItem({required this.badge, required this.width});

  static void showDetailSheet(BuildContext context, Badge badge) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isUnlocked = badge.isUnlocked;
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 32,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: isUnlocked
                            ? [context.colors.goldMuted, context.colors.gold]
                            : [
                                context.colors.border,
                                context.colors.scaffoldBg,
                              ],
                      ),
                      border: Border.all(
                        color: isUnlocked
                            ? context.colors.gold
                            : context.colors.border,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: isUnlocked ? 1.0 : 0.3,
                      child: Text(
                        badge.iconEmoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  )
                  .animate(target: isUnlocked ? 1 : 0)
                  .shimmer(duration: 1.seconds, color: Colors.white30),

              const SizedBox(height: 24),
              Text(
                badge.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                badge.description,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textMedium,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              if (isUnlocked) ...[
                Text(
                  'Unlocked ${DateFormat('MMMM d, yyyy').format(badge.unlockedAt!)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.colors.gold,
                  ),
                ),
              ] else ...[
                Text(
                  'How to earn:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textMedium,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: badge.requiredProgress > 0
                        ? badge.currentProgress / badge.requiredProgress
                        : 0,
                    backgroundColor: context.colors.border,
                    color: context.colors.textDark,
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${badge.currentProgress} / ${badge.requiredProgress}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUnlocked = badge.isUnlocked;
    final isNew =
        isUnlocked && DateTime.now().difference(badge.unlockedAt!).inHours < 48;
    final progressFrac = badge.requiredProgress > 0
        ? badge.currentProgress / badge.requiredProgress
        : 0.0;

    Widget medallion = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUnlocked
            ? RadialGradient(
                colors: [context.colors.goldMuted, context.colors.gold],
              )
            : null,
        color: isUnlocked ? null : Colors.transparent,
        border: Border.all(
          color: isUnlocked ? context.colors.gold : context.colors.border,
        ),
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: isUnlocked ? 1.0 : 0.3,
        child: Text(badge.iconEmoji, style: const TextStyle(fontSize: 24)),
      ),
    );

    if (!isUnlocked) {
      if (badge.currentProgress == 0) {
        medallion = Stack(
          alignment: Alignment.center,
          children: [
            medallion,
            Container(
              decoration: BoxDecoration(
                color: context.colors.scaffoldBg.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              width: 24,
              height: 24,
              child: Icon(
                Icons.lock_rounded,
                size: 14,
                color: context.colors.textLight,
              ),
            ),
          ],
        );
      } else {
        medallion = Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                value: progressFrac,
                strokeWidth: 2,
                backgroundColor: context.colors.border,
                color: context.colors.textLight,
              ),
            ),
            medallion,
          ],
        );
      }
    }

    Widget tile = GestureDetector(
      onTap: () => showDetailSheet(context, badge),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: width,
            decoration: BoxDecoration(color: Colors.transparent),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                medallion,
                const SizedBox(height: 8),
                Text(
                  badge.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: isUnlocked
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isUnlocked
                        ? context.colors.textDark
                        : context.colors.textMedium,
                  ),
                ),
                const SizedBox(height: 4),
                if (!isUnlocked)
                  Text(
                    '${badge.currentProgress}/${badge.requiredProgress}',
                    style: AppTheme.numeric(
                      TextStyle(fontSize: 10, color: context.colors.textLight),
                    ),
                  )
                else
                  Text(
                    DateFormat('MMM d').format(badge.unlockedAt!),
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (isNew)
            Positioned(
              top: 0,
              right: (width / 2) - 34,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colors.gold,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (isUnlocked) {
      tile = tile.animate().shimmer(
        delay: 400.ms,
        duration: 1200.ms,
        color: Colors.white.withValues(alpha: 0.4),
      );
    }

    return tile;
  }
}
