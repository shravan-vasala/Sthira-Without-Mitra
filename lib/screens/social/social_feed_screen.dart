import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../models/social_profile.dart';
import '../../theme/app_colors.dart';
import '../../widgets/surface_card.dart';
import '../../widgets/empty_state_view.dart';
import 'widgets/friend_status_card.dart';

class SocialFeedScreen extends ConsumerStatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Consumer(
              builder: (context, ref, child) {
                final count = ref.watch(friendRequestsCountProvider).value ?? 0;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Friends'),
                      if (count > 0) ...[
                        const SizedBox(width: 8),
                        Badge(
                          label: Text(count.toString()),
                          backgroundColor: context.colors.red,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const Tab(text: 'Board'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => context.go('/social/connect'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FriendsTab(),
          _LeaderboardTab(),
        ],
      ),
    );
  }
}

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendRepo = ref.watch(friendRepoProvider);
    // Actually we need to watch friends using a provider or listen to DB. 
    // Currently getAllFriends is sync, so we just rebuild on changes if there is a provider.
    // wait, friendRepoProvider doesn't notify on its own. 
    // Sthira architecture: We usually getAllFriends() synchronously.
    final friends = friendRepo.getAllFriends();
    final syncService = ref.watch(socialSyncServiceProvider);

    return Column(
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: syncService.streamFriendRequests(),
          builder: (context, snapshot) {
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                  child: Text('Friend Requests', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.textMedium)),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    final String fromUid = req['fromUid'];
                    final String name = req['fromName'] ?? 'Unknown';
                    final String? avatarUrl = req['fromAvatar'];
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _buildAvatar(avatarUrl, name, context),
                        title: Text(name, style: TextStyle(color: context.colors.textDark, fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('Wants to be friends', style: TextStyle(color: context.colors.textMedium)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.check_circle, color: context.colors.primary),
                              onPressed: () async {
                                await syncService.acceptFriendRequest(fromUid);
                                friendRepo.addFriend(fromUid, name, avatarUrl: avatarUrl);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.cancel, color: context.colors.textMedium.withValues(alpha: 0.5)),
                              onPressed: () => syncService.declineFriendRequest(fromUid),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(),
              ],
            );
          },
        ),
        Expanded(
          child: friends.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const EmptyStateView(
                      icon: Icons.people_outline,
                      title: 'No friends connected yet.',
                      subtitle: 'Connect with friends to share your progress.',
                    ),
                    ElevatedButton(
                      onPressed: () => context.go('/social/connect'),
                      child: const Text('Add Friends'),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    return FriendStatusCard(friend: friends[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String? avatarUrl, String name, BuildContext context) {
    if (avatarUrl != null && avatarUrl.startsWith('assets/')) {
      return CircleAvatar(backgroundColor: context.colors.inputFill, backgroundImage: AssetImage(avatarUrl));
    }
    return CircleAvatar(
      backgroundColor: context.colors.primary.withValues(alpha: 0.2),
      child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: TextStyle(color: context.colors.primary)),
    );
  }
}

class _LeaderboardTab extends ConsumerStatefulWidget {
  const _LeaderboardTab();
  @override
  ConsumerState<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends ConsumerState<_LeaderboardTab> {
  bool _isWeek = false;

  @override
  Widget build(BuildContext context) {
    final friendRepo = ref.watch(friendRepoProvider);
    final friends = friendRepo.getAllFriends();
    final auth = ref.watch(authServiceProvider);
    
    // We compute our own stats locally
    final myProfile = _computeMyProfile(ref, auth.uid ?? 'me');
    
    // Watch streams for all friends
    List<SocialProfile> allProfiles = [myProfile];
    for (var f in friends) {
      final asyncProfile = ref.watch(friendProfileStreamProvider(f.uid));
      if (asyncProfile.hasValue && asyncProfile.value != null) {
        allProfiles.add(asyncProfile.value!);
      } else {
        // Fallback to minimal placeholder if loading
        allProfiles.add(SocialProfile(
          uid: f.uid,
          name: f.name,
          avatarUrl: f.avatarUrl,
          todaySteps: 0,
          todayWorkouts: 0,
          currentStreak: 0,
          weeklySteps: 0,
          weeklyWorkouts: 0,
          lastUpdatedAt: DateTime.now().subtract(const Duration(days: 99)),
        ));
      }
    }

    final now = DateTime.now();
    // Split active vs inactive (7 days)
    final activeProfiles = <SocialProfile>[];
    final inactiveProfiles = <SocialProfile>[];
    for (var p in allProfiles) {
      if (now.difference(p.lastUpdatedAt).inDays > 7 && p.uid != myProfile.uid) {
        inactiveProfiles.add(p);
      } else {
        activeProfiles.add(p);
      }
    }

    // Sort active
    activeProfiles.sort((a, b) {
      if (_isWeek) {
        if (b.weeklySteps != a.weeklySteps) return b.weeklySteps.compareTo(a.weeklySteps);
        return b.weeklyWorkouts.compareTo(a.weeklyWorkouts);
      } else {
        if (b.todaySteps != a.todaySteps) return b.todaySteps.compareTo(a.todaySteps);
        return b.currentStreak.compareTo(a.currentStreak);
      }
    });
    
    // We don't rank inactive properly, just show them at bottom
    inactiveProfiles.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));

    if (friends.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EmptyStateView(
            icon: Icons.leaderboard_outlined,
            title: 'Board is empty',
            subtitle: 'Add friends to compete on the leaderboard!',
          ),
          ElevatedButton(
            onPressed: () => context.go('/social/connect'),
            child: const Text('Add Friends'),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Today'),
                selected: !_isWeek,
                onSelected: (val) { if (val) setState(() => _isWeek = false); },
              ),
              const SizedBox(width: 16),
              ChoiceChip(
                label: const Text('This Week'),
                selected: _isWeek,
                onSelected: (val) { if (val) setState(() => _isWeek = true); },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ...activeProfiles.asMap().entries.map((e) => _buildRow(e.value, e.key + 1, false, myProfile.uid)),
              if (inactiveProfiles.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Inactive', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.textMedium)),
                ),
                ...inactiveProfiles.map((p) => _buildRow(p, null, true, myProfile.uid)),
              ]
            ],
          ),
        ),
      ],
    );
  }

  SocialProfile _computeMyProfile(WidgetRef ref, String myUid) {
    final profile = ref.watch(profileProvider);
    final dailyLogRepo = ref.read(dailyLogRepoProvider);
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final todayLog = dailyLogRepo.getOrCreate(todayStr);

    final now = DateTime.now();
    final diff = now.weekday - 1;
    final monday = now.subtract(Duration(days: diff));
    
    int weeklySteps = 0;
    int weeklyWorkouts = 0;
    for (int i = 0; i <= diff; i++) {
      final d = monday.add(Duration(days: i));
      final dStr = d.toIso8601String().substring(0, 10);
      final log = dailyLogRepo.getLog(dStr);
      if (log != null) {
        weeklySteps += log.steps ?? 0;
        if (log.workoutCompleted) weeklyWorkouts++;
      }
    }

    return SocialProfile(
      uid: myUid,
      name: profile.name.isEmpty ? 'You' : profile.name,
      avatarUrl: profile.photoPath,
      todaySteps: todayLog.steps ?? 0,
      todayWorkouts: todayLog.workoutCompleted ? 1 : 0,
      currentStreak: ref.read(stepsStreakProvider),
      weeklySteps: weeklySteps,
      weeklyWorkouts: weeklyWorkouts,
      lastUpdatedAt: DateTime.now(),
    );
  }

  Widget _buildRow(SocialProfile profile, int? rank, bool isInactive, String myUid) {
    final isMe = profile.uid == myUid;
    final primaryMetric = _isWeek ? profile.weeklySteps : profile.todaySteps;
    final secondaryMetric = _isWeek ? '${profile.weeklyWorkouts} W/O' : '${profile.currentStreak} Streak';

    Widget? rankWidget;
    if (rank != null) {
      if (rank == 1) rankWidget = const Icon(Icons.workspace_premium, color: Color(0xFFFFD700)); // Gold
      else if (rank == 2) rankWidget = const Icon(Icons.workspace_premium, color: Color(0xFFC0C0C0)); // Silver
      else if (rank == 3) rankWidget = const Icon(Icons.workspace_premium, color: Color(0xFFCD7F32)); // Bronze
      else rankWidget = Text('#$rank', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.textMedium));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rankWidget != null) ...[rankWidget, const SizedBox(width: 8)],
            _buildAvatar(profile.avatarUrl, isMe ? 'You' : profile.name, isInactive),
          ],
        ),
        title: Text(isMe ? 'You' : profile.name, style: TextStyle(
          fontWeight: isMe ? FontWeight.w800 : FontWeight.bold,
          fontSize: 16,
          color: isInactive ? context.colors.textMedium.withValues(alpha: 0.5) : (isMe ? context.colors.primary : context.colors.textDark),
        )),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(primaryMetric.toString(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: isInactive ? context.colors.textMedium.withValues(alpha: 0.5) : context.colors.primary)),
            Text(secondaryMetric, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.colors.textMedium)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String name, bool isInactive) {
    final String? safeAvatar = (avatarUrl?.startsWith('assets/') ?? false) ? avatarUrl : null;
    if (safeAvatar != null) {
      return CircleAvatar(backgroundColor: context.colors.inputFill, backgroundImage: AssetImage(safeAvatar));
    }
    return CircleAvatar(
      backgroundColor: context.colors.primary.withValues(alpha: isInactive ? 0.1 : 0.2),
      child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: TextStyle(color: isInactive ? context.colors.textMedium : context.colors.primary)),
    );
  }
}

