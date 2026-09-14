import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/app_providers.dart';
import '../../../models/workout_plan.dart';
import '../../../utils/exercise_log_save.dart';
import '../../../widgets/surface_card.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../theme/app_theme.dart';
import '../log_data_dialog.dart';
import '../../../utils/format_units.dart';

class ExerciseCard extends ConsumerWidget {
  const ExerciseCard({super.key, required this.exercise, required this.dayId, this.highlight = false});

  final Exercise exercise;
  final String dayId;
  final bool highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(exerciseLogsUpdateProvider);
    final pr = ref.watch(exercisePrProvider(exercise.name ?? ''));
    final logRepo = ref.watch(exerciseLogRepoProvider);
    final profile = ref.watch(profileProvider);
    final useKg = profile.useKg;
    final dateStr = ref.watch(dateStringProvider);
    final log = logRepo.getLog(dateStr, exercise.instanceId ?? exercise.name ?? '');
    final isCompleted = log != null;
    
    final selectedDate = ref.watch(selectedDateProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isFuture = DateTime(selectedDate.year, selectedDate.month, selectedDate.day).isAfter(today);

    String? loggedText;
    if (log != null && log.sets.isNotEmpty) {
      final repsList = log.sets
          .map((s) {
            if ((s.weight ?? 0) > 0) {
              final w = convertFromKg(profile, s.weight!);
              return '${s.reps}x${w.toInt()}${useKg ? 'kg' : 'lb'}';
            }
            return '${s.reps}';
          })
          .join(', ');
      loggedText = 'Done: $repsList';
    }

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      elevation: SurfaceCardElevation.home,
      color: highlight ? context.colors.primary.withValues(alpha: 0.05) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // YouTube Thumbnail
                Semantics(
                  label:
                      'Play ${exercise.displayName ?? exercise.name ?? ''} video tutorial',
                  button: true,
                  child: GestureDetector(
                    onTap: () async {
                      final videoId = exercise.youtubeVideoId;
                      if (videoId != null &&
                          videoId != 'XXXX' &&
                          videoId.isNotEmpty) {
                        // ignore: unawaited_futures
                        context.push(
                          '/youtube-player?videoId=$videoId&title=${Uri.encodeComponent(exercise.displayName ?? exercise.name ?? '')}&subtitle=${Uri.encodeComponent(exercise.name ?? '')}&reps=${Uri.encodeComponent(exercise.repsDisplay ?? '')}',
                        );
                      } else {
                        final query = Uri.encodeComponent(
                          '${exercise.displayName ?? exercise.name ?? ''} exercise tutorial',
                        );
                        final url = Uri.parse(
                          'https://www.youtube.com/results?search_query=$query',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    },
                    child: Container(
                      width: 90,
                      height: 68,
                      decoration: BoxDecoration(
                        color: context.colors.insetSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          (exercise.youtubeVideoId == null ||
                              exercise.youtubeVideoId == 'XXXX' ||
                              exercise.youtubeVideoId!.isEmpty)
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  color: context.colors.primary,
                                  size: 24,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Search YT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.primary,
                                  ),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (exercise.thumbnailUrl.isNotEmpty)
                                    CachedNetworkImage(
                                      imageUrl: exercise.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (ctx, url) => Center(
                                        child: Icon(
                                          Icons.fitness_center_rounded,
                                          color: context.colors.primary,
                                          size: 30,
                                        ),
                                      ),
                                      errorWidget: (ctx, url, error) => Center(
                                        child: Icon(
                                          Icons.fitness_center_rounded,
                                          color: context.colors.primary,
                                          size: 30,
                                        ),
                                      ),
                                    )
                                  else
                                    Center(
                                      child: Icon(
                                        Icons.fitness_center_rounded,
                                        color: context.colors.primary,
                                        size: 30,
                                      ),
                                    ),
                                  // Play overlay
                                  if (exercise.youtubeUrl != null &&
                                      exercise.youtubeUrl!.isNotEmpty)
                                    Center(
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: context.colors.card,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Exercise info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.displayName ?? exercise.name ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            '${exercise.repsDisplay} Reps',
                            style: AppTheme.numeric(
                              TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                          if (exercise.weightKg != null) ...[
                            Text('•', style: TextStyle(color: context.colors.border, fontSize: 10)),
                            Text(
                              '${convertFromKg(profile, exercise.weightKg!).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} ${useKg ? 'kg' : 'lb'}',
                              style: AppTheme.numeric(
                                TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.primary,
                                ),
                              ),
                            ),
                          ],
                          if (exercise.sideInfo != 'None') ...[
                            Text('•', style: TextStyle(color: context.colors.border, fontSize: 10)),
                            Text(
                              exercise.sideInfo ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.colors.mintIcon,
                              ),
                            ),
                          ],
                          if (pr != null) ...[
                            Text('•', style: TextStyle(color: context.colors.border, fontSize: 10)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.emoji_events,
                                  size: 14,
                                  color: Color(0xFFB8860B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  pr.maxWeight > 0
                                      ? '${convertFromKg(profile, pr.maxWeight).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}${useKg ? 'kg' : 'lb'}'
                                      : '${pr.maxReps} reps',
                                  style: AppTheme.numeric(
                                    const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB8860B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      if (loggedText != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          loggedText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.colors.green,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Checkmark
                Semantics(
                  label:
                      'Mark ${exercise.displayName ?? exercise.name ?? ''} as ${isCompleted ? 'incomplete' : 'complete'}',
                  button: true,
                  child: GestureDetector(
                    onTap: isFuture ? null : () {
                      showAppBottomSheet(
                        context: context,
                        builder: (_) => LogDataDialog(exercise: exercise),
                      );
                    },
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? context.colors.green
                                : context.colors.textLight.withValues(alpha: 0.15),
                          ),
                          child: isCompleted
                              ? TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.elasticOut,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: Icon(
                                        Icons.check,
                                        color: context.colors.onPrimary,
                                        size: 18,
                                      ),
                                    );
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Coach note
          if (exercise.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.insetSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        // ignore: dead_null_aware_expression
                        exercise.note ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textMedium,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Button row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                if (!isCompleted)
                  _MinimalAction(
                    label: 'As planned',
                    icon: Icons.check_circle_outline_rounded,
                    onTap: () => _logAsPlanned(context, ref),
                    color: context.colors.primary,
                  ),
                _MinimalAction(
                  label: isCompleted ? 'Edit Log' : 'Adjust',
                  icon: Icons.edit_outlined,
                  onTap: () => _openLogSheet(context),
                ),
                _MinimalAction(
                  label: 'Progress',
                  icon: Icons.bar_chart_rounded,
                  onTap: () {
                    context.push('/exercise-progress?name=${Uri.encodeComponent(exercise.name ?? '')}');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openLogSheet(BuildContext context) {
    showAppBottomSheet(
      context: context,
      builder: (_) => LogDataDialog(exercise: exercise),
    );
  }

  Future<void> _logAsPlanned(BuildContext context, WidgetRef ref) async {
    final prResult = await saveExerciseAsPlanned(ref: ref, exercise: exercise);
    if (!context.mounted) return;

    final profile = ref.read(profileProvider);
    final useKg = profile.useKg;

    String msg = 'Logged ${exercise.name}';
    if (prResult.hasAnyNewPr) {
      if (prResult.isNewMaxWeight) {
        final w = convertFromKg(profile, prResult.newPr.maxWeight).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
        msg = 'New PR! $w${useKg ? 'kg' : 'lb'}';
      } else if (prResult.isNewMaxReps) {
        msg = 'New PR! ${prResult.newPr.maxReps} reps';
      } else if (prResult.isNewMaxVolume) {
        msg = 'New PR! ${prResult.newPr.maxVolume} vol';
      } else if (prResult.isNew1RM) {
        msg = 'New 1RM PR!';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: prResult.hasAnyNewPr
            ? context.colors.green
            : context.colors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _MinimalAction extends StatelessWidget {
  const _MinimalAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? context.colors.textMedium;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: baseColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: baseColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
