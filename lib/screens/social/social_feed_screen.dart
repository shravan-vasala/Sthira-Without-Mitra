import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../theme/layout_insets.dart';
import '../../models/social_profile.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/empty_state_view.dart';

import '../../utils/time_utils.dart';
import 'widgets/friend_status_card.dart';
import 'package:flutter/services.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';
import '../../theme/app_motion.dart';


class SocialFeedScreen extends ConsumerStatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen>
    with SingleTickerProviderStateMixin {
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
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
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
            const Tab(text: 'Leaderboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => context.push('/social/connect'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_FriendsTab(), _LeaderboardTab()],
      ),
    );
  }
}

class _FriendsTab extends ConsumerStatefulWidget {
  const _FriendsTab();

  @override
  ConsumerState<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends ConsumerState<_FriendsTab> {
  final Set<String> _processingRequests = {};

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsListStreamProvider);
    final syncService = ref.watch(socialSyncServiceProvider);

    return CustomScrollView(
      slivers: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: syncService.streamFriendRequests(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.screen),
                  child: Text(
                    'Error loading requests: ${snapshot.error}',
                    style: context.text.body.copyWith(
                      color: context.colors.red,
                    ),
                  ),
                ),
              );
            }
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }

            return SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.screen,
                      vertical: Spacing.stack,
                    ),
                    child: Text(
                      'Friend Requests',
                      style: context.text.eyebrow,
                    ),
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

                      final isProcessing = _processingRequests.contains(
                        fromUid,
                      );

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.screen,
                          vertical: Spacing.inline,
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _buildAvatar(
                            avatarUrl,
                            name,
                            fromUid,
                            context,
                          ),
                          title: Text(
                            name,
                            style: context.text.bodyStrong.copyWith(
                              color: context.colors.textDark,
                            ),
                          ),
                          subtitle: Text(
                            'Wants to be friends',
                            style: context.text.body.copyWith(
                              color: context.colors.textMedium,
                            ),
                          ),
                          trailing: AnimatedSwitcher(
                            duration: Motion.instant,
                            child: isProcessing
                                ? const SizedBox(
                                    key: ValueKey('processing'),
                                    width: 96,
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    key: const ValueKey('idle'),
                                    width: 96,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.check_circle_rounded,
                                          color: context.colors.primary,
                                        ),
                                        onPressed: () async {
                                          setState(
                                            () =>
                                                _processingRequests.add(fromUid),
                                          );
                                          try {
                                            await syncService.acceptFriendRequest(
                                              fromUid,
                                            );
                                            await ref
                                                .read(friendRepoProvider)
                                                .addFriend(
                                                  fromUid,
                                                  name,
                                                  avatarUrl: avatarUrl,
                                                );
                                          } finally {
                                            if (mounted) {
                                              setState(
                                                () => _processingRequests.remove(
                                                  fromUid,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.cancel_rounded,
                                          color: context.colors.textMedium
                                              .withValues(alpha: 0.5),
                                        ),
                                        onPressed: () async {
                                          setState(
                                            () =>
                                                _processingRequests.add(fromUid),
                                          );
                                          try {
                                            await syncService
                                                .declineFriendRequest(fromUid);
                                          } finally {
                                            if (mounted) {
                                              setState(
                                                () => _processingRequests.remove(
                                                  fromUid,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
        friendsAsync.when(
          data: (friends) {
            if (friends.isEmpty) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    EmptyStateView(
                      icon: Icons.people_outline_rounded,
                      title: 'No friends connected yet.',
                      subtitle:
                          'Tap the top right icon to connect and share your progress.',
                    ),
                  ],
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.screen,
                0,
                Spacing.screen,
                kShellScrollBottomPadding,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.section),
                    child: FriendStatusCard(friend: friends[index]),
                  );
                }, childCount: friends.length),
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, st) => SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.screen),
                child: Text(
                  'Error: $err',
                  textAlign: TextAlign.center,
                  style: context.text.body.copyWith(color: context.colors.red),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(
    String? avatarUrl,
    String name,
    String uid,
    BuildContext context,
  ) {
    if (avatarUrl != null && avatarUrl.startsWith('assets/')) {
      return CircleAvatar(
        backgroundColor: context.colors.inputFill,
        backgroundImage: AssetImage(avatarUrl),
      );
    }
    final hash = uid.hashCode.abs();
    final pastelColors = [
      context.colors.primary.withValues(alpha: 0.2),
      context.colors.green.withValues(alpha: 0.2),
      context.colors.indigo.withValues(alpha: 0.2),
      context.colors.orange.withValues(alpha: 0.2),
      const Color(0xFFB5A5AA).withValues(alpha: 0.3), // Muted Sage
    ];
    final color = pastelColors[hash % pastelColors.length];
    return CircleAvatar(
      backgroundColor: color,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: context.text.body.copyWith(color: context.colors.textDark),
      ),
    );
  }
}

enum LeaderboardMetric { steps, score }

enum LeaderboardPeriod { today, week }

class _LeaderboardTab extends ConsumerStatefulWidget {
  const _LeaderboardTab();
  @override
  ConsumerState<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends ConsumerState<_LeaderboardTab> {
  LeaderboardPeriod _period = LeaderboardPeriod.today;
  LeaderboardMetric _metric = LeaderboardMetric.score;

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsListStreamProvider);
    final auth = ref.watch(authServiceProvider);

    final friends = friendsAsync.value ?? [];

    // Compute my local stats
    final myProfile = _computeMyProfile(ref, auth.uid ?? 'me');

    final List<SocialProfile> allProfiles = [myProfile];
    final List<Widget> loadingSkeletons = [];

    for (var f in friends) {
      final asyncProfile = ref.watch(friendProfileStreamProvider(f.uid));
      if (asyncProfile.isLoading) {
        loadingSkeletons.add(const _SkeletonRow());
      } else if (asyncProfile.hasValue && asyncProfile.value != null) {
        allProfiles.add(asyncProfile.value!);
      }
    }

    final now = DateTime.now();
    final activeProfiles = <SocialProfile>[];
    final inactiveProfiles = <SocialProfile>[];

    for (var p in allProfiles) {
      if (now.difference(p.lastUpdatedAt).inDays > 7 &&
          p.uid != myProfile.uid) {
        inactiveProfiles.add(p);
      } else {
        activeProfiles.add(p);
      }
    }

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    bool isSameWeek(DateTime a, DateTime b) {
      final aMon = a.subtract(Duration(days: a.weekday - 1));
      final bMon = b.subtract(Duration(days: b.weekday - 1));
      return isSameDay(aMon, bMon);
    }

    int? getScore(SocialProfile p, bool forWeek) {
      if (forWeek) return isSameWeek(now, p.lastUpdatedAt) ? p.weekScore : 0;
      return isSameDay(now, p.lastUpdatedAt) ? p.todayScore : 0;
    }

    int getSteps(SocialProfile p, bool forWeek) {
      if (forWeek) return isSameWeek(now, p.lastUpdatedAt) ? p.weeklySteps : 0;
      return isSameDay(now, p.lastUpdatedAt) ? p.todaySteps : 0;
    }

    activeProfiles.sort((a, b) {
      final isWeek = _period == LeaderboardPeriod.week;
      if (_metric == LeaderboardMetric.score) {
        final aScore = getScore(a, isWeek);
        final bScore = getScore(b, isWeek);
        if (aScore == null && bScore == null) return 0;
        if (aScore == null) return 1;
        if (bScore == null) return -1;

        int cmp = bScore.compareTo(aScore);
        if (cmp != 0) return cmp;

        // Tie breaker 1: secondary metric (steps)
        final aSteps = getSteps(a, isWeek);
        final bSteps = getSteps(b, isWeek);
        cmp = bSteps.compareTo(aSteps);
        if (cmp != 0) return cmp;

        // Tie breaker 2: name (alphabetical)
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      } else {
        final aSteps = getSteps(a, isWeek);
        final bSteps = getSteps(b, isWeek);
        final int cmp = bSteps.compareTo(aSteps);
        if (cmp != 0) return cmp;

        // Tie breaker: name (alphabetical)
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    inactiveProfiles.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));

    if (friends.isEmpty && allProfiles.length == 1) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.inputFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.leaderboard_outlined,
                size: 40,
                color: context.colors.textMedium.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: Gap.x24),
            Text(
              'Board is empty',
              textAlign: TextAlign.center,
              style: context.text.cardTitle.copyWith(color: context.colors.textDark),
            ),
            const SizedBox(height: Gap.x8),
            Text(
              'Add friends to compete on the leaderboard!',
              textAlign: TextAlign.center,
              style: context.text.body.copyWith(color: context.colors.textMedium),
            ),
            const SizedBox(height: Gap.x32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.screen),
              child: PrimaryButton(
                label: 'Add Friends',
                onPressed: () => context.push('/social/connect'),
              ),
            ),
          ],
        ),
      );
    }

    final hasTop3 = activeProfiles.length >= 3;
    final top3 = hasTop3 ? activeProfiles.sublist(0, 3) : <SocialProfile>[];
    final remainingActive = hasTop3
        ? activeProfiles.sublist(3)
        : activeProfiles;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.screen, vertical: Spacing.section),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SegmentedButton<LeaderboardPeriod>(
                segments: const [
                  ButtonSegment(
                    value: LeaderboardPeriod.today,
                    label: Text('Today'),
                  ),
                  ButtonSegment(
                    value: LeaderboardPeriod.week,
                    label: Text('Week'),
                  ),
                ],
                selected: {_period},
                onSelectionChanged: (val) {
                  setState(() => _period = val.first);
                  _triggerHaptic();
                },
              ),
              const SizedBox(width: 8),
              SegmentedButton<LeaderboardMetric>(
                segments: const [
                  ButtonSegment(
                    value: LeaderboardMetric.score,
                    label: Text('Score'),
                  ),
                  ButtonSegment(
                    value: LeaderboardMetric.steps,
                    label: Text('Steps'),
                  ),
                ],
                selected: {_metric},
                onSelectionChanged: (val) {
                  setState(() => _metric = val.first);
                  _triggerHaptic();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.deliberate,
            child: ListView(
              key: ValueKey('${_period}_$_metric'),
              padding: const EdgeInsets.fromLTRB(
                Spacing.screen,
                0,
                Spacing.screen,
                kShellScrollBottomPadding,
              ),
              children: [
                if (hasTop3)
                  _PodiumView(
                    top3: top3,
                    myUid: myProfile.uid,
                    period: _period,
                    metric: _metric,
                  ),
                if (hasTop3) const SizedBox(height: Spacing.section),

                ...loadingSkeletons,

                ...remainingActive.asMap().entries.map(
                  (e) => _buildRow(
                    e.value,
                    hasTop3 ? e.key + 4 : e.key + 1,
                    false,
                    myProfile.uid,
                  ),
                ),

                if (inactiveProfiles.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.block),
                    child: Text(
                      'Inactive',
                      style: context.text.eyebrow,
                    ),
                  ),
                  ...inactiveProfiles.map(
                    (p) => _buildRow(p, null, true, myProfile.uid),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  SocialProfile _computeMyProfile(WidgetRef ref, String myUid) {
    final profile = ref.watch(profileProvider);
    final dailyLogRepo = ref.read(dailyLogRepoProvider);
    final todayStr = todayKey();
    final todayLog = dailyLogRepo.getOrCreate(todayStr);

    final now = DateTime.now();
    final diff = now.weekday - 1;
    final monday = now.subtract(Duration(days: diff));

    int weeklySteps = 0;
    int weeklyWorkouts = 0;
    for (int i = 0; i <= diff; i++) {
      final d = monday.add(Duration(days: i));
      final dStr = todayKey(d);
      final log = dailyLogRepo.getLog(dStr);
      if (log != null) {
        weeklySteps += log.steps ?? 0;
        if (log.workoutCompleted) weeklyWorkouts++;
      }
    }

    final dailyScore = ref.read(todayScoreProvider);

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
      todayScore: dailyScore.totalScore,
      weekScore: dailyScore.sevenDayAverage,
    );
  }

  Widget _buildRow(
    SocialProfile profile,
    int? rank,
    bool isInactive,
    String myUid,
  ) {
    final isMe = profile.uid == myUid;

    final now = DateTime.now();
    final isWeek = _period == LeaderboardPeriod.week;

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    bool isSameWeek(DateTime a, DateTime b) {
      final aMon = a.subtract(Duration(days: a.weekday - 1));
      final bMon = b.subtract(Duration(days: b.weekday - 1));
      return isSameDay(aMon, bMon);
    }

    String primaryText;
    if (_metric == LeaderboardMetric.score) {
      int? s;
      if (isWeek) {
        s = isSameWeek(now, profile.lastUpdatedAt) ? profile.weekScore : 0;
      } else {
        s = isSameDay(now, profile.lastUpdatedAt) ? profile.todayScore : 0;
      }
      primaryText = s == null ? '—' : s.toString();
    } else {
      int s;
      if (isWeek) {
        s = isSameWeek(now, profile.lastUpdatedAt) ? profile.weeklySteps : 0;
      } else {
        s = isSameDay(now, profile.lastUpdatedAt) ? profile.todaySteps : 0;
      }
      primaryText = NumberFormat.decimalPattern().format(s);
    }

    final secondaryMetric = _period == LeaderboardPeriod.week
        ? '${profile.weeklyWorkouts} W/O'
        : '${profile.currentStreak} Streak';

    Widget? rankWidget;
    if (rank != null) {
      if (rank <= 3) {
        final Map<int, Color> colors = {
          1: context.colors.gold,
          2: context.colors.silver,
          3: context.colors.bronze,
        };
        rankWidget = SizedBox(
          width: 32,
          child: Center(
            child: Icon(Icons.workspace_premium_rounded, color: colors[rank]),
          ),
        );
      } else {
        rankWidget = SizedBox(
          width: 32,
          child: Center(
            child: Text(
              '#$rank',
              style: context.text.bodyStrong.copyWith(
                color: context.colors.textMedium,
              ),
            ),
          ),
        );
      }
    }

    final container = Container(
      decoration: isMe
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: context.colors.primary.withValues(alpha: 0.1),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rankWidget != null) ...[rankWidget, const SizedBox(width: 8)],
            _buildAvatar(
              profile.avatarUrl,
              profile.name,
              profile.uid,
              isInactive,
            ),
          ],
        ),
        title: Text(
          isMe ? 'You' : profile.name,
          style: context.text.bodyStrong.copyWith(
            color: isInactive
                ? context.colors.textMedium.withValues(alpha: 0.5)
                : (isMe ? context.colors.primary : context.colors.textDark),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              primaryText,
              style: AppTheme.numeric(
                context.text.bodyStrong.copyWith(
                  color: isInactive
                      ? context.colors.textMedium.withValues(alpha: 0.5)
                      : context.colors.textDark,
                ),
              ),
            ),
            const SizedBox(height: Spacing.textPair),
            Text(
              secondaryMetric,
              style: context.text.caption.copyWith(color: context.colors.textMedium),
            ),
          ],
        ),
      ),
    );

    return container;
  }

  Widget _buildAvatar(
    String? avatarUrl,
    String name,
    String uid,
    bool isInactive,
  ) {
    if (avatarUrl != null && avatarUrl.startsWith('assets/')) {
      return CircleAvatar(
        backgroundColor: context.colors.inputFill,
        backgroundImage: AssetImage(avatarUrl),
      );
    }
    final hash = uid.hashCode.abs();
    final pastelColors = [
      context.colors.primary.withValues(alpha: isInactive ? 0.05 : 0.2),
      context.colors.green.withValues(alpha: isInactive ? 0.05 : 0.2),
      context.colors.indigo.withValues(alpha: isInactive ? 0.05 : 0.2),
      context.colors.orange.withValues(alpha: isInactive ? 0.05 : 0.2),
      const Color(0xFFB5A5AA).withValues(alpha: isInactive ? 0.1 : 0.3),
    ];
    final color = pastelColors[hash % pastelColors.length];

    return CircleAvatar(
      backgroundColor: color,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
        style: context.text.body.copyWith(
          color: isInactive
              ? context.colors.textMedium
              : context.colors.textDark,
        ),
      ),
    );
  }
}

class _PodiumView extends ConsumerWidget {
  final List<SocialProfile> top3;
  final String myUid;
  final LeaderboardPeriod period;
  final LeaderboardMetric metric;

  const _PodiumView({
    required this.top3,
    required this.myUid,
    required this.period,
    required this.metric,
  });
  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool isSameWeek(DateTime a, DateTime b) {
    final aMon = a.subtract(Duration(days: a.weekday - 1));
    final bMon = b.subtract(Duration(days: b.weekday - 1));
    return isSameDay(aMon, bMon);
  }

  int? _getRawVal(SocialProfile p) {
    final now = DateTime.now();
    final isWeek = period == LeaderboardPeriod.week;
    if (metric == LeaderboardMetric.score) {
      if (isWeek) return isSameWeek(now, p.lastUpdatedAt) ? p.weekScore : 0;
      return isSameDay(now, p.lastUpdatedAt) ? p.todayScore : 0;
    } else {
      if (isWeek) return isSameWeek(now, p.lastUpdatedAt) ? p.weeklySteps : 0;
      return isSameDay(now, p.lastUpdatedAt) ? p.todaySteps : 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPodiumItem(context, top3[1], 2, context.colors.silver, 60),
        const SizedBox(width: 8),
        _buildPodiumItem(context, top3[0], 1, context.colors.gold, 80),
        const SizedBox(width: 8),
        _buildPodiumItem(context, top3[2], 3, context.colors.bronze, 60),
      ],
    );
  }

  Widget _buildPodiumItem(
    BuildContext context,
    SocialProfile p,
    int rank,
    Color ringColor,
    double size,
  ) {
    final isMe = p.uid == myUid;
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: CircleAvatar(
              backgroundColor: context.colors.inputFill,
              backgroundImage:
                  p.avatarUrl != null && p.avatarUrl!.startsWith('assets/')
                  ? AssetImage(p.avatarUrl!)
                  : null,
              child: p.avatarUrl == null || !p.avatarUrl!.startsWith('assets/')
                  ? Text(
                      p.name.isNotEmpty
                          ? p.name.substring(0, 1).toUpperCase()
                          : '?',
                      style: context.text.body.copyWith(
                        color: context.colors.textDark,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isMe ? 'You' : p.name,
          style: context.text.body.copyWith(
            color: isMe ? context.colors.primary : context.colors.textDark,
          ),
          overflow: TextOverflow.ellipsis,
        ),

        (() {
          final rawVal = _getRawVal(p);
          if (rawVal == null) {
            return Text(
              '—',
              style: context.text.body.copyWith(color: ringColor),
            );
          }
          return TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: rawVal),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : Motion.deliberate,
            curve: Motion.enter,
            builder: (context, val, child) {
              final displayStr = metric == LeaderboardMetric.score
                  ? val.toString()
                  : NumberFormat.compact().format(val);
              
              if (metric == LeaderboardMetric.score) {
                return Text(
                  displayStr,
                  style: context.text.display.copyWith(
                    color: ringColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
              } else {
                return Text(
                  displayStr,
                  style: context.text.metric.copyWith(
                    color: ringColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
              }
            },
          );
        })(),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? Colors.white10
        : Colors.black12;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          ],
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 120,
            height: 16,
            color: color,
          ),
        ),
        subtitle: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Container(
              width: 80,
              height: 12,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
