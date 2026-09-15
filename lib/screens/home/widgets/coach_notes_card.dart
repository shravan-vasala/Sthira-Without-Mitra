import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/layout_insets.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/credential_provider.dart';
import '../../../widgets/surface_card.dart';
import '../../../widgets/async_error_card.dart';
import '../../../widgets/app_bottom_sheet.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class CoachNotesCard extends ConsumerWidget {
  const CoachNotesCard({super.key});

  void _showHistory(BuildContext context, WidgetRef ref) {
    final repo = ref.read(coachNoteRepoProvider);
    final history = repo.getRecentNotes(7);

    showAppBottomSheet(
      context: context,
      builder: (context) {
        return AppSheet(
          title: 'Coach History',
          scrollable: true,
          maxHeightFactor: 0.6,
          child: history.isEmpty
              ? Center(
                  child: Text(
                    'No history yet. Check back tomorrow!',
                    style: context.text.body.copyWith(color: context.colors.textLight),
                  ),
                )
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final h = history[index];
                    final dt = DateTime.tryParse(h.date) ?? DateTime.now();
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(kCardRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('MMM d, yyyy').format(dt),
                                style: context.text.caption.copyWith(color: context.colors.primary),
                              ),
                              if (h.isAi)
                                Icon(
                                  Icons.auto_awesome,
                                  size: 12,
                                  color: context.colors.primary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            h.note,
                            style: context.text.body.copyWith(color: context.colors.textDark),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(coachNoteProvider);
    final profile = ref.watch(profileProvider);
    final cred = ref.watch(credentialProvider);
    final hasKey = cred.status == CredentialStatus.present && (cred.key ?? '').isNotEmpty;

    return SurfaceCard(
      onTap: () => _showHistory(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.sports_rounded,
                  color: context.colors.onPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  profile.coachDisplayName,
                  style: context.text.bodyStrong.copyWith(color: context.colors.primary),
                ),
              ),
              if (!hasKey)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Tooltip(
                    message: 'AI API Key not set',
                    child: Icon(
                      Icons.key_off_rounded,
                      color: context.colors.orange,
                      size: 20,
                    ),
                  ),
                ),
              if (!noteAsync.isLoading)
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: context.colors.primary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    ref.read(coachNoteProvider.notifier).fetchNote(force: true);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          noteAsync.when(
            data: (note) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      note.note,
                      style: context.text.body.copyWith(color: context.colors.textDark),
                    )
                    .animate(key: ValueKey(note.note))
                    .fade(duration: 500.ms)
                    .slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 500.ms,
                      curve: Curves.easeOut,
                    ),
                if (note.isAi) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: context.colors.primary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Generated by AI',
                        style: context.text.micro.copyWith(color: context.colors.textMedium.withValues(
                            alpha: 0.8),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Coach is writing...',
                style: context.text.body.copyWith(color: context.colors.textMedium),
              ).animate(onPlay: MediaQuery.disableAnimationsOf(context) ? (c) => c.stop() : (c) => c.repeat()).shimmer(
                duration: MediaQuery.disableAnimationsOf(context) ? 0.ms : 1500.ms,
                color: context.colors.primary,
              ),
            ),
            error: (err, stack) => AsyncErrorCard(
              title: 'Coach is offline',
              message:
                  'Couldn\'t connect to AI coach. Keep up the great work today!',
              actionText: 'Retry',
              onRetry: () {
                ref.read(coachNoteProvider.notifier).fetchNote(force: true);
              },
            ),
          ),
        ],
      ),
    );
  }
}
