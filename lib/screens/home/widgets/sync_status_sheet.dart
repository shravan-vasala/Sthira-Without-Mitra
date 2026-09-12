import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/app_providers.dart';
import '../../../services/health_connect_service.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../steps_entry_dialog.dart';
import '../../../widgets/async_error_card.dart';

class SyncStatusSheet extends ConsumerStatefulWidget {
  const SyncStatusSheet({super.key});

  @override
  ConsumerState<SyncStatusSheet> createState() => _SyncStatusSheetState();
}

class _SyncStatusSheetState extends ConsumerState<SyncStatusSheet> {
  String? _errorMessage;
  String? _errorAction;

  bool _checking = true;
  bool _authorized = false;
  bool _isAvailable = false;
  String? _lastAttempt;
  String? _lastSuccess;
  bool _backfillDone = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final hcService = ref.read(healthConnectServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    final avail = await hcService.isAvailable();
    final auth = await hcService.isAuthorized();
    final attemptStr = prefs.getString('last_hc_sync_attempt');
    final successStr = prefs.getString('last_hc_sync_time');

    if (mounted) {
      setState(() {
        _isAvailable = avail;
        _authorized = auth;
        _lastAttempt = attemptStr;
        _lastSuccess = successStr;
        _backfillDone = hcService.isBackfillDone;
        _checking = false;
      });
    }
  }

  String _formatTime(String? isoStr) {
    if (isoStr == null) return 'Never';
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyLog = ref.watch(dailyLogProvider);
    final steps = dailyLog.steps ?? 0;
    final source = ref.watch(stepsSourceProvider);
    final pendingCount = ref.watch(syncPendingCountProvider).value ?? 0;

    String sourceText = 'Unknown';
    if (source == StepsSource.healthConnect) {
      sourceText = 'Health Connect';
    } else if (source == StepsSource.manual) {
      sourceText = 'Manual Entry';
    } else {
      sourceText = 'None';
    }

    return AppSheet(
      title: 'Sync Status',
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pendingCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: context.colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_upload_rounded,
                    color: context.colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$pendingCount items pending cloud sync',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Total Steps display
          Center(
            child: Column(
              children: [
                Text(
                  '$steps',
                  style: AppTheme.numeric.copyWith(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: context.colors.primary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Steps Today',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Diagnostics
          Text(
            'Diagnostics',
            style: TextStyle(
              fontFamily: 'Cabinet Grotesk',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_checking)
             const Center(
               child: Padding(
                 padding: EdgeInsets.all(24),
                 child: CircularProgressIndicator(),
               ),
             )
          else ...[
            _DiagnosticRow(label: 'Source', value: sourceText),
            _DiagnosticRow(label: 'Permissions', value: _isAvailable ? (_authorized ? 'Granted' : 'Missing/Denied') : 'Unavailable'),
            _DiagnosticRow(label: 'Last Successful Read', value: _formatTime(_lastSuccess)),
            _DiagnosticRow(label: 'Last Attempted Read', value: _formatTime(_lastAttempt)),
            _DiagnosticRow(label: '90-Day Backfill', value: _backfillDone ? 'Complete' : 'Pending'),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 24),
            AsyncErrorCard(
              title: 'Sync Failed',
              message: _errorMessage!,
              actionText: _errorAction,
              onRetry: _errorAction != null
                  ? () async {
                      final hcService = ref.read(healthConnectServiceProvider);
                      if (_errorAction == 'Install Health Connect') {
                        setState(
                          () => _errorMessage = 'Please install Health Connect from the Play Store.',
                        );
                      } else if (_errorAction == 'Grant Permission') {
                        await hcService.requestPermission();
                        await _loadStatus();
                        if (mounted) setState(() => _errorMessage = null);
                      }
                    }
                  : null,
            ),
          ],
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                setState(() => _errorMessage = null);
                final hcService = ref.read(healthConnectServiceProvider);
                final dailyLogRepo = ref.read(dailyLogRepoProvider);
                final habitRepo = ref.read(habitRepoProvider);
                final prefs = ref.read(sharedPreferencesProvider);

                try {
                  final isAvail = await hcService.isAvailable();
                  if (!isAvail) {
                    setState(() {
                      _errorMessage = 'Health Connect is not available on this device.';
                      _errorAction = 'Install Health Connect';
                    });
                    return;
                  }
                  
                  await prefs.setString(
                    'last_hc_sync_attempt',
                    DateTime.now().toIso8601String(),
                  );

                  var canSync = await hcService.isAuthorized();
                  if (!canSync) {
                    canSync = await hcService.canReadSteps();
                  }

                  if (!canSync) {
                    setState(() {
                      _errorMessage = 'Missing permissions to read steps.';
                      _errorAction = 'Grant Permission';
                    });
                    await _loadStatus();
                    return;
                  }

                  final todayData = await hcService.syncToday();
                  final steps = todayData?.steps;
                  if (todayData != null) await dailyLogRepo.updateFromHealthConnect([todayData]);
                  if (steps != null) {
                    await prefs.setBool('hc_connected', true);
                    await prefs.setString(
                      'last_hc_sync_time',
                      DateTime.now().toIso8601String(),
                    );
                    ref.read(stepsSourceProvider.notifier).state = StepsSource.healthConnect;
                  }

                  ref.invalidate(dailyLogProvider);
                  ref.invalidate(habitCompletionsProvider);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (e) {
                  setState(() {
                    _errorMessage = 'An unexpected error occurred during sync.';
                    _errorAction = null;
                  });
                  await _loadStatus();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Refresh Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.colors.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                showAppBottomSheet(
                  context: context,
                  builder: (_) => const StepsEntryDialog(),
                );
              },
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Log Manually Instead',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.colors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  final String label;
  final String value;

  const _DiagnosticRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.textMedium,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
