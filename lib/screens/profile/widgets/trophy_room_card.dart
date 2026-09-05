import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../providers/badge_engine_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../models/badge.dart';
import '../../../share/share_card_exporter.dart';

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flat Header over Scaffold
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: context.colors.gold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TROPHY ROOM',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: context.colors.gold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: unlocked),
                        duration: 1.seconds,
                        builder: (context, value, child) {
                          return Text(
                            '$value of ${badges.length} Unlocked',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textDark,
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
                      width: 44,
                      height: 44,
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
          ),

          const SizedBox(height: 32),

          // Next Up Spotlight directly flush against ScaffoldBg
          if (nextUpBadge != null) ...[
            _NextUpSpotlight(badge: nextUpBadge),
            const SizedBox(height: 24),
          ],

          // Badges Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 24, // Generous breathing room (Negative space)
                  children: sortedBadges.map((badge) {
                    final itemWidth = (constraints.maxWidth - 24) / 3;
                    return _BadgeItem(badge: badge, width: itemWidth);
                  }).toList(),
                );
              },
            ),
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
    final progressFraction = badge.requiredProgress > 0 
        ? badge.currentProgress / badge.requiredProgress 
        : 0.0;
    final remaining = badge.requiredProgress - badge.currentProgress;

    return GestureDetector(
      onTap: () => _BadgeItem.showDetailSheet(context, badge),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.surface,
                border: Border.all(color: context.colors.border, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Opacity(
                opacity: 0.4,
                child: Text(
                  badge.iconEmoji,
                  style: const TextStyle(fontSize: 26),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Up: ${badge.title}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: progressFraction),
                            duration: 1.seconds,
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return LinearProgressIndicator(
                                value: value,
                                backgroundColor: context.colors.border,
                                color: context.colors.textMedium, // Muted indicator for locked
                                minHeight: 4, // Very thin as per Sesireka
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$remaining more',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: context.colors.textLight),
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
    // Wrap with the generic bottom sheet handler
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        final isUnlocked = badge.isUnlocked;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 40,
              bottom: MediaQuery.paddingOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                      width: 110,
                      height: 110,
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
                          style: const TextStyle(fontSize: 52),
                        ),
                      ),
                    )
                    .animate(target: isUnlocked ? 1 : 0)
                    .shimmer(duration: 1.seconds, color: Colors.white30),
  
                const SizedBox(height: 32),
                Text(
                  badge.title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  badge.description,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: context.colors.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
  
                if (isUnlocked) ...[
                  Text(
                    'Unlocked ${DateFormat('MMMM d, yyyy').format(badge.unlockedAt!)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: context.colors.gold,
                    ),
                  ),
                ] else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'HOW TO EARN:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: context.colors.textLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: badge.requiredProgress > 0
                          ? badge.currentProgress / badge.requiredProgress
                          : 0,
                      backgroundColor: context.colors.border,
                      color: context.colors.textMedium,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Progress',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textMedium,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${badge.currentProgress} / ${badge.requiredProgress}',
                        style: AppTheme.numeric(
                          TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textDark,
                          )
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
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
      width: 54,
      height: 54,
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
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: isUnlocked ? 1.0 : 0.3,
        child: Text(badge.iconEmoji, style: const TextStyle(fontSize: 26)),
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
              width: 58,
              height: 58,
              child: CircularProgressIndicator(
                value: progressFrac,
                strokeWidth: 2,
                backgroundColor: context.colors.border,
                color: context.colors.textLight, // Muted progress for locked
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
                const SizedBox(height: 12),
                Text(
                  badge.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: isUnlocked
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: isUnlocked
                        ? context.colors.textDark
                        : context.colors.textMedium,
                  ),
                ),
                const SizedBox(height: 6),
                if (!isUnlocked)
                  Text(
                    '${badge.currentProgress}/${badge.requiredProgress}',
                    style: AppTheme.numeric(
                      TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.colors.textLight),
                    ),
                  )
                else
                  Text(
                    DateFormat('MMM d').format(badge.unlockedAt!),
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colors.gold,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
          if (isNew)
            Positioned(
              top: -4,
              right: (width / 2) - 36,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.gold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
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
