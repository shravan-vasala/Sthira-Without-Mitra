import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/ai_client.dart';
import '../../services/ai_logger.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/setup_sheets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_colors.dart';
import '../../theme/layout_insets.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/primary_button.dart';
import 'widgets/trophy_room_card.dart';
import 'widgets/journey_stats_strip.dart';
import '../../providers/app_providers.dart';
import '../../services/screen_time_service.dart';
import '../../widgets/avatar_picker_sheet.dart';
import '../../services/diagnostic_logger.dart';
import '../home/share_preview_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _appVersion = '';
  int _devTapCount = 0;

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'v${info.version}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            children: [
              // Massive Heading
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    'My Profile',
                    style: TextStyle(
                      fontFamily: 'Cabinet Grotesk',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textDark,
                    ),
                  ),
                ),
              ),

              // Profile header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: () {
                        showAppBottomSheet(
                          context: context,
                          builder: (_) => const AvatarPickerSheet(),
                        );
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.transparent,
                        ),
                        child: ClipOval(
                          child: profile.photoPath != null
                              ? (profile.photoPath!.startsWith('assets/')
                                    ? Image.asset(
                                        profile.photoPath!,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      )
                                    : (File(profile.photoPath!).existsSync()
                                          ? Image.file(
                                              File(profile.photoPath!),
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            )
                                          : _buildDefaultAvatar(
                                              context,
                                              profile.name,
                                            )))
                              : _buildDefaultAvatar(context, profile.name),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Height: ${profile.height.toStringAsFixed(0)} cm',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.textMedium,
                      ),
                    ),
                    if (profile.targetWeight != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Target: ${profile.targetWeight!.toStringAsFixed(1)} ${profile.weightUnit}',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.textMedium,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Journey Stats Strip
              const JourneyStatsStrip(),
              
              const SizedBox(height: 24),

              // Cloud Sync
              const _CloudSyncCard(),

              const TrophyRoomCard(),

              // Menu items
              _MenuCard(
                icon: Icons.edit_rounded,
                title: 'Edit Profile',
                subtitle: 'Name, height, target weight',
                onTap: () {
                  showAppBottomSheet(
                    context: context,
                    builder: (ctx) => const _EditProfileSheet(),
                  );
                },
              ),
              _MenuCard(
                icon: Icons.auto_awesome_rounded,
                title: 'AI Settings',
                subtitle: 'Coach name & Gemini API key',
                onTap: () => showAppBottomSheet(context: context, builder: (_) => const AiSetupSheet()),
              ),
              _MenuCard(
                icon: Icons.history_rounded,
                title: 'Recent AI Activity',
                subtitle: 'View local diagnostic logs',
                onTap: () => showAppBottomSheet(
                  context: context,
                  builder: (_) => const _AiActivitySheet(),
                ),
              ),
              _MenuCard(
                icon: Icons.fitness_center_rounded,
                title: 'Manage Plans',
                subtitle: 'Edit workout & meal JSON',
                onTap: () => context.go('/profile/manage-plans'),
              ),
              _MenuCard(
                icon: Icons.notifications_rounded,
                title: 'Reminders',
                subtitle: 'Daily habits, workouts, and backups',
                onTap: () => context.go('/profile/reminders'),
              ),
              _MenuCard(
                icon: Icons.swap_horiz_rounded,
                title: 'Unit Preference',
                subtitle:
                    'Currently: ${profile.useKg ? 'Kilograms (kg)' : 'Pounds (lb)'}',
                onTap: () {
                  ref.read(profileProvider.notifier).toggleUnit();
                },
              ),
              _MenuCard(
                icon: Icons.dark_mode_rounded,
                title: 'Theme',
                subtitle:
                    'Currently: ${_themeLabel(ref.watch(themeModeProvider))}',
                onTap: () => _showThemeDialog(context, ref),
              ),
              _SettingsSwitch(
                icon: Icons.volume_up_rounded,
                title: 'Rest Timer Sound',
                subtitle: 'Play alert sound when rest finishes',
                value: profile.restTimerSound,
                onChanged: (val) {
                  ref
                      .read(profileProvider.notifier)
                      .updateProfile(profile.copyWith(restTimerSound: val));
                },
              ),
              if (Platform.isAndroid)
                _SettingsSwitch(
                  icon: Icons.smartphone_rounded,
                  title: 'Screen Time Tracking',
                  subtitle: profile.screenTimeEnabled
                      ? 'Enabled (Tracks device screen time)'
                      : 'Disabled (Opt-in to track screen time)',
                  value: profile.screenTimeEnabled,
                  onChanged: (val) async {
                    if (val) {
                      // Attempt to enable
                      final hasPermission = await ref
                          .read(screenTimeServiceProvider)
                          .checkPermission();
                      if (hasPermission) {
                        // ignore: unawaited_futures
                        ref
                            .read(profileProvider.notifier)
                            .updateProfile(
                              profile.copyWith(screenTimeEnabled: true),
                            );
                      } else {
                        if (context.mounted) {
                          _showScreenTimePermissionDialog(
                            context,
                            ref,
                            profile,
                          );
                        }
                      }
                    } else {
                      // Disable
                      // ignore: unawaited_futures
                      ref
                          .read(profileProvider.notifier)
                          .updateProfile(
                            profile.copyWith(screenTimeEnabled: false),
                          );
                    }
                  },
                ),
              _SettingsSwitch(
                icon: Icons.vibration_rounded,
                title: 'Rest Timer Vibration',
                subtitle: 'Vibrate when rest finishes',
                value: profile.restTimerVibration,
                onChanged: (val) {
                  ref
                      .read(profileProvider.notifier)
                      .updateProfile(profile.copyWith(restTimerVibration: val));
                },
              ),
              _MenuCard(
                icon: Icons.backup_rounded,
                title: 'Backup & Restore',
                subtitle: 'Export or restore all data & photos',
                onTap: () {
                  context.go('/profile/backup-restore');
                },
              ),
              _MenuCard(
                icon: Icons.ios_share_rounded,
                title: 'Share Progress',
                subtitle: 'Generate a progress summary card',
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const SharePreviewSheet(),
                  );
                },
              ),
              _MenuCard(
                icon: Icons.table_chart_rounded,
                title: 'Export Data',
                subtitle: 'Download logs and stats as CSV',
                onTap: () => _showExportDataSheet(context, ref),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  _devTapCount++;
                  if (_devTapCount >= 7) {
                    _devTapCount = 0;
                    showAppBottomSheet(
                      context: context,
                      builder: (ctx) => const _SystemDiagnosticsSheet(),
                    );
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Made with ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colors.primary,
                          ),
                        ),
                        Icon(
                          Icons.eco_rounded,
                          size: 14,
                          color: context.colors.primary,
                        ),
                        Text(
                          ' for Bodamma',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (_appVersion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _appVersion,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.textLight.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showScreenTimePermissionDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic profile,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(
          'Enable Screen Time',
          style: TextStyle(color: context.colors.textDark),
        ),
        content: Text(
          'Sthira can read your daily screen time to help you build better habits. '
          'This requires "Usage Access" permission.\n\n'
          'Your screen time is only stored locally on this device, and will only be synced to your private cloud if Cloud Sync is enabled.',
          style: TextStyle(color: context.colors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colors.textLight),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(screenTimeServiceProvider).openSettings();
            },
            child: Text(
              'Open Settings',
              style: TextStyle(
                color: context.colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    showAppBottomSheet(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final current = ref.watch(themeModeProvider);
            final colors = context.colors;

            String label(ThemeMode mode) {
              switch (mode) {
                case ThemeMode.system:
                  return 'System';
                case ThemeMode.light:
                  return 'Light';
                case ThemeMode.dark:
                  return 'Dark';
              }
            }

            String subtitle(ThemeMode mode) {
              switch (mode) {
                case ThemeMode.system:
                  return 'Match phone settings';
                case ThemeMode.light:
                  return 'Always light';
                case ThemeMode.dark:
                  return 'Always dark';
              }
            }

            IconData icon(ThemeMode mode) {
              switch (mode) {
                case ThemeMode.system:
                  return Icons.brightness_auto_rounded;
                case ThemeMode.light:
                  return Icons.light_mode_rounded;
                case ThemeMode.dark:
                  return Icons.dark_mode_rounded;
              }
            }

            return AppSheet(
              title: 'Select Theme',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: ThemeMode.values.map((mode) {
                  final selected = current == mode;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      icon(mode),
                      color: selected ? colors.primary : colors.textMedium,
                    ),
                    title: Text(
                      label(mode),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colors.textDark,
                      ),
                    ),
                    subtitle: Text(
                      subtitle(mode),
                      style: TextStyle(color: colors.textMedium, fontSize: 13),
                    ),
                    trailing: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? colors.primary : colors.border,
                    ),
                    onTap: () async {
                      await ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(mode);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  void _showExportDataSheet(BuildContext context, WidgetRef ref) {
    showAppBottomSheet(
      context: context,
      builder: (sheetContext) => AppSheet(
        title: 'Export Data (CSV)',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExportOptionTile(
              title: 'Last 30 Days',
              onTap: () {
                // Sheet is on the root navigator; pop with sheet context.
                Navigator.of(sheetContext).pop();
                _handleExport(
                  context,
                  ref,
                  DateTime.now().subtract(const Duration(days: 30)),
                );
              },
            ),
            _ExportOptionTile(
              title: 'Last 90 Days',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(
                  context,
                  ref,
                  DateTime.now().subtract(const Duration(days: 90)),
                );
              },
            ),
            _ExportOptionTile(
              title: 'All Time',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleExport(context, ref, null);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport(
    BuildContext context,
    WidgetRef ref,
    DateTime? startDate,
  ) async {
    if (!context.mounted) return;

    // ignore: unawaited_futures
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final exportService = ref.read(csvExportServiceProvider);
      final zipPath = await exportService.exportData(startDate);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // hide loading

      if (zipPath != null) {
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(zipPath)], text: 'Sthira Data Export');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to export data or no data found'),
            backgroundColor: context.colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: $e'),
          backgroundColor: context.colors.red,
        ),
      );
    }
  }

  Widget _buildDefaultAvatar(BuildContext context, String name) {
    return Center(
      child: name.isNotEmpty
          ? Text(
              name[0].toUpperCase(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: context.colors.primary,
              ),
            )
          : Icon(Icons.person, size: 40, color: context.colors.primary),
    );
  }
}

class _CloudSyncCard extends ConsumerStatefulWidget {
  const _CloudSyncCard();

  @override
  ConsumerState<_CloudSyncCard> createState() => _CloudSyncCardState();
}

class _CloudSyncCardState extends ConsumerState<_CloudSyncCard> {
  bool _isSyncing = false;
  String _syncStatus = '';

  Future<void> _handleSignIn() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Signing in...';
    });
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      if (user != null && mounted) {
        // Run initial sync/migration
        setState(() {
          _syncStatus = 'Syncing data...';
        });
        await _runFullSync();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Successfully signed in & synced!'),
              backgroundColor: context.colors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            backgroundColor: context.colors.red,
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _isSyncing = false;
          _syncStatus = '';
        });
    }
  }

  Future<void> _runFullSync() async {
    final syncService = ref.read(firestoreSyncServiceProvider);

    // 1. Check if cloud has data
    final hasCloudData = await syncService.hasCloudData();

    if (hasCloudData) {
      // Pull down to device
      final profile = await syncService.pullProfile();
      await ref.read(profileRepoProvider).importProfileFromCloud(profile);

      final dailyLogs = await syncService.pullCollection('daily_logs');
      await ref.read(dailyLogRepoProvider).importFromCloud(dailyLogs);

      final mealLogs = await syncService.pullCollection('meal_logs');
      await ref.read(mealRepoProvider).importLogsFromCloud(mealLogs);

      final stats = await syncService.pullCollection('body_stats');
      await ref.read(bodyStatsRepoProvider).importStatsFromCloud(stats);

      final workoutPlans = await syncService.pullCollection('workout_plans');
      await ref.read(workoutRepoProvider).importPlansFromCloud(workoutPlans);

      final mealPlans = await syncService.pullCollection('meal_plans');
      await ref.read(mealRepoProvider).importPlansFromCloud(mealPlans);

      // refresh UI
      ref.invalidate(profileProvider);
      ref.invalidate(dailyLogProvider);
      ref.invalidate(dailyMealLogProvider);
      ref.invalidate(latestBodyStatsProvider);
    } else {
      // First time cloud user: upload local data
      syncService.syncProfile(
        ref.read(profileRepoProvider).exportProfileForCloud(),
      );

      await syncService.bulkSync(
        'daily_logs',
        ref.read(dailyLogRepoProvider).exportForCloud(),
      );
      await syncService.bulkSync(
        'meal_logs',
        ref.read(mealRepoProvider).exportLogsForCloud(),
      );
      await syncService.bulkSync(
        'body_stats',
        ref.read(bodyStatsRepoProvider).exportStatsForCloud(),
      );
      await syncService.bulkSync(
        'habit_config',
        ref.read(habitRepoProvider).exportConfigForCloud(),
      );
      await syncService.bulkSync(
        'habit_completions',
        ref.read(habitRepoProvider).exportCompletionsForCloud(),
      );
      await syncService.bulkSync(
        'workout_plans',
        ref.read(workoutRepoProvider).exportPlansForCloud(),
      );
      await syncService.bulkSync(
        'meal_plans',
        ref.read(mealRepoProvider).exportPlansForCloud(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final userEmail = ref.watch(userEmailProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_rounded, color: context.colors.primary),
              const SizedBox(width: 8),
              Text(
                'Cloud Sync',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textDark,
                ),
              ),
              const Spacer(),
              if (isSignedIn)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isSignedIn
                ? 'Your text data is securely synced as $userEmail. Photos are NOT cloud-synced. Use ZIP backup to move media.'
                : 'Sign in to sync your text data across devices. Photos are NOT cloud-synced.',
            style: TextStyle(color: context.colors.textMedium, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_isSyncing)
            Center(
              child: Column(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _syncStatus,
                    style: TextStyle(
                      color: context.colors.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else if (!isSignedIn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      setState(() {
                        _isSyncing = true;
                        _syncStatus = 'Syncing...';
                      });
                      await _runFullSync();
                      setState(() {
                        _isSyncing = false;
                        _syncStatus = '';
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.primary,
                      side: BorderSide(
                        color: context.colors.primary.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Now'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: context.colors.card,
                        title: Text(
                          'Sign Out',
                          style: TextStyle(color: context.colors.textDark),
                        ),
                        content: Text(
                          'Are you sure you want to sign out?',
                          style: TextStyle(color: context.colors.textMedium),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: context.colors.textLight),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              'Sign Out',
                              style: TextStyle(
                                color: context.colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(authServiceProvider).signOut();
                    }
                  },
                  tooltip: 'Sign out',
                  icon: Icon(Icons.logout, color: context.colors.red),
                  style: IconButton.styleFrom(
                    backgroundColor: context.colors.red.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _ExportOptionTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(
        title,
        style: TextStyle(
          color: context.colors.textDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.colors.textMedium,
      ),
      onTap: onTap,
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: context.colors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textLight),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(kCardRadius),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: context.colors.primary,
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: context.colors.primary, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: context.colors.textMedium),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kCardRadius),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late TextEditingController nameController;
  late TextEditingController coachNameController;
  late TextEditingController heightController;
  late TextEditingController targetController;
  late TextEditingController caloriesController;
  late TextEditingController proteinController;
  late TextEditingController carbsController;
  late TextEditingController fatController;

  String? _localPhotoPath;
  bool _clearPhoto = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    nameController = TextEditingController(text: profile.name);
    coachNameController = TextEditingController(text: profile.coachName);
    heightController = TextEditingController(
      text: profile.height.toStringAsFixed(0),
    );
    targetController = TextEditingController(
      text: profile.targetWeight?.toStringAsFixed(1) ?? '',
    );
    caloriesController = TextEditingController(
      text: profile.targetCalories.toString(),
    );
    proteinController = TextEditingController(
      text: profile.targetProteinG.toString(),
    );
    carbsController = TextEditingController(
      text: profile.targetCarbsG.toString(),
    );
    fatController = TextEditingController(text: profile.targetFatG.toString());
    _localPhotoPath = profile.photoPath;
  }

  @override
  void dispose() {
    nameController.dispose();
    coachNameController.dispose();
    heightController.dispose();
    targetController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            // ignore: use_build_context_synchronously
            toolbarColor: context.colors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'profile_pic_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(
          croppedFile.path,
        ).copy('${appDir.path}/$fileName');

        setState(() {
          _localPhotoPath = savedImage.path;
          _clearPhoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: context.colors.red,
          ),
        );
      }
    }
  }

  void _showPickerOptions() {
    showAppBottomSheet(
      context: context,
      builder: (ctx) => AppSheet(
        title: 'Profile Photo',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.camera_alt, color: context.colors.primary),
              title: const Text('Take a picture'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.photo_library, color: context.colors.primary),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.pets, color: context.colors.primary),
              title: const Text('Choose preset avatar'),
              onTap: () async {
                Navigator.pop(ctx);
                final selectedAvatar = await AvatarPickerSheet.show(context);
                if (selectedAvatar != null) {
                  setState(() {
                    _localPhotoPath = selectedAvatar;
                    _clearPhoto = false;
                  });
                }
              },
            ),
            if (_localPhotoPath != null && !_clearPhoto)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete, color: context.colors.red),
                title: Text(
                  'Remove photo',
                  style: TextStyle(color: context.colors.red),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() {
                    _localPhotoPath = null;
                    _clearPhoto = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return AppSheet(
      title: 'Edit Profile',
      scrollable: true,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _showPickerOptions,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.lavenderCard,
                      ),
                      child: ClipOval(
                        child: _localPhotoPath != null && !_clearPhoto
                            ? (_localPhotoPath!.startsWith('assets/')
                                  ? Image.asset(
                                      _localPhotoPath!,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_localPhotoPath!),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ))
                            : Center(
                                child: nameController.text.isNotEmpty
                                    ? Text(
                                        nameController.text[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w800,
                                          color: context.colors.primary,
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 40,
                                        color: context.colors.primary,
                                      ),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: context.colors.onPrimary,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _ProfileTextField(
              label: 'Name',
              controller: nameController,
              prefixIcon: Icons.person_rounded,
              onChanged: (v) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _ProfileTextField(
              label: 'Coach name',
              controller: coachNameController,
              prefixIcon: Icons.sports_rounded,
            ),
            const SizedBox(height: 16),
            _ProfileTextField(
              label: 'Height (cm)',
              controller: heightController,
              prefixIcon: Icons.height_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _ProfileTextField(
              label: 'Target Weight (kg)',
              controller: targetController,
              prefixIcon: Icons.flag_rounded,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            _ProfileTextField(
              label: 'Target Daily Calories',
              controller: caloriesController,
              prefixIcon: Icons.restaurant_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Text(
              'Daily macros (g)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textMedium,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ProfileTextField(
                    label: 'Protein',
                    controller: proteinController,
                    prefixIcon: Icons.fitness_center_rounded,
                    keyboardType: TextInputType.number,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ProfileTextField(
                    label: 'Carbs',
                    controller: carbsController,
                    prefixIcon: Icons.breakfast_dining_rounded,
                    keyboardType: TextInputType.number,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ProfileTextField(
                    label: 'Fat',
                    controller: fatController,
                    prefixIcon: Icons.water_drop_rounded,
                    keyboardType: TextInputType.number,
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Save',
              onPressed: () {
                final updated = profile.copyWith(
                  name: nameController.text,
                  coachName: coachNameController.text.trim(),
                  height:
                      double.tryParse(heightController.text) ?? profile.height,
                  targetWeight: double.tryParse(targetController.text),
                  targetCalories:
                      int.tryParse(caloriesController.text) ??
                      profile.targetCalories,
                  targetProteinG:
                      int.tryParse(proteinController.text) ??
                      profile.targetProteinG,
                  targetCarbsG:
                      int.tryParse(carbsController.text) ??
                      profile.targetCarbsG,
                  targetFatG:
                      int.tryParse(fatController.text) ?? profile.targetFatG,
                  photoPath: _localPhotoPath,
                  clearPhoto: _clearPhoto,
                );
                if (_clearPhoto &&
                    profile.photoPath != null &&
                    !profile.photoPath!.startsWith('assets/')) {
                  final f = File(profile.photoPath!);
                  if (f.existsSync()) f.deleteSync();
                }

                ref.read(profileProvider.notifier).updateProfile(updated);
                Navigator.of(context).pop();
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.label,
    required this.controller,
    required this.prefixIcon,
    this.keyboardType,
    this.onChanged,
    this.compact = false,
  });

  final String label;
  final TextEditingController controller;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textMedium,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: context.colors.textDark,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.colors.inputFill,
            prefixIcon: Icon(
              prefixIcon,
              size: compact ? 18 : 22,
              color: context.colors.primary,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 14 : 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _AiActivitySheet extends StatelessWidget {
  const _AiActivitySheet();
  @override
  Widget build(BuildContext context) {
    if (AiLogger.logs.isEmpty) {
      return AppSheet(
        title: 'Recent AI Activity',
        scrollable: true,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No AI requests made yet.')),
        ),
      );
    }
    return AppSheet(
      title: 'Recent AI Activity',
      scrollable: true,
      child: Column(
        children: AiLogger.logs
            .map(
              (log) => ListTile(
                title: Text(
                  '${log.purpose} • ${log.model}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                subtitle: Text(
                  'Outcome: ${log.outcome}\n${log.timestamp.toString().substring(11, 16)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '${log.durationMs} ms',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DiagnosticsTestSheet extends StatefulWidget {
  final WidgetRef ref;
  const _DiagnosticsTestSheet({required this.ref});
  @override
  State<_DiagnosticsTestSheet> createState() => _DiagnosticsTestSheetState();
}

class _DiagnosticsTestSheetState extends State<_DiagnosticsTestSheet> {
  final Map<String, Map<String, dynamic>> _results = {};
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() => _isTesting = true);
    final allModels = {
      ...AiClient.textModelsToTry,
      ...AiClient.visionModelsToTry,
    }.toList();
    final client = AiClient();
    final profile = widget.ref.read(profileProvider);

    for (final model in allModels) {
      if (!mounted) break;
      final sw = Stopwatch()..start();
      try {
        await client.generateJson(
          prompt: '{"test":"Respond with exactly {\"status\":\"ok\"}"}',
          systemInstruction: 'Respond only in valid JSON.',
          apiKey: profile.geminiApiKey,
          skipCache: true,
        );
        sw.stop();
        if (mounted)
          setState(() {
            _results[model] = {
              'status': '✓',
              'latency': sw.elapsedMilliseconds,
              'error': null,
            };
          });
      } catch (e) {
        sw.stop();
        final cause = (e is AiException) ? (e as AiException).cause : null;
        if (mounted)
          setState(() {
            _results[model] = {
              'status': '✗',
              'latency': sw.elapsedMilliseconds,
              'error': cause?.toString() ?? e.toString(),
            };
          });
      }
    }
    if (mounted) setState(() => _isTesting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'AI Connection Test',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isTesting) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          ..._results.entries
              .map(
                (e) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Text(
                        e.value['status'],
                        style: TextStyle(
                          color: e.value['status'] == '✓'
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (e.value['error'] != null)
                              Text(
                                e.value['error'],
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text('${e.value['latency']} ms'),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}

class _SystemDiagnosticsSheet extends ConsumerWidget {
  const _SystemDiagnosticsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.watch(diagnosticLoggerProvider);
    final logs = logger.getLogs();

    return AppSheet(
      title: 'System Diagnostics',
      scrollable: true,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${logs.length} logs in ring buffer',
                  style: TextStyle(color: context.colors.textMedium),
                ),
                TextButton.icon(
                  onPressed: () {
                    logger.clear();
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('No diagnostic logs.')),
            )
          else
            ...logs.map((log) => _buildLogRow(context, log)),
        ],
      ),
    );
  }

  Widget _buildLogRow(BuildContext context, DiagnosticLog log) {
    Color lvlColor;
    switch (log.level) {
      case 'ERROR':
        lvlColor = context.colors.red;
        break;
      case 'WARN':
        lvlColor = context.colors.orange;
        break;
      default:
        lvlColor = context.colors.green;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: lvlColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.level,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: lvlColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.timestamp.toString().substring(0, 19),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textLight,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            log.message,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textDark,
            ),
          ),
          if (log.error != null) ...[
            const SizedBox(height: 4),
            Text(
              log.error!,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.red,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
