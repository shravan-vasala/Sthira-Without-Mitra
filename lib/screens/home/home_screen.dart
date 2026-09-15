import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/insights_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../providers/midnight_tick_provider.dart';

import '../../models/habit.dart';
import '../../utils/workout_completion.dart';
import '../../utils/workout_formatting.dart';
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
          SnackBar(content: Text('$next-day steps goal streak unlocked.')),
        );
      }
    });

    ref.listen<int>(mealStreakProvider, (prev, next) {
      if (next == 3 && (prev == null || prev < 3)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('3-day meal tracking streak achieved.')),
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
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: kScreenPadding,
                          ),
                          child: StaggeredFadeIn(
                            key: ValueKey('home_greeting'),
                            index: 0,
                            child: _HomeGreetingTitle(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 2. Week calendar + score
                        const StaggeredFadeIn(
                          key: ValueKey('calendar_strip'),
                          index: 1,
                          child: WeekCalendarStrip(),
                        ),
                        const SizedBox(height: 24),

                        // 3. Workout (primary daily action)
                        if (plan != null && plan.days.isNotEmpty) ...[
                          StaggeredFadeIn(
                            key: const ValueKey('workouts_section'),
                            index: 2,
                            child: _WorkoutsSection(plan: plan),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // 4. Habits
                        StaggeredFadeIn(
                          key: const ValueKey('habits_section'),
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
                          key: const ValueKey('meals_section'),
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
                          key: const ValueKey('progress_section'),
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
                              const SizedBox(height: 12),
                              const _WeeklySummaryLink(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 7. Secondary Coach/Insight
                        if (hasInsight)
                          const StaggeredFadeIn(
                            key: ValueKey('insight_card'),
                            index: 6,
                            child: DailyInsightCard(),
                          )
                        else
                          const StaggeredFadeIn(
                            key: ValueKey('coach_notes_card'),
                            index: 6,
                            child: CoachNotesCard(),
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

        const Align(alignment: Alignment.topCenter),
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
              .slideY(
                begin: 0.08,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOut,
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
    final profile = ref.watch(profileProvider);
    final name = profile.name.trim();
    final selected = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = selectedDay(selected) == today;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE, d MMMM').format(selected).toUpperCase(),
          style: context.text.eyebrow.copyWith(
            color: context.colors.textLight,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: name.isEmpty
                          ? _timeGreeting()
                          : '${_timeGreeting()}, ',
                      style: context.text.screenTitle.copyWith(
                        color: context.colors.textMedium,
                      ),
                    ),
                    if (name.isNotEmpty)
                      TextSpan(
                        text: name,
                        style: context.text.screenTitle.copyWith(
                          color: context.colors.textDark,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!isToday) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  ref.read(selectedDateProvider.notifier).state = today;
                  ref.read(weekOffsetProvider.notifier).state = 0;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Return to Today',
                        style: context.text.micro.copyWith(
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
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
                  style: context.text.body.copyWith(
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

    return Text(
      '$completedCount/${habits.length}',
      style: context.text.body.copyWith(color: context.colors.textLight),
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
      icon: Icon(Icons.edit_rounded, color: context.colors.primary, ),
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
    if (workoutPlan == null || workoutPlan.days.isEmpty) {
      return const SizedBox();
    }

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

        final String title = formatSectionTitle(sec.title, i);

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
          subtitle =
              '${sec.exercises.length}/${sec.exercises.length} logged · View workout';
        } else {
          subtitle =
              'Continue · $exercisesLogged/${sec.exercises.length} logged · Next: $firstUnlogged';
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
            style: context.text.body.copyWith(
              color: context.colors.primary.withValues(alpha: 0.8),
            ),
          ),
          trailing: phaseProgress.isPhaseActive
              ? Row(
                  children: [
                    Text(
                      'Week ${phaseProgress.currentWeek} of ${phaseProgress.totalWeeks}',
                      style: context.text.micro.copyWith(
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
                          style: context.text.cardTitle.copyWith(
                            color: context.colors.textDark,
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      title,
                      style: context.text.cardTitle.copyWith(
                        color: context.colors.textDark,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: context.text.micro.copyWith(
                      color: context.colors.textMedium,
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
