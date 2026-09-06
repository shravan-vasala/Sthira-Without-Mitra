import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/format_units.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/layout_insets.dart';
import '../../../providers/app_providers.dart';
import '../../../services/health_connect_service.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../theme/app_theme.dart';
import '../weight_entry_dialog.dart';
import '../steps_entry_dialog.dart';
import 'sync_status_sheet.dart';

class DailyProgressGrid extends ConsumerWidget {
  const DailyProgressGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watches:
    // - dailyLogProvider.select((l) => l.weight)
    final weight = ref.watch(dailyLogProvider.select((l) => l.weight));

    final selectedDateStr = ref.watch(dateStringProvider);
    final selectedDate = DateTime.parse(selectedDateStr);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final isFuture = selectedDate.isAfter(today);
    final isToday = selectedDate.isAtSameMomentAs(today);

    String weightSubtitle;
    if (weight != null) {
      weightSubtitle = '${weight.toStringAsFixed(1)} kg';
    } else if (isFuture) {
      weightSubtitle = 'No data';
    } else {
      final lastWeight = _lastLoggedWeight(ref, selectedDateStr);
      weightSubtitle = lastWeight != null
          ? 'Last: ${lastWeight.toStringAsFixed(1)} kg'
          : 'Tap to log';
    }

    final mediaRepo = ref.watch(mediaRepoProvider);
    final allPhotos = mediaRepo.getAllProgressPhotos();
    final flattenedPhotos = allPhotos.expand((e) => e.value).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
      child: Column(
        children: [
          _ProgressCard(
            title: 'Body Stats',
            icon: Icons.straighten_rounded,
            color: context.colors.pink,
            iconColor: context.colors.pinkIcon,
            subtitle: 'Tap to view',
            onTap: () => context.go('/home/body-stats'),
          ),
          const SizedBox(height: 12),
          _ProgressCard(
            title: 'Physique',
            icon: Icons.camera_alt_rounded,
            color: context.colors.pink,
            iconColor: context.colors.pinkIcon,
            subtitle: 'Progress',
            thumbnails: flattenedPhotos,
            onTap: () => context.go('/home/physique-pictures'),
          ),
          const SizedBox(height: 12),
          _ProgressCard(
            title: 'Body Weight',
            icon: Icons.monitor_weight_rounded,
            color: context.colors.lavenderCard,
            iconColor: context.colors.primary,
            subtitle: weightSubtitle,
            onTap: isFuture
                ? () {}
                : () {
                    showAppBottomSheet(
                      context: context,
                      builder: (_) => const WeightEntryDialog(),
                    );
                  },
            onChartTap: () => context.push('/progress?metric=weight'),
          ),
          const SizedBox(height: 12),
          _StepsCard(isFuture: isFuture, isToday: isToday),
        ],
      ),
    );
  }

  double? _lastLoggedWeight(WidgetRef ref, String beforeOrOnDate) {
    final repo = ref.read(dailyLogRepoProvider);
    final end = DateTime.parse(beforeOrOnDate);
    final start = end.subtract(const Duration(days: 90));
    final startStr =
        '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final logs = repo.getLogsInRange(startStr, beforeOrOnDate);
    for (int i = logs.length - 1; i >= 0; i--) {
      final w = logs[i].weight;
      if (w != null) return w;
    }
    return null;
  }
}

/// Special Steps card that handles the Health Connect first-run CTA.
class _StepsCard extends ConsumerStatefulWidget {
  const _StepsCard({required this.isFuture, required this.isToday});

  final bool isFuture;
  final bool isToday;

  @override
  ConsumerState<_StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends ConsumerState<_StepsCard> {
  bool _showSyncCta = false;
  bool _checkingPermission = true;
  bool _isAuth = false;

  @override
  void initState() {
    super.initState();
    _checkHealthConnectStatus();
  }

  Future<void> _checkHealthConnectStatus() async {
    final hcService = ref.read(healthConnectServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final everConnected = prefs.getBool('hc_connected') ?? false;

    // hasPermissions is flaky on Android after process death — also trust
    // a prior successful sync, and probe read access when unsure.
    var connected = everConnected || await hcService.isAuthorized();
    if (!connected) {
      connected = await hcService.canReadSteps();
      if (connected) {
        await prefs.setBool('hc_connected', true);
      }
    }

    if (mounted) {
      setState(() {
        _isAuth = connected;
        _showSyncCta = !connected && widget.isToday;
        _checkingPermission = false;
      });
    }
  }

  Future<void> _handleSyncTap() async {
    final hcService = ref.read(healthConnectServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    // Check if Health Connect is installed
    final available = await hcService.isAvailable();
    if (!available) {
      // Deep link to Play Store
      final uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // Request permission
    final granted = await hcService.requestPermission();
    if (!granted) return;

    // Trigger sync
    final dailyLogRepo = ref.read(dailyLogRepoProvider);
    final habitRepo = ref.read(habitRepoProvider);
    final steps = await hcService.syncTodayAndAutoCompleteHabit(
      dailyLogRepo,
      habitRepo,
    );
    await hcService.syncLast7Days(dailyLogRepo, habitRepo);

    await prefs.setBool('hc_connected', true);
    await prefs.setString(
      'last_hc_sync_time',
      DateTime.now().toIso8601String(),
    );
    if (steps != null) {
      ref.read(stepsSourceProvider.notifier).state = StepsSource.healthConnect;
    }

    if (mounted) {
      setState(() {
        _isAuth = true;
        _showSyncCta = false;
      });
    }

    // Backfill in background
    if (!hcService.isBackfillDone) {
      // ignore: unawaited_futures
      hcService.backfillLast90Days(dailyLogRepo, habitRepo).then((_) {
        ref.invalidate(dailyLogProvider);
        ref.invalidate(habitCompletionsProvider);
      });
    }

    ref.invalidate(dailyLogProvider);
    ref.invalidate(habitCompletionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final steps = ref.watch(dailyLogProvider.select((l) => l.steps));
    final stepsSource = ref.watch(
      dailyLogProvider.select((l) => l.stepsSource),
    );

    // Hide Sync CTA once we have Health Connect data (covers race with async permission check)
    final showSyncCta =
        _showSyncCta &&
        !_checkingPermission &&
        !(steps != null && stepsSource == 'healthConnect');

    // Show the sync CTA card if permission not granted (today only)
    if (showSyncCta) {
      return GestureDetector(
        onTap: _handleSyncTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: context.colors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: context.colors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.sync_rounded,
                  color: context.colors.onPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Sync Steps',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.colors.onPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'from Health Connect',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: context.colors.onPrimary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Determine subtitle
    String stepsSubtitle;
    String? sourceHint;

    if (steps != null) {
      stepsSubtitle = '$steps steps';
      if (stepsSource == 'healthConnect') {
        sourceHint = 'Synced via Health Connect';
      } else if (stepsSource == 'manual') {
        sourceHint = 'manual';
      }
    } else {
      stepsSubtitle = widget.isFuture ? 'No data' : 'Tap to log';
      if (_isAuth) {
        sourceHint = 'Synced';
      } else {
        sourceHint = widget.isToday ? 'Health Connect or manual' : null;
      }
    }

    return GestureDetector(
      onTap: widget.isFuture
          ? () {}
          : () {
              if (_isAuth) {
                showAppBottomSheet(
                  context: context,
                  isScrollControlled: false,
                  builder: (_) => const SyncStatusSheet(),
                );
              } else {
                showAppBottomSheet(
                  context: context,
                  builder: (_) => const StepsEntryDialog(),
                );
              }
            },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.mintIcon.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.directions_walk_rounded, size: 20, color: context.colors.mintIcon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Steps',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        stepsSubtitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textMedium,
                        ),
                      ),
                      if (sourceHint != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: (sourceHint == 'Synced via Health Connect' || sourceHint == 'Synced')
                                ? context.colors.green.withValues(alpha: 0.1)
                                : context.colors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sourceHint == 'Health Connect or manual' ? 'HC/Manual' : sourceHint,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: (sourceHint == 'Synced via Health Connect' || sourceHint == 'Synced')
                                  ? context.colors.green
                                  : context.colors.textMedium,
                            ),
                          ),
                        ),
                      ]
                    ]
                  )
                ],
              ),
            ),
            if (steps != null) ...[
              GestureDetector(
                onTap: () => context.push('/progress?metric=steps'),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.show_chart_rounded, size: 22, color: context.colors.textMedium),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: context.colors.textMedium.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.subtitle,
    required this.onTap,
    this.thumbnails,
    this.onChartTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String subtitle;
  final VoidCallback onTap;
  final List<String>? thumbnails;
  final VoidCallback? onChartTap;

  @override
  Widget build(BuildContext context) {
    String displaySubtitle = subtitle;
    if (subtitle.contains(' Tap to log') || subtitle == 'Tap to log' || subtitle == 'Tap to view' || subtitle == 'Progress photos' || subtitle == 'Progress' || subtitle == 'No data') {
      displaySubtitle = subtitle == 'No data' ? 'No data yet' : subtitle.replaceAll('--', '').trim();
    } else if (subtitle.contains('Last:')) {
      displaySubtitle = subtitle;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displaySubtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (thumbnails != null && thumbnails!.isNotEmpty)
              Row(
                children: [
                  ...thumbnails!.take(3).map(
                    (path) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? Image.network(path, width: 36, height: 36, fit: BoxFit.cover)
                            : Image.file(
                                File(path),
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                cacheWidth: 108,
                                cacheHeight: 108,
                              ),
                      ),
                    ),
                  ),
                  if (thumbnails!.length > 3)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+${thumbnails!.length - 3}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: context.colors.textMedium.withValues(alpha: 0.5)),
                ],
              )
            else ...[
              if (onChartTap != null && displaySubtitle != 'Tap to log' && displaySubtitle != 'Tap to view' && displaySubtitle != 'No data yet') ...[
                GestureDetector(
                  onTap: onChartTap,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.show_chart_rounded, size: 22, color: context.colors.textMedium),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: context.colors.textMedium.withValues(alpha: 0.5)),
            ]
          ],
        ),
      ),
    );
  }
}
