import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../providers/sync_controller.dart';
import '../../providers/midnight_tick_provider.dart';
import '../../services/widget_update_service.dart';
import '../../services/health_connect_service.dart';
import '../../services/screen_time_service.dart';
import '../../models/habit.dart';
import '../../utils/workout_completion.dart';
import '../../widgets/section_header.dart';
import '../../theme/layout_insets.dart';
import '../../providers/app_providers.dart';
import '../../providers/badge_engine_provider.dart';
import '../../widgets/surface_card.dart';
import '../profile/manage_habits_screen.dart';
import 'widgets/week_calendar_strip.dart';
import 'widgets/meals_card.dart';
import 'widgets/habits_card.dart';
import 'widgets/daily_progress_grid.dart';
import 'widgets/coach_notes_card.dart';
import 'widgets/day_complete_sheet.dart';

import 'package:confetti/confetti.dart';
import '../../providers/gamification_provider.dart';
import 'share_preview_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late ConfettiController _confettiController;
  final _habitsKey = GlobalKey();
  final _mealsKey = GlobalKey();
  final _progressKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Initial sync when screen first loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncControllerProvider.notifier).sync(isManualRefresh: true);
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // ignore: unused_element
  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _staggerWrap(int index, Widget child) {
    return child
        .animate(delay: (index * 80).ms)
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(badgeEngineProvider); // Initialize Gamification Engine
    final plan = ref.watch(workoutPlanProvider);
    ref.watch(syncControllerProvider);
    // ignore: unused_local_variable
    final dailyScore = ref.watch(dailyScoreProvider);

    // One calm day-complete sheet when primary buckets fill (today only).
    ref.listen<DailyScore>(dailyScoreProvider, (prev, next) {
      if (next.isPrimaryComplete && (prev == null || !prev.isPrimaryComplete)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) maybeShowDayCompleteSheet(context, ref);
        });
      }
    });

    ref.listen<int>(stepsStreakProvider, (prev, next) {
      if (next > 5 && (prev == null || prev <= 5)) {
        _confettiController.play();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Woohoo! You hit your steps goal for $next days in a row! 💃',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.colors.green,
          ),
        );
      }
    });

    ref.listen<int>(mealStreakProvider, (prev, next) {
      if (next == 3 && (prev == null || prev < 3)) {
        _confettiController.play();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Amazing! You\'ve logged your meals for 3 days in a row! 🌻',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.colors.green,
          ),
        );
      }
    });

    return Stack(
      children: [
        Scaffold(
          backgroundColor: context.colors.scaffoldBg,
          body: RefreshIndicator(
            color: context.colors.primary,
            onRefresh: () => ref
                .read(syncControllerProvider.notifier)
                .sync(isManualRefresh: true),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: context.colors.scaffoldBg.withValues(alpha: 0.9),
                  surfaceTintColor: Colors.transparent,
                  actions: const [
                    Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: _HomeShareButton(),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: _HomeGreetingTitle(),
                      ),
                      const SizedBox(height: 24),

                      // 2. Week calendar + score
                      _staggerWrap(1, const WeekCalendarStrip()),
                      const SizedBox(height: 24),

                      // 3. Workout (primary daily action)
                      if (plan != null && plan.days.isNotEmpty) ...[
                        _staggerWrap(2, _WorkoutsSection(plan: plan)),
                        const SizedBox(height: 24),
                      ],

                      // 4. Habits
                      _staggerWrap(
                        3,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KeyedSubtree(
                              key: _habitsKey,
                              child: const SectionHeader(
                                'HABITS',
                                trailing: _HabitsEditButton(),
                                countLabel: _HabitsCountLabel(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const HabitsCard(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 5. Meals
                      _staggerWrap(
                        4,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KeyedSubtree(
                              key: _mealsKey,
                              child: const SectionHeader('MEALS'),
                            ),
                            const SizedBox(height: 12),
                            const MealsCard(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 6. Daily progress metrics
                      _staggerWrap(
                        5,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KeyedSubtree(
                              key: _progressKey,
                              child: const SectionHeader(
                                'DAILY PROGRESS',
                                icon: Icons.show_chart_rounded,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const DailyProgressGrid(),
                            const SizedBox(height: 16),
                            const _WeeklySummaryLink(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 7. Coach notes last (below fold)
                      _staggerWrap(6, const CoachNotesCard()),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeGreetingTitle extends ConsumerWidget {
  const _HomeGreetingTitle();

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(midnightTickProvider);
    final name = ref.watch(profileProvider.select((p) => p.name)).trim();
    final selected = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = selectedDay(selected) == today;

    final title = name.isEmpty ? _timeGreeting() : '${_timeGreeting()},\n$name';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: context.colors.textDark,
            height: 1.15,
            fontSize: 32,
          ),
        ),
        if (!isToday) ...[
          const SizedBox(height: 4),
          Text(
            'Looking at ${DateFormat('EEE, MMM d').format(selected)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: context.colors.primary,
            ),
          ),
        ],
      ],
    );
  }

  DateTime selectedDay(DateTime s) => DateTime(s.year, s.month, s.day);
}

class _HomeShareButton extends StatelessWidget {
  const _HomeShareButton();
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const SharePreviewSheet(),
        );
      },
      icon: Icon(Icons.ios_share_rounded, color: context.colors.primary),
      style: IconButton.styleFrom(
        backgroundColor: context.colors.primary.withValues(alpha: 0.1),
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}

class _WeeklySummaryLink extends StatelessWidget {
  const _WeeklySummaryLink();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => context.push('/progress/weekly-summary'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: context.colors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "This week's summary",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textDark,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitsCountLabel extends ConsumerWidget {
  const _HabitsCountLabel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final completions = ref.watch(habitCompletionsProvider);
    final dailyLog = ref.watch(dailyLogProvider);
    final completedCount = habits
        .where((h) => isHabitCompleted(h, completions, dailyLog))
        .length;

    return Text(
      '($completedCount/${habits.length})',
      style: TextStyle(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: context.colors.primary,
        fontSize: 13,
      ),
    );
  }
}

class _HabitsEditButton extends StatelessWidget {
  const _HabitsEditButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => const ManageHabitsScreen()));
      },
      child: Icon(Icons.edit_rounded, color: context.colors.primary, size: 18),
    );
  }
}

class _WorkoutsSection extends ConsumerWidget {
  const _WorkoutsSection({required this.plan});

  final dynamic plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutPlan = ref.watch(workoutPlanProvider);
    final phaseProgress = ref.watch(phaseProgressProvider);
    if (workoutPlan == null || workoutPlan.days.isEmpty)
      return const SizedBox();

    final dateStr = ref.watch(dateStringProvider);

    final selectedDate = DateTime.parse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isFuture = selectedDate.isAfter(today);

    final day = WorkoutCompletion.resolveWorkoutDay(workoutPlan, selectedDate);
    final isRest = WorkoutCompletion.isRestDay(day, selectedDate);

    final logRepo = ref.watch(exerciseLogRepoProvider);
    ref.watch(exerciseLogsUpdateProvider); // Rebuild when logs are saved
    final dailyLog = ref.watch(dailyLogProvider);
    final isWholeDayCompleted = WorkoutCompletion.isDayWorkoutDoneWithRepo(
      date: dateStr,
      day: day,
      dateTime: selectedDate,
      repo: logRepo,
      dailyLog: dailyLog,
    );

    final List<Widget> cards = [];
    int completedCount = 0;

    if (isRest) {
      cards.add(
        _buildCard(
          context,
          title: 'Rest Day',
          subtitle: 'Recovery day — you\'re all set. Rest counts as complete.',
          isCompleted: isWholeDayCompleted,
          isFuture: isFuture,
          isRest: true,
        ),
      );
      if (isWholeDayCompleted) completedCount = 1;
    } else {
      for (int i = 0; i < day.sections.length; i++) {
        final sec = day.sections[i];

        final isCompleted = WorkoutCompletion.isSectionCompleteWithRepo(
          dateStr,
          sec,
          logRepo,
        );
        if (isCompleted) completedCount++;

        String title = (i == 0) ? (day.dayId ?? '') : (sec.title ?? '');
        
        if (title.startsWith('beg_day')) {
          title = 'Beginner Day ${title.substring(7)}';
        } else if (title.startsWith('int_day')) {
          title = 'Intermediate Day ${title.substring(7)}';
        } else if (title.startsWith('adv_day')) {
          title = 'Advanced Day ${title.substring(7)}';
        }

        if ((sec.title?.toLowerCase() ?? '').contains('cooldown') ||
            (sec.title?.toLowerCase() ?? '').contains('cool down')) {
          title = 'Cool down';
        }

        final String subtitle = (i == 0)
            ? 'Complete your scheduled workout'
            : '${sec.exercises.length} exercises';

        cards.add(
          _buildCard(
            context,
            title: title,
            subtitle: subtitle,
            isCompleted: isCompleted,
            isFuture: isFuture,
            isRest: false,
            heroTag: 'workout-${day.dayId}-section-$i',
            onTap: () => context.go('/home/workout/${day.dayId}?section=$i'),
          ),
        );
      }
    }

    final total = isRest ? 1 : day.sections.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'WORKOUTS ($completedCount/$total)',
          trailing: phaseProgress.isPhaseActive
              ? Row(
                  children: [
                    Text(
                      'Week ${phaseProgress.currentWeek} of ${phaseProgress.totalWeeks}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        value:
                            (phaseProgress.currentWeek - 1) /
                            phaseProgress.totalWeeks,
                        strokeWidth: 2,
                        backgroundColor: context.colors.primary.withValues(
                          alpha: 0.2,
                        ),
                        color: context.colors.primary,
                      ),
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
          child: Column(children: cards),
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isFuture,
    required bool isRest,
    String? heroTag,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        onTap: isFuture ? null : onTap,
        color: context.colors.card,
        border: null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (heroTag != null)
                    Hero(
                      tag: heroTag,
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          title,
                          style: TextStyle(
                            color: context.colors.textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      title,
                      style: TextStyle(
                        color: context.colors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.colors.textMedium,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (isCompleted)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: context.colors.green,
                  size: 24,
                ),
              )
            else if (isRest)
              Icon(
                Icons.self_improvement_rounded,
                color: context.colors.textMedium,
                size: 32,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMedium,
                  size: 28,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
