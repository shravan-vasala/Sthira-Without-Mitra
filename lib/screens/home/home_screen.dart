import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/insights_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../providers/sync_controller.dart';
import '../../providers/midnight_tick_provider.dart';

import '../../services/health_connect_service.dart';
import '../../services/screen_time_service.dart';
import '../../models/habit.dart';
import '../../utils/workout_completion.dart';
import '../../widgets/section_header.dart';
import '../../theme/layout_insets.dart';
import '../../theme/app_typography.dart';
import '../../providers/app_providers.dart';
import '../../providers/badge_engine_provider.dart';
import '../../widgets/surface_card.dart';
import '../profile/manage_habits_screen.dart';
import 'widgets/week_calendar_strip.dart';
import 'widgets/meals_card.dart';
import 'widgets/habits_card.dart';
import 'widgets/daily_progress_grid.dart';
import 'widgets/coach_notes_card.dart';
import 'widgets/daily_insight_card.dart';
import 'widgets/day_complete_sheet.dart';

import 'widgets/day_complete_sheet.dart';
import '../../providers/gamification_provider.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _habitsKey = GlobalKey();
  final _mealsKey = GlobalKey();
  final _progressKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Initial sync when screen first loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncControllerProvider.notifier).sync(isManualRefresh: true);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Removed _staggerWrap logic entirely to rely on a separate Stateful widget

  @override
  Widget build(BuildContext context) {
    ref.watch(badgeEngineProvider); // Initialize Gamification Engine
    final plan = ref.watch(workoutPlanProvider);
    ref.watch(syncControllerProvider);
    final dailyScore = ref.watch(dailyScoreProvider);
    final hasInsight = ref.watch(insightsProvider).isNotEmpty;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$next-day steps goal streak unlocked.',
            ),
          ),
        );
      }
    });

    ref.listen<int>(mealStreakProvider, (prev, next) {
      if (next == 3 && (prev == null || prev < 3)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '3-day meal tracking streak achieved.',
            ),
          ),
        );
      }
    });

    return Stack(
      children: [
        Scaffold(
          backgroundColor: context.colors.scaffoldBg,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: context.colors.primary,
            onRefresh: () => ref
                .read(syncControllerProvider.notifier)
                .sync(isManualRefresh: true),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
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
                      StaggeredFadeIn(index: 1, child: const WeekCalendarStrip()),
                      const SizedBox(height: 24),

                      // 3. Workout (primary daily action)
                      if (plan != null && plan.days.isNotEmpty) ...[
                        StaggeredFadeIn(index: 2, child: _WorkoutsSection(plan: plan)),
                        const SizedBox(height: 24),
                      ],

                      // 4. Habits
                      StaggeredFadeIn(
                        index: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KeyedSubtree(
                              key: _habitsKey,
                              child: const SectionHeader(
                                'Habits',
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
                      StaggeredFadeIn(
                        index: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KeyedSubtree(
                              key: _mealsKey,
                              child: const SectionHeader('Meals'),
                            ),
                            const SizedBox(height: 12),
                            const MealsCard(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 6. Daily progress metrics
                      StaggeredFadeIn(
                        index: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KeyedSubtree(
                              key: _progressKey,
                              child: const SectionHeader(
                                'Daily progress',
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
                      
                      // 7. Secondary Coach/Insight
                      if (hasInsight)
                        StaggeredFadeIn(
                          index: 6,
                          child: const DailyInsightCard(),
                        )
                      else
                        StaggeredFadeIn(
                          index: 6,
                          child: const CoachNotesCard(),
                        ),

                      // Explicit bottom clearance for floating nav constraints
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        ),

        Align(
          alignment: Alignment.topCenter,
        ),
      ],
    );
  }
}

class StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggeredFadeIn({super.key, required this.index, required this.child});

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn> {
  bool _played = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _played = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return _played
        ? widget.child
        : widget.child
            .animate(delay: (widget.index * 60).ms)
            .fadeIn(duration: 400.ms, curve: Curves.easeOut)
            .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOut);
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isEmpty)
          Text(
            _timeGreeting(),
            style: TextStyle(
              fontFamily: 'General Sans',
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: context.colors.textMedium,
              letterSpacing: -0.3,
            ),
          )
        else
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${_timeGreeting()}, ',
                  style: TextStyle(
                    fontFamily: 'General Sans',
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: context.colors.textMedium,
                    letterSpacing: -0.3,
                  ),
                ),
                TextSpan(
                  text: name,
                  style: TextStyle(
                    fontFamily: 'General Sans',
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        if (!isToday) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                DateFormat('EEEE, MMM d').format(selected),
                style: context.text.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colors.textDark,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  ref.read(selectedDateProvider.notifier).state = today;
                  ref.read(weekOffsetProvider.notifier).state = 0;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: context.colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Return to Today',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  DateTime selectedDay(DateTime s) => DateTime(s.year, s.month, s.day);
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
                size: 16,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        '$completedCount/${habits.length}',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: context.colors.textLight,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _HabitsEditButton extends StatelessWidget {
  const _HabitsEditButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Edit Habits',
      onPressed: () {
        Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => const ManageHabitsScreen()));
      },
      icon: Icon(Icons.edit_rounded, color: context.colors.primary, size: 24),
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

        int exercisesLogged = 0;
        int firstUnloggedIndex = -1;
        String? firstUnlogged;
        for (int e = 0; e < sec.exercises.length; e++) {
          final ex = sec.exercises[e];
          if (logRepo.hasLog(dateStr, ex.name ?? '')) {
            exercisesLogged++;
          } else if (firstUnlogged == null) {
            firstUnlogged = ex.name;
            firstUnloggedIndex = e;
          }
        }

        String subtitle;
        if (exercisesLogged == 0) {
          subtitle = '${sec.exercises.length} exercises · Ready to start';
        } else if (exercisesLogged == sec.exercises.length) {
          subtitle = '${sec.exercises.length}/${sec.exercises.length} logged · View workout';
        } else {
          subtitle = 'Continue · $exercisesLogged/${sec.exercises.length} logged · Next: $firstUnlogged';
        }

        cards.add(
          _buildCard(
            context,
            title: title,
            subtitle: subtitle,
            isCompleted: isCompleted,
            isFuture: isFuture,
            isRest: false,
            heroTag: 'workout-${day.dayId}-section-$i',
            onTap: () {
               String route = '/home/workout/${day.dayId}?section=$i';
               if (firstUnloggedIndex != -1 && exercisesLogged > 0) {
                 route += '&jumpTo=$firstUnloggedIndex';
               }
               context.go(route);
            },
          ),
        );
      }
    }

    final total = isRest ? 1 : day.sections.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Workouts',
          countLabel: Text(
            '($completedCount/$total)',
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'General Sans',
              fontWeight: FontWeight.w500,
              color: context.colors.primary.withValues(alpha: 0.8),
            ),
          ),
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
                            fontFamily: 'Cabinet Grotesk',
                            color: context.colors.textDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Cabinet Grotesk',
                        color: context.colors.textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
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
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
