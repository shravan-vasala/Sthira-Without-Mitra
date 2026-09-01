import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/friend.dart';
import '../../../providers/app_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/surface_card.dart';

class FriendStatusCard extends ConsumerWidget {
  final Friend friend;

  const FriendStatusCard({super.key, required this.friend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(friendProfileStreamProvider(friend.uid));
    
    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return SurfaceCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: _buildAvatar(null, friend.name, context),
              title: Text(friend.name),
              subtitle: const Text('No recent activity.'),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: context.colors.red),
                onPressed: () => _showRemoveDialog(context, ref, friend),
              ),
            ),
          );
        }

        final now = DateTime.now();
        final diff = now.difference(profile.lastUpdatedAt);
        final isStale = diff.inHours > 24;
        
        final Color iconColor = isStale ? context.colors.textMedium.withValues(alpha: 0.5) : context.colors.primary;
        final Color textColor = isStale ? context.colors.textMedium.withValues(alpha: 0.5) : context.colors.textDark;

        return SurfaceCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAvatar(profile.avatarUrl, profile.name, context),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.colors.textDark),
                          ),
                          Text(
                            isStale ? 'Last active ${diff.inDays}d ago' : 'Updated ${_timeAgo(profile.lastUpdatedAt)}',
                            style: TextStyle(color: context.colors.textMedium, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: context.colors.red),
                      onPressed: () => _showRemoveDialog(context, ref, friend),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatBlock(
                      icon: Icons.directions_walk,
                      value: profile.todaySteps.toString(),
                      label: 'Steps',
                      color: iconColor,
                      textColor: textColor,
                    ),
                    _StatBlock(
                      icon: Icons.fitness_center,
                      value: profile.todayWorkouts.toString(),
                      label: 'Workouts',
                      color: iconColor,
                      textColor: textColor,
                    ),
                    _StatBlock(
                      icon: Icons.local_fire_department,
                      value: profile.currentStreak.toString(),
                      label: 'Streak',
                      color: iconColor,
                      textColor: textColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SurfaceCard(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => SurfaceCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(title: Text('Error loading profile', style: TextStyle(color: context.colors.red))),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String name, BuildContext context) {
    if (avatarUrl != null && avatarUrl.startsWith('assets/')) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: context.colors.inputFill,
        backgroundImage: AssetImage(avatarUrl),
      );
    }
    
    // Initials fallback
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return CircleAvatar(
      radius: 24,
      backgroundColor: context.colors.primary.withValues(alpha: 0.2),
      child: Text(
        initials,
        style: TextStyle(
          color: context.colors.primary,
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
        title: Text('Remove Friend', style: TextStyle(color: context.colors.textDark)),
        content: Text(
          'Are you sure you want to remove ${friend.name}? They will lose access to your activity. They may still see your past stats locally until they remove you.',
          style: TextStyle(color: context.colors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: context.colors.textMedium)),
          ),
          TextButton(
            onPressed: () {
              ref.read(friendRepoProvider).removeFriend(friend.uid);
              ref.read(socialSyncServiceProvider).removeFriendAccess(friend.uid);
              Navigator.of(ctx).pop();
            },
            child: Text('Remove', style: TextStyle(color: context.colors.red)),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color textColor;

  const _StatBlock({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
        ),
        Text(
          label,
          style: TextStyle(color: context.colors.textMedium, fontSize: 12),
        ),
      ],
    );
  }
}
