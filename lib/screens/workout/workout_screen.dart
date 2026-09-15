import 'package:flutter/material.dart';
import '../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../models/workout_plan.dart';
import 'widgets/exercise_card.dart';
import 'widgets/rest_timer_label.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../widgets/primary_button.dart';
import '../../utils/workout_formatting.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';
class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({
    super.key,
    required this.dayId,
    this.sectionIndex,
    this.jumpToIndex,
  });

  final String dayId;

  /// null = show all sections; 0+ = show that specific section only
  final int? sectionIndex;
  final int? jumpToIndex;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  /// When non-null, only show that section. When null, show all.
  int? _activeSectionIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _activeSectionIndex = widget.sectionIndex;
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(workoutPlanProvider);
    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: Text('No workout plan found')),
      );
    }

    WorkoutDay? day;
    for (final d in plan.days) {
      if (d.dayId == widget.dayId) {
        day = d;
        break;
      }
    }

    if (day == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: Text('Workout day not found')),
      );
    }

    final workoutDay = day;

    final logRepo = ref.watch(exerciseLogRepoProvider);
    final dateStr = ref.watch(dateStringProvider);
    ref.watch(exerciseLogsUpdateProvider); // Trigger rebuild on log save

    final totalExercises = workoutDay.sections.fold<int>(
      0,
      (sum, s) => sum + s.exercises.length,
    );
    final completedExercises = workoutDay.sections.fold<int>(
      0,
      (sum, s) =>
          sum +
          s.exercises
              .where((e) => logRepo.hasLog(dateStr, e.instanceId ?? e.name ?? ''))
              .length,
    );

    final isFinished = ref
        .watch(workoutRepoProvider)
        .isWorkoutFinished(dateStr, widget.dayId);
        
    final selectedDate = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isFuture = selectedDay.isAfter(today);

    // Determine which sections to display
    final bool isFiltered =
        _activeSectionIndex != null &&
        _activeSectionIndex! >= 0 &&
        _activeSectionIndex! < workoutDay.sections.length;
    final sectionsToShow = isFiltered
        ? [workoutDay.sections[_activeSectionIndex!]]
        : workoutDay.sections;

    // Title: use section name when filtered, day label when showing all
    final String appBarTitle = isFiltered
        ? formatSectionTitle(workoutDay.sections[_activeSectionIndex!].title, _activeSectionIndex!)
        : workoutDay.label ?? workoutDay.dayId ?? '';

    // Progress counts for current view
    final viewExercises = isFiltered
        ? workoutDay.sections[_activeSectionIndex!].exercises.length
        : totalExercises;
    final viewCompleted = isFiltered
        ? workoutDay.sections[_activeSectionIndex!].exercises
              .where((e) => logRepo.hasLog(dateStr, e.instanceId ?? e.name ?? ''))
              .length
        : completedExercises;

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.sectionIndex != null)
                          Hero(
                            tag:
                                'workout-${widget.dayId}-section-${widget.sectionIndex}',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                appBarTitle,
                                style: context.text.screenTitle.copyWith(color: context.colors.textDark),
                              ),
                            ),
                          )
                        else
                          Text(
                            appBarTitle,
                            style: context.text.screenTitle.copyWith(color: context.colors.textDark),
                          ),
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: viewCompleted),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutQuart,
                            builder: (context, value, child) {
                              return Text(
                                '$value/$viewExercises exercises done',
                                style: AppTheme.numeric(
                                  context.text.caption.copyWith(color: context.colors.textMedium),
                                ),
                              );
                            }
                          ),
                      ],
                    ),
                  ),
                  if (isFinished)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.greenLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: context.colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Done',
                            style: context.text.caption.copyWith(color: context.colors.green),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Progress bar (always total day progress) ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: totalExercises > 0
                      ? completedExercises / totalExercises
                      : 0,
                  backgroundColor: context.colors.primary.withValues(
                    alpha: 0.12,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.colors.green,
                  ),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (totalExercises > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Day total: $completedExercises/$totalExercises',
                      style: AppTheme.numeric(
                        context.text.micro.copyWith(color: context.colors.textLight),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // ── "Show all sections" banner when filtered ─────────────────
            if (isFiltered)
              GestureDetector(
                onTap: () => setState(() => _activeSectionIndex = null),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                    decoration: BoxDecoration(
                      color: context.colors.insetSurface,
                      borderRadius: BorderRadius.circular(14),
                      // Sthira: No borders! Let floating backgrounds separate space
                    ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        color: context.colors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Showing: ${formatSectionTitle(workoutDay.sections[_activeSectionIndex!].title, _activeSectionIndex!)}',
                        style: context.text.caption.copyWith(color: context.colors.primary),
                      ),
                      const Spacer(),
                      Text(
                        'Show all →',
                        style: context.text.micro.copyWith(color: context.colors.primary),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Sections list ─────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: sectionsToShow.length,
                itemBuilder: (context, listIndex) {
                  // Map back to original section index for consistency
                  final sectionIndex = isFiltered
                      ? _activeSectionIndex!
                      : listIndex;
                  final section = sectionsToShow[listIndex];
                  return _SectionWidget(
                        section: section,
                        sectionIndex: sectionIndex,
                        dayId: widget.dayId,
                        jumpToIndex: (widget.sectionIndex == sectionIndex) ? widget.jumpToIndex : null,
                      )
                      .animate(delay: (listIndex * 100).ms)
                      .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                      .slideY(
                        begin: 0.1,
                        end: 0,
                        duration: 400.ms,
                        curve: Curves.easeOutCubic,
                      );
                },
              ),
            ),

            // ── Rest Timer Floating Bar ───────────────────────────────────
            if (ref.watch(restTimerProvider).isActive)
              _buildRestTimerBar(context, ref, ref.read(restTimerProvider)),

            // ── Finish Workout Button ─────────────────────────────────────
            if (!isFinished)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: PrimaryButton(
                  label: 'Finish Workout',
                  icon: Icons.emoji_events_rounded,
                  onPressed: isFuture ? null : () => _finishWorkout(
                    context,
                    ref,
                    widget.dayId,
                    completedExercises,
                    totalExercises,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _finishWorkout(
    BuildContext context,
    WidgetRef ref,
    String dayId,
    int completed,
    int total,
  ) {
    if (completed < total) {
      if (completed == 0) {
        _showSkipConfirmation(context, ref, dayId);
      } else {
        _showPartialConfirmation(context, ref, dayId, completed, total);
      }
    } else {
      _executeFinish(context, ref, dayId, completed, total);
    }
  }

  void _showPartialConfirmation(
    BuildContext context,
    WidgetRef ref,
    String dayId,
    int completed,
    int total,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish early?'),
        content: Text(
          'Only $completed of $total exercises done — finish anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _persistWorkoutFinished(ref, dayId, status: 'partial');
              if (context.mounted) {
                _executeFinish(context, ref, dayId, completed, total, isPartial: true);
              }
            },
            child: const Text('Finish early'),
          ),
        ],
      ),
    );
  }

  void _showSkipConfirmation(
    BuildContext context,
    WidgetRef ref,
    String dayId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip workout?'),
        content: const Text(
          'Nothing checked — mark this workout as skipped instead?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _persistWorkoutFinished(ref, dayId, status: 'skipped');
              if (context.mounted) {
                context.go('/home');
              }
            },
            child: const Text('Skip Workout'),
          ),
        ],
      ),
    );
  }

  Future<void> _persistWorkoutFinished(WidgetRef ref, String dayId, {String status = 'completed'}) async {
    final dateStr = ref.read(dateStringProvider);
    await ref.read(workoutRepoProvider).finishWorkout(dateStr, dayId, status: status);
    await ref.read(dailyLogProvider.notifier).updateWorkoutStatus(dayId, status);
  }

  void _executeFinish(
      BuildContext context, WidgetRef ref, String dayId, int completed, int total, {bool isPartial = false}) async {
    if (!isPartial) {
      await _persistWorkoutFinished(ref, dayId, status: 'completed');
    }
    Haptics.toggle();

    final name = ref.read(profileProvider).name.trim();
    final title = isPartial 
        ? '$completed of $total exercises done!' 
        : (name.isEmpty ? 'Workout complete!' : 'Nice work, $name!');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Stack(
        alignment: Alignment.center,
        children: [
          Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: context.colors.card,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.12), // gold
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFFFD700), // gold
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: AppTheme.numeric(
                      context.text.screenTitle.copyWith(color: context.colors.textDark),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$completed / $total exercises completed.',
                    style: AppTheme.numeric(
                      context.text.bodyStrong.copyWith(color: context.colors.primary),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Session saved. Head home to finish habits and meals if you have any left.',
                    style: context.text.body.copyWith(color: context.colors.textMedium),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Back to Home',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.go('/home');
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestTimerBar(BuildContext context, WidgetRef ref, RestTimerState state) {
    if (!state.isActive) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.insetSurface,
        borderRadius: BorderRadius.circular(20),
        // Sthira: No borders! Use shadow for elevation
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // Circle countdown
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: (state.remainingSeconds % 60) / 60, // visual only, assumes mostly < 2 mins
                  strokeWidth: 4,
                  backgroundColor: context.colors.primary.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(context.colors.primary),
                ),
              ),
              Text(
                '${state.remainingSeconds}',
                style: context.text.bodyStrong.copyWith(color: context.colors.textDark),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Resting',
                  style: context.text.micro.copyWith(color: context.colors.textMedium),
                ),
                Text(
                  state.exerciseName ?? 'Rest Timer',
                  style: context.text.body.copyWith(color: context.colors.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.exposure_plus_1, color: context.colors.primary), // 30s roughly
                onPressed: () => ref.read(restTimerProvider.notifier).addSeconds(30),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  state.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, 
                  color: context.colors.primary,
                ),
                onPressed: () {
                  if (state.isPaused) {
                    ref.read(restTimerProvider.notifier).resumeTimer();
                  } else {
                    ref.read(restTimerProvider.notifier).pauseTimer();
                  }
                },
              ),
              IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.skip_next_rounded, color: context.colors.textDark),
                onPressed: () => ref.read(restTimerProvider.notifier).stopTimer(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section Widget ───────────────────────────────────────────────────────────

class _SectionWidget extends StatefulWidget {
  const _SectionWidget({
    required this.section,
    required this.sectionIndex,
    required this.dayId,
    this.jumpToIndex,
  });

  final WorkoutSection section;
  final int sectionIndex;
  final String dayId;
  final int? jumpToIndex;

  @override
  State<_SectionWidget> createState() => _SectionWidgetState();
}

class _SectionWidgetState extends State<_SectionWidget> {
  final _jumpKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.jumpToIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_jumpKey.currentContext != null) {
          Scrollable.ensureVisible(
            _jumpKey.currentContext!,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            alignment: 0.2,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sticky-style section header
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formatSectionTitle(widget.section.title, widget.sectionIndex),
                    style: context.text.bodyStrong.copyWith(color: context.colors.textDark),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.section.exercises.length} exercises',
                  style: context.text.micro.copyWith(color: context.colors.textMedium),
                ),
              ],
            ),
          ),
          if (widget.section.exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'No exercises in this section.',
                style: context.text.body.copyWith(color: context.colors.textMedium),
              ),
            )
          else
            ...List.generate(widget.section.exercises.length * 2 - 1, (index) {
              if (index.isOdd) {
                final exerciseIndex = index ~/ 2;
                final exercise = widget.section.exercises[exerciseIndex];
                if (exercise.restSecondsAfterSet > 0) {
                  return RestTimerLabel(
                    seconds: exercise.restSecondsAfterSet,
                    exerciseName: exercise.name ?? '',
                  );
                }
                return const SizedBox(height: 4);
              }
              final exerciseIndex = index ~/ 2;
              final exercise = widget.section.exercises[exerciseIndex];
              return Container(
                key: (widget.jumpToIndex == exerciseIndex) ? _jumpKey : null,
                child: ExerciseCard(
                  exercise: exercise, 
                  dayId: widget.dayId,
                  highlight: widget.jumpToIndex == exerciseIndex,
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
