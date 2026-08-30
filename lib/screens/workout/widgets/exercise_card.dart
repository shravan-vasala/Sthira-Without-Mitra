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
import '../log_data_dialog.dart';

class ExerciseCard extends ConsumerWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.dayId,
  });

  final Exercise exercise;
  final String dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(exerciseLogsUpdateProvider);
    final pr = ref.watch(exercisePrProvider(exercise.name ?? ''));
    final logRepo = ref.watch(exerciseLogRepoProvider);
    final dateStr = ref.watch(dateStringProvider);
    final log = logRepo.getLog(dateStr, exercise.name ?? '');
    final isCompleted = log != null;
    
    String? loggedText;
    if (log != null && log.sets.isNotEmpty) {
      final repsList = log.sets.map((s) {
        if ((s.weight ?? 0) > 0) return '${s.reps}x${(s.weight ?? 0).toInt()}kg';
        return '${s.reps}';
      }).join(', ');
      loggedText = 'Done: $repsList';
    }
    
    return SurfaceCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: EdgeInsets.zero,
      elevation: SurfaceCardElevation.nested,
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
                  label: 'Play ${exercise.displayName ?? exercise.name ?? ''} video tutorial',
                  button: true,
                  child: GestureDetector(
                  onTap: () async {
                    final videoId = exercise.youtubeVideoId;
                    if (videoId != null && videoId != 'XXXX' && videoId.isNotEmpty) {
                      // ignore: unawaited_futures
                      context.push(
                        // ignore: dead_code, dead_null_aware_expression
                        '/youtube-player?videoId=$videoId&title=${Uri.encodeComponent(exercise.displayName ?? exercise.name ?? '')}&subtitle=${Uri.encodeComponent(exercise.name ?? '')}&reps=${Uri.encodeComponent(exercise.repsDisplay ?? '')}',
                      );
                    } else {
                      final query = Uri.encodeComponent('${exercise.displayName ?? exercise.name ?? ''} exercise tutorial');
                      final url = Uri.parse('https://www.youtube.com/results?search_query=$query');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  child: Container(
                    width: 90,
                    height: 68,
                    decoration: BoxDecoration(
                      color: context.colors.lavenderCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: (exercise.youtubeVideoId == null || exercise.youtubeVideoId == 'XXXX' || exercise.youtubeVideoId!.isEmpty)
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_rounded, color: context.colors.primary, size: 24),
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
                                // ignore: dead_code, dead_null_aware_expression
                                if (exercise.thumbnailUrl.isNotEmpty ?? false)
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
                                if (exercise.youtubeUrl != null && exercise.youtubeUrl!.isNotEmpty)
                                  Center(
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.colors.lavenderCard,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Reps: ${exercise.repsDisplay}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                          if (exercise.weightKg != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: context.colors.lavenderCard,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${exercise.weightKg} kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.primary,
                                ),
                              ),
                            ),
                          ],
                          if (exercise.sideInfo != 'None') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: context.colors.mint,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                // ignore: dead_code, dead_null_aware_expression
                                exercise.sideInfo ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.mintIcon,
                                ),
                              ),
                            ),
                          ],
                          if (pr != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.2), // Gold tint
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.emoji_events, size: 12, color: Color(0xFFB8860B)),
                                  const SizedBox(width: 2),
                                  Text(
                                    pr.maxWeight > 0 ? '${pr.maxWeight}kg' : '${pr.maxReps} reps',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB8860B),
                                    ),
                                  ),
                                ],
                              ),
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
                  label: 'Mark ${exercise.displayName ?? exercise.name ?? ''} as ${isCompleted ? 'incomplete' : 'complete'}',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
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
                            color: isCompleted ? context.colors.green : Colors.transparent,
                            border: isCompleted
                                ? null
                                : Border.all(color: context.colors.border, width: 2),
                          ),
                          child: isCompleted
                              ? Icon(Icons.check, color: context.colors.onPrimary, size: 18)
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
          // ignore: dead_code, dead_null_aware_expression
          if (exercise.note.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.lavenderCard.withValues(alpha: 0.6),
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
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                if (!isCompleted) ...[
                  Expanded(
                    child: CompactButton(
                      label: 'As planned',
                      filled: true,
                      onPressed: () => _logAsPlanned(context, ref),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: CompactButton(
                    label: isCompleted ? 'Edit Log' : 'Adjust',
                    filled: isCompleted,
                    onPressed: () => _openLogSheet(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CompactButton(
                    label: 'Progress',
                    onPressed: () {
                      context.push(
                        '/exercise-progress?name=${Uri.encodeComponent(exercise.name ?? '')}',
                      );
                    },
                  ),
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

    String msg = 'Logged ${exercise.name}';
    if (prResult.hasAnyNewPr) {
      if (prResult.isNewMaxWeight) {
        msg = 'New PR! ${prResult.newPr.maxWeight}kg';
      } else if (prResult.isNewMaxReps) {
        msg = 'New PR! ${prResult.newPr.maxReps} reps';
      } else if (prResult.isNewMaxVolume) {
        msg = 'New Volume PR!';
      } else if (prResult.isNew1RM) {
        msg = 'New 1RM PR!';
      }
    }

    // ignore: unused_local_variable
    final timerActive = ref.read(restTimerProvider).isActive;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            prResult.hasAnyNewPr ? context.colors.green : context.colors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 16,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

