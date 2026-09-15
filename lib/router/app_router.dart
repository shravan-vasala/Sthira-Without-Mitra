import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/meal_detail_screen.dart';
import '../screens/home/body_stats_screen.dart';
import '../screens/home/physique_pictures_screen.dart';
import '../screens/workout/workout_screen.dart';
import '../screens/workout/youtube_player_screen.dart';
import '../screens/workout/exercise_progress_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/progress/weekly_summary_screen.dart';
import '../screens/progress/yearly_activity_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/manage_plans_screen.dart';
import '../screens/profile/backup_restore_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/profile/reminders_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/badge_overlay_host.dart';
import '../screens/social/social_feed_screen.dart';
import '../screens/social/connect_screen.dart';
import '../services/haptics.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _progressNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'progress');
final _socialNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'social');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen(onboardingCompletedProvider, (_, _) => notifyListeners());
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

final appRouterProvider = Provider<GoRouter>((ref) {
  // ignore: unused_local_variable
  final prefs = ref.watch(sharedPreferencesProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: ref.watch(routerNotifierProvider),
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'This page doesn\'t exist or was removed.',
                style: context.text.bodyStrong.copyWith(color: context.colors.textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Return to Home'),
              ),
            ],
          ),
        ),
      ),
    ),
    redirect: (context, state) {
      final isCompleted = ref.read(onboardingCompletedProvider);

      if (!isCompleted && state.uri.path != '/onboarding') {
        return '/onboarding';
      }

      if (isCompleted && state.uri.path == '/onboarding') {
        return '/home';
      }

      if (state.uri.path == '/' || state.uri.path.isEmpty) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'meals',
                    builder: (context, state) => const MealDetailScreen(),
                  ),
                  GoRoute(
                    path: 'body-stats',
                    builder: (context, state) => const BodyStatsScreen(),
                  ),
                  GoRoute(
                    path: 'physique-pictures',
                    builder: (context, state) => const PhysiquePicturesScreen(),
                  ),
                  GoRoute(
                    path: 'workout/:dayId',
                    builder: (context, state) {
                      final dayId = state.pathParameters['dayId']!;
                      final sectionParam = state.uri.queryParameters['section'];
                      final sectionIndex = sectionParam != null
                          ? int.tryParse(sectionParam)
                          : null;
                      final jumpToParam = state.uri.queryParameters['jumpTo'];
                      final jumpToIndex = jumpToParam != null
                          ? int.tryParse(jumpToParam)
                          : null;
                      return WorkoutScreen(
                        dayId: dayId,
                        sectionIndex: sectionIndex,
                        jumpToIndex: jumpToIndex,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _progressNavigatorKey,
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) {
                  final metricStr = state.uri.queryParameters['metric'];
                  MetricType? metric;
                  if (metricStr != null) {
                    switch (metricStr) {
                      case 'weight':
                        metric = MetricType.weight;
                        break;
                      case 'steps':
                        metric = MetricType.steps;
                        break;
                      case 'sleep':
                        metric = MetricType.sleep;
                        break;
                      case 'bmi':
                        metric = MetricType.bmi;
                        break;
                      case 'bodyFat':
                        metric = MetricType.bodyFat;
                        break;
                      case 'calories':
                        metric = MetricType.calories;
                        break;
                      case 'protein':
                      case 'macros': // legacy deep link
                        metric = MetricType.protein;
                        break;
                    }
                  }
                  return ProgressScreen(initialMetric: metric);
                },
                routes: [
                  GoRoute(
                    path: 'weekly-summary',
                    builder: (context, state) => const WeeklySummaryScreen(),
                  ),
                  GoRoute(
                    path: 'yearly-activity',
                    builder: (context, state) => const YearlyActivityScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _socialNavigatorKey,
            routes: [
              GoRoute(
                path: '/social',
                builder: (context, state) => const SocialFeedScreen(),
                routes: [
                  GoRoute(
                    path: 'connect',
                    builder: (context, state) => const ConnectScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'manage-plans',
                    builder: (context, state) => const ManagePlansScreen(),
                  ),
                  GoRoute(
                    path: 'backup-restore',
                    builder: (context, state) => const BackupRestoreScreen(),
                  ),
                  GoRoute(
                    path: 'reminders',
                    builder: (context, state) => const RemindersScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes (outside bottom nav)
      GoRoute(
        path: '/youtube-player',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final videoId = state.uri.queryParameters['videoId'] ?? '';
          final title = state.uri.queryParameters['title'] ?? '';
          final subtitle = state.uri.queryParameters['subtitle'] ?? '';
          final reps = state.uri.queryParameters['reps'] ?? '';
          return YoutubePlayerScreen(
            videoId: videoId,
            title: title,
            subtitle: subtitle,
            reps: reps,
          );
        },
      ),
      GoRoute(
        path: '/exercise-progress',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final exerciseName = state.uri.queryParameters['name'] ?? '';
          return ExerciseProgressScreen(exerciseName: exerciseName);
        },
      ),
    ],
  );
});

class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(restTimerProvider);
    final canPopInner = GoRouter.of(context).canPop();
    final isHomeTab = navigationShell.currentIndex == 0;

    return PopScope(
      canPop: isHomeTab && !canPopInner,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        if (canPopInner) {
          GoRouter.of(context).pop();
        } else if (!isHomeTab) {
          navigationShell.goBranch(0, initialLocation: false);
        }
      },
      child: Stack(
        children: [
          Scaffold(
            body: Builder(
              builder: (innerContext) {
                return MediaQuery(
                  data: MediaQuery.of(innerContext).copyWith(
                    padding: MediaQuery.paddingOf(innerContext).copyWith(
                      bottom:
                          MediaQuery.paddingOf(innerContext).bottom +
                          (timerState.isActive ? 76.0 : 0.0),
                    ),
                  ),
                  child: Stack(
                    children: [
                      navigationShell,
                      if (timerState.isActive)
                        Positioned(
                          bottom: 16,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.orange,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: context.colors.orange.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  timerState.isPaused
                                      ? Icons.pause_circle_filled
                                      : Icons.timer,
                                  color: context.colors.onPrimary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        timerState.exerciseName != null
                                            ? 'Resting for ${timerState.exerciseName}'
                                            : 'Resting',
                                        style: context.text.micro.copyWith(color: Colors.white70),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${timerState.remainingSeconds ~/ 60}:${(timerState.remainingSeconds % 60).toString().padLeft(2, '0')}',
                                        style: AppTheme.numeric(
                                          context.text.bodyStrong.copyWith(color: context.colors.onPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Controls
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () => ref
                                          .read(restTimerProvider.notifier)
                                          .addSeconds(15),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        minimumSize: const Size(48, 48),
                                        foregroundColor: context.colors.card,
                                      ),
                                      child: Text(
                                        '+15s',
                                        style: AppTheme.numeric(
                                          context.text.micro,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => ref
                                          .read(restTimerProvider.notifier)
                                          .addSeconds(30),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        minimumSize: const Size(48, 48),
                                        foregroundColor: context.colors.card,
                                      ),
                                      child: Text(
                                        '+30s',
                                        style: AppTheme.numeric(
                                          context.text.micro,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      onPressed: () {
                                        if (timerState.isPaused) {
                                          ref.read(restTimerProvider.notifier).resumeTimer();
                                        } else {
                                          ref.read(restTimerProvider.notifier).pauseTimer();
                                        }
                                      },
                                      icon: Icon(
                                        timerState.isPaused
                                            ? Icons.play_arrow_rounded
                                            : Icons.pause_rounded,
                                      ),
                                      color: context.colors.white,
                                      tooltip: timerState.isPaused ? 'Play' : 'Pause',
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        ref.read(restTimerProvider.notifier).stopTimer();
                                      },
                                      icon: const Icon(Icons.close),
                                      color: context.colors.white,
                                      tooltip: 'Close timer',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            bottomNavigationBar: _CustomNavBar(
              currentIndex: navigationShell.currentIndex,
              onItemSelected: (index) {
                Haptics.tap();
                navigationShell.goBranch(index);
              },
            ),
          ),

          const BadgeOverlayHost(),
        ],
      ),
    );
  }
}

// Removed _TimerControlButton in favor of native TextButton.

class _CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const _CustomNavBar({
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 32, right: 32, bottom: 16, top: 0),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavBarItem(
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                isSelected: currentIndex == 0,
                onTap: () => onItemSelected(0),
              ),
              _NavBarItem(
                label: 'Progress',
                icon: Icons.show_chart_outlined,
                activeIcon: Icons.show_chart_rounded,
                isSelected: currentIndex == 1,
                onTap: () => onItemSelected(1),
              ),
              _NavBarItem(
                label: 'Social',
                icon: Icons.people_outline_rounded,
                activeIcon: Icons.people_rounded,
                isSelected: currentIndex == 2,
                onTap: () => onItemSelected(2),
              ),
              _NavBarItem(
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                isSelected: currentIndex == 3,
                onTap: () => onItemSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        selected: isSelected,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 24 : 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? context.colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected
                  ? context.colors.onPrimary
                  : const Color(0xFF8A9A93),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
