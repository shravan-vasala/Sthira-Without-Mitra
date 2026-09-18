import 'package:trufit_bodamma/theme/app_typography.dart';
import 'package:trufit_bodamma/theme/app_colors.dart';
import 'package:trufit_bodamma/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/layout_insets.dart';
import '../../../providers/app_providers.dart';
import '../../../models/habit.dart';
import '../../../utils/workout_completion.dart';
import '../../../widgets/app_bottom_sheet.dart';
import 'past_day_summary_sheet.dart';
import 'daily_score_sheet.dart';
import '../../../theme/app_spacing.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';
import '../../../widgets/section_header.dart';
import '../../../theme/app_motion.dart';


/// Activity flags for each day in a week (keyed by yyyy-MM-dd).
/// Rebuilds when selected-day logs/habits/meals or exercise logs change, then
/// re-reads Hive for all 7 days so dots stay correct for non-selected dates.
final calendarWeekActivityProvider = Provider.family<Map<String, bool>, String>(
  (ref, weekStartStr) {
    ref.watch(dailyLogProvider);
    ref.watch(habitCompletionsProvider);
    ref.watch(dailyMealLogProvider);
    ref.watch(exerciseLogsUpdateProvider);

    final weekStart = DateTime.parse(weekStartStr);
    final dailyLogRepo = ref.watch(dailyLogRepoProvider);
    final mealRepo = ref.watch(mealRepoProvider);
    final habitRepo = ref.watch(habitRepoProvider);
    final habits = habitRepo.getHabits();

    final result = <String, bool>{};
    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final hasActivity = dailyLogRepo.hasActivityOnDate(dateStr);
      final mealLog = mealRepo.getDailyLog(dateStr);
      final habitCompletions = habitRepo.getCompletions(dateStr);
      final dailyLog = dailyLogRepo.getOrCreate(dateStr);

      final applicableHabits = habits.where((h) {
        final habitDate = DateTime(
          h.createdAt.year,
          h.createdAt.month,
          h.createdAt.day,
        );
        final sDate = DateTime(date.year, date.month, date.day);
        return !habitDate.isAfter(sDate);
      }).toList();

      final completedHabits = applicableHabits
          .where((h) => isHabitCompleted(h, habitCompletions, dailyLog))
          .length;

      result[dateStr] =
          hasActivity || mealLog.loggedSlotsCount > 0 || completedHabits > 0;
    }
    return result;
  },
);

class WeekCalendarStrip extends ConsumerStatefulWidget {
  const WeekCalendarStrip({super.key});

  @override
  ConsumerState<WeekCalendarStrip> createState() => _WeekCalendarStripState();
}

class _WeekCalendarStripState extends ConsumerState<WeekCalendarStrip> {
  late PageController _pageController;
  final int _basePage = 10000;
  bool _isManualAnimate = false;

  @override
  void initState() {
    super.initState();
    // Use the initial week offset if any
    final initialOffset = ref.read(weekOffsetProvider);
    _pageController = PageController(initialPage: _basePage + initialOffset);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    ref.listen<int>(weekOffsetProvider, (prev, next) {
      if (_pageController.hasClients && !_isManualAnimate) {
        final targetPage = _basePage + next;

        // Prevent hijacking natural PageView swipe velocities
        final currentPage = _pageController.page ?? targetPage.toDouble();
        if ((currentPage - targetPage).abs() > 0.5) {
          _pageController.animateToPage(
            targetPage,
            duration: Motion.standard,
            curve: Motion.enter,
          );
        }
      }
    });

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: kScreenPadding,
      ),
      child: Column(
        children: [
          // Date header row
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: context.colors.primary,
                        surface: context.colors.card,
                        onSurface: context.colors.textDark,
                      ),
                      dialogTheme: DialogThemeData(
                        backgroundColor: context.colors.card,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                ref.read(selectedDateProvider.notifier).state = picked;
                final pickedWeekStart = picked.subtract(
                  Duration(days: picked.weekday - 1),
                );
                final todayWeekStart = today.subtract(
                  Duration(days: today.weekday - 1),
                );
                final diffDays = pickedWeekStart
                    .difference(todayWeekStart)
                    .inDays;
                final weekOffset = (diffDays / 7).round();
                ref.read(weekOffsetProvider.notifier).state = weekOffset;
              }
            },
            child: SectionHeader(
              'This week',
              horizontalPadding: 0,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _DailyScoreBadge(),
                  const SizedBox(width: Spacing.inline),
                  IconButton(
                    tooltip: 'Previous week',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _pageController.previousPage(
                        duration: Motion.standard,
                        curve: Motion.enter,
                      );
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.colors.border.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: context.colors.textDark,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.inline),
                  IconButton(
                    tooltip: 'Next week',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _pageController.nextPage(
                        duration: Motion.standard,
                        curve: Motion.enter,
                      );
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.colors.border.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: context.colors.textDark,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.stack),

          // Week day circles
          SizedBox(
            height: 70 * MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.5),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (idx) {
                _isManualAnimate = true;
                ref.read(weekOffsetProvider.notifier).state = idx - _basePage;
                Future.microtask(() => _isManualAnimate = false);
              },
              itemBuilder: (context, index) {
                final weekOffset = index - _basePage;
                final weekStart = today
                    .subtract(Duration(days: today.weekday - 1))
                    .add(Duration(days: weekOffset * 7));

                return _WeekDaysRow(
                  weekStart: weekStart,
                  today: today,
                  selectedDate: selectedDate,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDaysRow extends ConsumerWidget {
  const _WeekDaysRow({
    required this.weekStart,
    required this.today,
    required this.selectedDate,
  });

  final DateTime weekStart;
  final DateTime today;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
    final activityByDate = ref.watch(
      calendarWeekActivityProvider(weekStartStr),
    );
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekDays.map((day) {
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        return _DayCircle(
          date: day,
          isSelected: _isSameDay(day, selectedDate),
          isToday: _isSameDay(day, today),
          isFuture: day.isAfter(today),
          isComplete: activityByDate[dateStr] ?? false,
        );
      }).toList(),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DayCircle extends ConsumerStatefulWidget {
  const _DayCircle({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.isFuture,
    required this.isComplete,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool isFuture;
  final bool isComplete;

  @override
  ConsumerState<_DayCircle> createState() => _DayCircleState();
}

class _DayCircleState extends ConsumerState<_DayCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: Motion.standard,
    );
    _scaleAnim =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 70),
        ]).animate(
          CurvedAnimation(parent: _pulseController, curve: Motion.enter),
        );
  }

  @override
  void didUpdateWidget(_DayCircle old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !old.isSelected) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('E').format(widget.date).substring(0, 3);
    final dayNum = widget.date.day.toString();

    // Planned rest: no activity dot — green/red would misread rest as success/failure.
    final plan = ref.watch(workoutPlanProvider);
    final isRestDay = plan != null
        ? WorkoutCompletion.isRestDay(
            WorkoutCompletion.resolveWorkoutDay(plan, widget.date),
            widget.date,
          )
        : widget.date.weekday == DateTime.sunday;

    final muted = context.colors.border;
    Color? dotColor;
    if (isRestDay) {
      dotColor = null;
    } else if (widget.isFuture) {
      dotColor = muted;
    } else if (widget.isToday) {
      dotColor = widget.isComplete ? context.colors.green : context.colors.red;
    } else {
      dotColor = widget.isComplete ? context.colors.green : muted;
    }

    final fullDate = DateFormat('EEEE, MMMM d').format(widget.date);
    final relative = widget.isToday
        ? "Today"
        : (widget.isFuture ? "Future" : "");
    final completion = widget.isComplete ? "Activity completed" : "No activity";
    final label = [
      if (relative.isNotEmpty) relative,
      fullDate,
      completion,
    ].join(", ");

    return Semantics(
      label: label,
      button: true,
      selected: widget.isSelected,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          if (!widget.isSelected) {
            ref.read(selectedDateProvider.notifier).state = widget.date;
          } else if (!widget.isFuture && !widget.isToday) {
            showAppBottomSheet(
              context: context,
              builder: (_) => PastDaySummarySheet(date: widget.date),
            );
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dayName.toUpperCase(),
              style: context.text.micro.copyWith(
                color: context.colors.textLight,
              ),
            ),
            const SizedBox(height: Spacing.inline),
            ScaleTransition(
              scale: _scaleAnim,
              child: AnimatedContainer(
                duration: Motion.standard,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected
                      ? context.colors.primary
                      : Colors.transparent,
                ),
                child: Center(
                  child: Text(
                    dayNum,
                    style: context.text.body.copyWith(
                      color: widget.isSelected
                          ? context.colors.onPrimary
                          : (widget.isToday
                                ? context.colors.primary
                                : context.colors.textDark),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.inline),
            // Activity dot (hidden on rest days)
            SizedBox(
              width: 8,
              height: 8,
              child: dotColor == null
                  ? null
                  : Center(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                          boxShadow: (dotColor == context.colors.green)
                              ? [
                                  BoxShadow(
                                    color: context.colors.green.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyScoreBadge extends ConsumerStatefulWidget {
  const _DailyScoreBadge();

  @override
  ConsumerState<_DailyScoreBadge> createState() => _DailyScoreBadgeState();
}

class _DailyScoreBadgeState extends ConsumerState<_DailyScoreBadge> {
  @override
  Widget build(BuildContext context) {
    final scoreData = ref.watch(dailyScoreProvider);

    final score = scoreData.totalScore;
    final isFuture = scoreData.isFutureDate;
    final totalMax = scoreData.totalMax;
    final displayScore = isFuture ? '--' : score.toString();

    final percentage = totalMax > 0 ? (score / totalMax) * 100 : 0;

    Color iconColor;
    Color textColor;
    List<Color>? gradientColors;
    Color borderColor;
    final IconData iconData = Icons.local_fire_department_rounded;

    if (isFuture) {
      iconColor = context.colors.textLight;
      textColor = context.colors.textLight;
      gradientColors = null;
      borderColor = Colors.transparent;
    } else if (percentage == 0) {
      iconColor = context.colors.textLight;
      textColor = context.colors.textDark.withValues(alpha: 0.7);
      gradientColors = [
        context.colors.border.withValues(alpha: 0.3),
        context.colors.border.withValues(alpha: 0.1),
      ];
      borderColor = context.colors.border;
    } else if (percentage < 50) {
      // Starting to warm up
      iconColor = context.colors.orange;
      textColor = context.colors.textDark;
      gradientColors = [
        context.colors.orange.withValues(alpha: 0.15),
        context.colors.orange.withValues(alpha: 0.05),
      ];
      borderColor = context.colors.orange.withValues(alpha: 0.3);
    } else if (percentage < 90) {
      // Getting hot!
      iconColor = context.colors.red;
      textColor = context.colors.textDark;
      gradientColors = [
        context.colors.red.withValues(alpha: 0.15),
        context.colors.red.withValues(alpha: 0.05),
      ];
      borderColor = context.colors.red.withValues(alpha: 0.3);
    } else {
      // Top Tier Bodamma Flame!
      iconColor = context.colors.primary;
      textColor = context.colors.primary;
      gradientColors = [
        context.colors.primary.withValues(alpha: 0.25),
        context.colors.primary.withValues(alpha: 0.05),
      ];
      borderColor = context.colors.primary.withValues(alpha: 0.3);
    }

    final semanticsLabel = isFuture
        ? 'Future date score'
        : 'Daily score: $score';

    return Semantics(
      label: semanticsLabel,
      button: !isFuture,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: isFuture
            ? null
            : () {
                showAppBottomSheet(
                  context: context,
                  builder: (ctx) => const DailyScoreSheet(),
                );
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Gap.x4),
          decoration: BoxDecoration(
            gradient: gradientColors == null
                ? null
                : LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: gradientColors == null
                ? context.colors.border.withValues(alpha: 0.5)
                : null,
            borderRadius: BorderRadius.circular(20),
            // Sthira: No borders! Let the soft gradient fill float the pill.
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, size: 16, color: iconColor),
              const SizedBox(width: 4),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: isFuture ? 0 : score),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : Motion.deliberate,
                curve: Motion.enter,
                builder: (context, value, child) {
                  return Text(
                    isFuture ? '--' : value.toString(),
                    style: context.text.micro.copyWith(color: textColor),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
