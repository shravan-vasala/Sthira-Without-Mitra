import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/friend.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_spacing.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';
import '../../../theme/app_motion.dart';


class FriendStatusCard extends ConsumerWidget {
  final Friend friend;

  const FriendStatusCard({super.key, required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(friendProfileStreamProvider(friend.uid));

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _buildAvatar(null, friend.name, friend.uid, context),
            title: Text(
              friend.name,
              style: context.text.bodyStrong.copyWith(
                color: context.colors.textDark,
              ),
            ),
            subtitle: Text(
              'No recent activity.',
              style: context.text.body.copyWith(
                color: context.colors.textMedium,
              ),
            ),
            trailing: _buildOverflowMenu(context, ref, friend),
          );
        }

        final now = DateTime.now();
        final daysStale = diffInDays(profile.lastUpdatedAt, now);
        final isDailyStale =
            profile.lastUpdatedAt.day != now.day || daysStale > 0;
        final isWeeklyStale = daysStale >= 7;

        final Color iconColor = isDailyStale
            ? context.colors.textMedium.withValues(alpha: 0.5)
            : context.colors.primary;
        final Color textColor = isDailyStale
            ? context.colors.textMedium.withValues(alpha: 0.5)
            : context.colors.textDark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                  _buildAvatar(
                    profile.avatarUrl,
                    profile.name,
                    profile.uid,
                    context,
                  ),
                  const SizedBox(width: Spacing.inline),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              profile.name,
                              style: context.text.bodyStrong.copyWith(
                                color: context.colors.textDark,
                              ),
                            ),
                            if (profile.todayScore != null &&
                                !isDailyStale) ...[
                              const SizedBox(width: Spacing.inline),
                              _ScoreBadge(
                                score: profile.todayScore!,
                                isStale: isDailyStale,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: Spacing.textPair),
                        Text(
                          isDailyStale
                              ? 'Last active ${daysStale > 0 ? daysStale : 1}d ago'
                              : 'Updated ${_timeAgo(profile.lastUpdatedAt)}',
                          style: context.text.caption.copyWith(
                            color: context.colors.textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildOverflowMenu(context, ref, friend),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatBlock(
                    icon: Icons.directions_walk_rounded,
                    rawValue: isDailyStale ? null : profile.todaySteps,
                    useDecimalFormat: true,
                    label: 'Steps',
                    color: iconColor,
                    textColor: textColor,
                    progress: isDailyStale ? 0 : profile.todaySteps / 10000.0,
                  ),
                  _StatBlock(
                    icon: Icons.fitness_center_rounded,
                    rawValue: isDailyStale ? null : profile.todayWorkouts,
                    useDecimalFormat: false,
                    label: 'Workouts',
                    color: iconColor,
                    textColor: textColor,
                    progress: isDailyStale
                        ? 0
                        : (profile.todayWorkouts >= 1 ? 1.0 : 0.0),
                  ),
                  _StatBlock(
                    icon: Icons.local_fire_department_rounded,
                    rawValue: isWeeklyStale ? null : profile.currentStreak,
                    useDecimalFormat: false,
                    label: 'Streak',
                    color: iconColor,
                    textColor: textColor,
                    progress: null,
                  ),
                ],
              ),
            ],
          );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          'Error loading profile',
          style: context.text.body.copyWith(color: context.colors.red),
        ),
        trailing: IconButton(
          icon: Icon(Icons.refresh_rounded, color: context.colors.textMedium),
          onPressed: () =>
              ref.invalidate(friendProfileStreamProvider(friend.uid)),
        ),
      ),
    );
  }

  Widget _buildOverflowMenu(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
  ) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: IconSize.nav,
        color: context.colors.textMedium,
      ),
      color: context.colors.card,
      onSelected: (value) {
        if (value == 'remove') {
          _showRemoveDialog(context, ref, friend);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: context.colors.red, size: IconSize.row),
              const SizedBox(width: Spacing.stack),
              Text(
                'Remove Friend',
                style: context.text.bodyStrong.copyWith(color: context.colors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int diffInDays(DateTime a, DateTime b) {
    return DateTime(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime(a.year, a.month, a.day)).inDays;
  }

  Widget _buildAvatar(
    String? avatarUrl,
    String name,
    String uid,
    BuildContext context,
  ) {
    if (avatarUrl != null && avatarUrl.startsWith('assets/')) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.transparent,
        backgroundImage: AssetImage(avatarUrl),
      );
    }

    // Deterministic pastel color based on uid
    final hash = uid.hashCode.abs();
    final pastelColors = [
      context.colors.primary.withValues(alpha: 0.2), // Peach
      context.colors.green.withValues(alpha: 0.2),
      context.colors.indigo.withValues(alpha: 0.2),
      context.colors.orange.withValues(alpha: 0.2),
      const Color(0xFFB5A5AA).withValues(alpha: 0.3), // Muted Sage
    ];
    final color = pastelColors[hash % pastelColors.length];

    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return CircleAvatar(
      radius: 20,
      backgroundColor: color,
      child: Text(
        initials,
        style: context.text.bodyStrong.copyWith(
          color: context.colors.textDark,
        ),
      ),
    );
  }

  void _showRemoveDialog(BuildContext context, WidgetRef ref, Friend friend) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(
          'Remove Friend',
          style: context.text.body.copyWith(color: context.colors.textDark),
        ),
        content: Text(
          'Are you sure you want to remove ${friend.name}? They will lose access to your activity. They may still see your past stats locally until they remove you.',
          style: context.text.body.copyWith(color: context.colors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: context.text.body.copyWith(
                color: context.colors.textMedium,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Wait for the backend response instead of pretending it worked immediately
                await ref
                    .read(socialSyncServiceProvider)
                    .removeFriendAccess(friend.uid);
                await ref.read(friendRepoProvider).removeFriend(friend.uid);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Failed to remove friend. Please try again.',
                      ),
                      backgroundColor: context.colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Remove',
              style: context.text.body.copyWith(color: context.colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours > 0) {
        if (date.hour < 12) return 'this morning';
        if (date.hour < 17) return 'this afternoon';
        return 'this evening';
      }
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    }
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays}d ago';
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final int? rawValue;
  final bool useDecimalFormat;
  final String label;
  final Color color;
  final Color textColor;
  final double? progress;

  const _StatBlock({
    required this.icon,
    required this.rawValue,
    required this.useDecimalFormat,
    required this.label,
    required this.color,
    required this.textColor,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: IconSize.row),
        const SizedBox(height: Spacing.textPair),
        if (rawValue == null)
          Text(
            '-',
            style: AppTheme.numeric(
              context.text.cardTitle.copyWith(color: textColor),
            ),
          )
        else
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: rawValue!),
            duration: Motion.deliberate,
            curve: Motion.enter,
            builder: (context, val, child) {
              final displayString = useDecimalFormat
                  ? NumberFormat.decimalPattern().format(val)
                  : val.toString();
              return Text(
                displayString,
                style: AppTheme.numeric(
                  context.text.cardTitle.copyWith(color: textColor),
                ),
              );
            },
          ),
        Text(
          label,
          style: context.text.caption.copyWith(
            color: context.colors.textMedium,
          ),
        ),
        const SizedBox(height: Spacing.inline),
        if (progress != null)
          SizedBox(
            width: 48,
            height: 4,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress!.clamp(0.0, 1.0)),
              duration: Motion.deliberate,
              curve: Motion.enter,
              builder: (context, val, child) {
                return LinearProgressIndicator(
                  value: val,
                  backgroundColor: context.colors.inputFill,
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                );
              },
            ),
          )
        else
          SizedBox(
            width: 48,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  final bool isStale;
  const _ScoreBadge({required this.score, required this.isStale});

  @override
  Widget build(BuildContext context) {
    final color = isStale
        ? context.colors.textMedium.withValues(alpha: 0.5)
        : context.colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.micro),
      ),
      child: Center(
        child: Text(
          score.toString(),
          style: AppTheme.numeric(context.text.micro.copyWith(color: color)),
        ),
      ),
    );
  }
}
