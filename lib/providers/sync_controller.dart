import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart';

import '../models/daily_log.dart';
import '../services/screen_time_service.dart';
import 'auth_provider.dart';
import '../services/health_connect_service.dart';
import '../utils/time_utils.dart';

final syncControllerProvider = NotifierProvider<SyncController, bool>(
  SyncController.new,
);

class SyncController extends Notifier<bool> with WidgetsBindingObserver {
  bool _isSyncing = false;

  @override
  bool build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
    });
    return false; // state represents whether we are currently syncing
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      sync(isManualRefresh: false);
    } else if (state == AppLifecycleState.paused) {
      // Flush any pending Widget state when going to background

      // Also flush firestore queue if available (Task 4)
      ref.read(firestoreSyncServiceProvider).flushNow();
    }
  }

  Future<void> sync({bool isManualRefresh = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    state = true;

    try {
      final hcService = ref.read(healthConnectServiceProvider);
      final dailyLogRepo = ref.read(dailyLogRepoProvider);
      final habitRepo = ref.read(habitRepoProvider);
      final prefs = ref.read(sharedPreferencesProvider);

      // Coach note is date-scoped — only auto-refresh when viewing today
      final selectedDate = ref.read(dateStringProvider);
      final todayStr = todayKey();
      if (selectedDate == todayStr) {
        // ignore: unawaited_futures
        ref.read(coachNoteProvider.notifier).fetchNote(force: isManualRefresh);
      }

      // Sync Screen Time
      if (ref.read(profileProvider).screenTimeEnabled) {
        final currentUid = ref.read(authServiceProvider).uid;
        
        final screenTimeResult = await ref
            .read(screenTimeServiceProvider)
            .getScreenTimeForToday();
            
        // Check cancellation/ownership pre-write
        if (currentUid != null && currentUid == ref.read(authServiceProvider).uid) {
          if (screenTimeResult.status == 'success' && 
              screenTimeResult.measuredDate != null && 
              screenTimeResult.minutes != null) {
                
            // Discard overlapping local-drift; Use authoritative native boundaries
            await dailyLogRepo.updateScreenTime(
                screenTimeResult.measuredDate!, 
                screenTimeResult.minutes!,
            );
          }
        }
      }

      final available = await hcService.isAvailable();
      if (available) {
        final now = DateTime.now();
        final lastSyncStr = prefs.getString('last_hc_sync_time');
        final lastSync = lastSyncStr != null
            ? DateTime.tryParse(lastSyncStr)
            : null;
        final everConnected = prefs.getBool('hc_connected') ?? false;

        final todayData = await hcService.syncToday();
        final todaySteps = todayData?.steps;

        if (todayData != null) {
          await dailyLogRepo.updateFromHealthConnect([todayData]);
          await prefs.setBool('hc_connected', true);
          ref.read(stepsSourceProvider.notifier).state =
              StepsSource.healthConnect;
        }

        if (todaySteps != null || everConnected) {
          // Heavier historical sync — manual pull or every 15 minutes
          final shouldFullSync =
              isManualRefresh ||
              lastSync == null ||
              now.difference(lastSync).inMinutes >= 15;

          if (shouldFullSync) {
            final last7 = await hcService.syncLast7Days();
            if (last7.isNotEmpty) {
              await dailyLogRepo.updateFromHealthConnect(last7);
            }
            if (!hcService.isBackfillDone) {
              final backfill = await hcService.backfillLast90Days();
              if (backfill.isNotEmpty) {
                await dailyLogRepo.updateFromHealthConnect(backfill);
              }
            }
            await prefs.setString('last_hc_sync_time', now.toIso8601String());
          }
        }
      }

      // Batched invalidation at the end
      ref.invalidate(dailyLogProvider);
      ref.invalidate(habitCompletionsProvider);

      // Update widget with new sync data
    } finally {
      _isSyncing = false;
      state = false;
    }
  }
}
