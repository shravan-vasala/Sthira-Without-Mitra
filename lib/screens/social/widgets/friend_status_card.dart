import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/friend.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../models/social_profile.dart';


class FriendStatusCard extends ConsumerWidget {
  final Friend friend;

  const FriendStatusCard({super.key, required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(friendProfileStreamProvider(friend.uid));

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _buildAvatar(null, friend.name, friend.uid, context),
              title: Text(
                friend.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: context.colors.textDark,
                ),
              ),
              subtitle: Text(
                'No recent activity.',
                style: TextStyle(color: context.colors.textMedium),
              ),
              trailing: _buildOverflowMenu(context, ref, friend),
            ),
          );
        }

        final now = DateTime.now();
        final isStale =
            profile.lastUpdatedAt.day != now.day ||
            diffInDays(profile.lastUpdatedAt, now) > 0;

        final Color iconColor = isStale
            ? context.colors.textMedium.withValues(alpha: 0.5)
            : context.colors.primary;
        final Color textColor = isStale
            ? context.colors.textMedium.withValues(alpha: 0.5)
            : context.colors.textDark;

        return Padding(
          padding: const EdgeInsets.only(bottom: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   _buildAvatar(profile.avatarUrl, profile.name, profile.uid, context),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              profile.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: context.colors.textDark,
                              ),
                            ),
                            if (profile.todayScore != null) ...[
                              const SizedBox(width: 8),
                              _ScoreBadge(score: profile.todayScore!, isStale: isStale),
                            ]
                          ],
                        ),
                        Text(
                          isStale
                              ? 'Last active ${diffInDays(profile.lastUpdatedAt, now) > 0 ? diffInDays(profile.lastUpdatedAt, now) : 1}d ago'
                              : 'Updated ${_timeAgo(profile.lastUpdatedAt)}',
                          style: TextStyle(
                            color: context.colors.textMedium,
                            fontSize: 13,
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
                    icon: Icons.directions_walk,
                    rawValue: profile.todaySteps,
                    useDecimalFormat: true,
                    label: 'Steps',
                    color: iconColor,
                    textColor: textColor,
                    progress: profile.todaySteps / 10000.0,
                  ),
                  _StatBlock(
                    icon: Icons.fitness_center,
                    rawValue: profile.todayWorkouts,
                    useDecimalFormat: false,
                    label: 'Workouts',
                    color: iconColor,
                    textColor: textColor,
                    progress: profile.todayWorkouts >= 1 ? 1.0 : 0.0,
                  ),
                  _StatBlock(
                    icon: Icons.local_fire_department,
                    rawValue: profile.currentStreak,
                    useDecimalFormat: false,
                    label: 'Streak',
                    color: iconColor,
                    textColor: textColor,
                    progress: null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Error loading profile',
            style: TextStyle(color: context.colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildOverflowMenu(BuildContext context, WidgetRef ref, Friend friend) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: context.colors.textMedium.withValues(alpha: 0.5),
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
              Icon(Icons.delete_outline, color: context.colors.red, size: 20),
              const SizedBox(width: 12),
              Text('Remove Friend', style: TextStyle(color: context.colors.red)),
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

  Widget _buildAvatar(String? avatarUrl, String name, String uid, BuildContext context) {
    if (avatarUrl != null && avatarUrl.startsWith('assets/')) {
      return CircleAvatar(
        radius: 24,
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
    final textColor = color.withValues(alpha: 1.0); // Make it fully opaque for text

    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return CircleAvatar(
      radius: 24,
      backgroundColor: color,
      child: Text(
        initials,
        style: TextStyle(
          color: context.colors.textDark, // So it pops against the pastel
          fontWeight: FontWeight.bold,
          fontSize: 20,
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
          style: TextStyle(
            color: context.colors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${friend.name}? They will lose access to your activity. They may still see your past stats locally until they remove you.',
          style: TextStyle(color: context.colors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colors.textMedium),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Wait for the backend response instead of pretending it worked immediately
                await ref
                    .read(socialSyncServiceProvider)
                    .removeFriendAccess(friend.uid);
                ref.read(friendRepoProvider).removeFriend(friend.uid);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Failed to remove friend. Please try again.'),
                      backgroundColor: context.colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('Remove', style: TextStyle(color: context.colors.red)),
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
  final int rawValue;
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
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: rawValue),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutQuart,
          builder: (context, val, child) {
            final displayString = useDecimalFormat ? NumberFormat.decimalPattern().format(val) : val.toString();
            return Text(
              displayString,
              style: AppTheme.numeric(
                TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: textColor,
                ),
              ),
            );
          },
        ),
        Text(
          label,
          style: TextStyle(
            color: context.colors.textMedium,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 48,
            height: 4,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress!.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
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
        ]
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
    final color = isStale ? context.colors.textMedium.withValues(alpha: 0.5) : context.colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          score.toString(),
          style: AppTheme.numeric(
            TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
