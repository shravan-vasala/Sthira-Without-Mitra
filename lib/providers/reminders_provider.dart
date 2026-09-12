import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder_config.dart';
import '../services/notification_service.dart';
import 'app_providers.dart';

class RemindersNotifier extends Notifier<ReminderConfig> {
  late SharedPreferences _prefs;
  late NotificationService _notificationService;

  static final _key = 'reminder_config';

  @override
  ReminderConfig build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    _notificationService = ref.watch(notificationServiceProvider);

    // Listen to workout and photo changes to automatically reschedule
    ref.listen(workoutPlanProvider, (prev, next) {
      if (state.workoutsEnabled) {
        _queueSync();
      }
    });

    ref.listen(progressPhotosStreamProvider, (prev, next) {
      if (state.photosEnabled) {
        _queueSync();
      }
    });

    final jsonStr = _prefs.getString(_key);
    if (jsonStr != null) {
      return ReminderConfig.fromJson(jsonStr);
    }
    return ReminderConfig();
  }

  bool _isSyncing = false;
  bool _needsSync = false;

  Future<void> _queueSync() async {
    if (_isSyncing) {
      _needsSync = true;
      return;
    }
    _isSyncing = true;
    try {
      do {
        _needsSync = false;
        await _syncNotifications();
      } while (_needsSync);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> updateConfig(ReminderConfig newConfig) async {
    state = newConfig;
    await _prefs.setString(_key, newConfig.toJson());
    await _queueSync();
  }

  Future<void> _syncNotifications() async {
    // Request permission if enabling anything
    if (state.habitsEnabled ||
        state.workoutsEnabled ||
        state.mealsEnabled ||
        state.backupEnabled ||
        state.photosEnabled) {
      final granted = await _notificationService.requestPermissions();
      if (!granted) {
        // Fallback: If not granted, immediately revert the toggles in state
        final reverted = state.copyWith(
          habitsEnabled: false,
          workoutsEnabled: false,
          mealsEnabled: false,
          backupEnabled: false,
          photosEnabled: false,
        );
        state = reverted;
        await _prefs.setString(_key, reverted.toJson());
        await _notificationService.cancelAllReminders();
        return;
      }
    }

    await _notificationService.cancelAllReminders();

    if (state.habitsEnabled) {
      await _notificationService.scheduleHabitReminder(state.habitTime);
    }

    if (state.workoutsEnabled) {
      final workoutPlan = ref.read(workoutPlanProvider);
      if (workoutPlan != null) {
        // Convert active days to list of ints (1=Monday, 7=Sunday)
        // workoutPlan.days has items. Index 0 is Monday (usually)
        final List<int> activeDays = [];
        for (final day in workoutPlan.days) {
          if (day.sections.isNotEmpty && day.dayId != 'Rest') {
            final wday = day.weekday;
            if (wday != null) activeDays.add(wday);
          }
        }
        if (activeDays.isNotEmpty) {
          await _notificationService.scheduleWorkoutReminders(
            activeDays,
            state.workoutTime,
          );
        }
      }
    }

    if (state.mealsEnabled) {
      await _notificationService.scheduleMealReminders(
        state.lunchTime,
        state.dinnerTime,
      );
    }

    if (state.backupEnabled) {
      await _notificationService.scheduleBackupReminder(
        state.backupDayOfWeek,
        state.backupTime,
      );
    }

    if (state.photosEnabled) {
      final mediaRepo = ref.read(mediaRepoProvider);
      final allPhotos = mediaRepo.getAllProgressPhotosDetailed();
      DateTime? lastPhotoDate;
      if (allPhotos.isNotEmpty) {
        // Since getAllProgressPhotos() sorts descending, the first one might be the latest.
        // Wait, getAllProgressPhotosDetailed() relies on getAllProgressPhotos() which is sorted by date descending.
        // So the first element should be the latest date.
        try {
          lastPhotoDate = DateTime.parse(allPhotos.first.date);
        } catch (_) {}
      }
      await _notificationService.schedulePhotoReminder(
        state.photoTime,
        lastPhotoDate,
      );
    }
  }

  // Called on app boot from main.dart
  Future<void> initializeNotifications() async {
    await _queueSync();
  }
}

final remindersProvider = NotifierProvider<RemindersNotifier, ReminderConfig>(
  () {
    return RemindersNotifier();
  },
);
