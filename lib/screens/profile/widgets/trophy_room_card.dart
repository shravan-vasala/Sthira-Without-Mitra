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
import '../../../widgets/primary_button.dart';
import '../../../widgets/surface_card.dart';

class TrophyRoomCard extends ConsumerWidget {
  const TrophyRoomCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgesProvider);
    if (badges.isEmpty) return const SizedBox.shrink();

    final unlocked = badges.where((b) => b.isUnlocked).length;

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: unlocked),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutExp,
              builder: (context, val, child) {
                return Text(
                  'TROPHY ROOM ($val/${badges.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.colors.primary,
                    letterSpacing: 1.5,
                  ),
                );
              },
            ),
          ),
          SurfaceCard(
            padding: const EdgeInsets.all(20),
            color: context.colors.card,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 24,
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
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked ? context.colors.primary.withValues(alpha: 0.1) : context.colors.inputFill,
                  ),
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: isUnlocked ? 1.0 : 0.4,
                    child: Text(
                      badge.iconEmoji,
                      style: const TextStyle(fontSize: 42),
                    ),
                  ),
                )
                  .animate(target: isUnlocked ? 1 : 0)
                  .shimmer(duration: 1.seconds, color: Colors.white24),
  
                const SizedBox(height: 32),
                Text(
                  badge.title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  badge.description,
                  style: TextStyle(
                    fontSize: 14,
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
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: context.colors.textMedium,
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
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: badge.requiredProgress > 0
                          ? badge.currentProgress / badge.requiredProgress
                          : 0,
                      backgroundColor: context.colors.border,
                      color: context.colors.textMedium,
                      minHeight: 4,
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
                
                const SizedBox(height: 32),
                if (isUnlocked)
                  PrimaryButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Share action could go here
                    },
                    icon: Icons.share_rounded,
                    label: 'Share Badge',
                  )
                else
                  PrimaryButton(
                    onPressed: () => Navigator.of(context).pop(),
                    label: 'Got it',
                  ),
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
    final progressFrac = badge.requiredProgress > 0
        ? badge.currentProgress / badge.requiredProgress
        : 0.0;

    Widget medallion = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUnlocked ? context.colors.primary.withValues(alpha: 0.1) : context.colors.inputFill,
      ),
      alignment: Alignment.center,
      child: Opacity(
        opacity: isUnlocked ? 1.0 : 0.4,
        child: Text(badge.iconEmoji, style: const TextStyle(fontSize: 24)),
      ),
    );

    if (!isUnlocked) {
      if (badge.currentProgress > 0) {
        medallion = Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                value: progressFrac,
                strokeWidth: 2,
                backgroundColor: context.colors.border,
                color: context.colors.textMedium, 
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
      child: Container(
        width: width,
        decoration: const BoxDecoration(color: Colors.transparent),
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
                fontWeight: isUnlocked ? FontWeight.w700 : FontWeight.w600,
                color: isUnlocked ? context.colors.textDark : context.colors.textMedium,
              ),
            ),
            const SizedBox(height: 6),
            if (!isUnlocked)
              Text(
                '${badge.currentProgress}/${badge.requiredProgress}',
                style: AppTheme.numeric(
                  TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.colors.textMedium.withValues(alpha: 0.5)),
                ),
              )
            else
              Text(
                DateFormat('MMM d').format(badge.unlockedAt!),
                style: TextStyle(
                  fontSize: 10,
                  color: context.colors.textMedium,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
      ),
    );

    if (isUnlocked) {
      tile = tile.animate().shimmer(
        delay: 400.ms,
        duration: 2000.ms,
        color: Colors.white.withValues(alpha: 0.2),
      );
    }

    return tile;
  }
}
