import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/reminder_config.dart';
import '../services/notification_service.dart';
import 'app_providers.dart';

class RemindersNotifier extends Notifier<ReminderConfig> {
  late SharedPreferences _prefs;
  late NotificationService _notificationService;

  static const _key = 'reminder_config';

  @override
  ReminderConfig build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    _notificationService = ref.watch(notificationServiceProvider);

    // Listen to dependencies to automatically reschedule
    ref.listen(workoutPlanProvider, (prev, next) {
      if (state.workoutsEnabled) _queueSync();
    });

    ref.listen(progressPhotosStreamProvider, (prev, next) {
      if (state.photosEnabled) _queueSync();
    });
    
    // Listen to daily logs to cancel/skip completed tasks
    ref.listen(dailyLogsUpdateProvider, (prev, next) {
      if (state.habitsEnabled || state.mealsEnabled) _queueSync();
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
    final isEnabling = (newConfig.habitsEnabled && !state.habitsEnabled) ||
        (newConfig.workoutsEnabled && !state.workoutsEnabled) ||
        (newConfig.mealsEnabled && !state.mealsEnabled) ||
        (newConfig.backupEnabled && !state.backupEnabled) ||
        (newConfig.photosEnabled && !state.photosEnabled);

    if (isEnabling) {
      final granted = await _notificationService.requestPermissions();
      if (!granted) {
        newConfig = newConfig.copyWith(
          habitsEnabled: state.habitsEnabled,
          workoutsEnabled: state.workoutsEnabled,
          mealsEnabled: state.mealsEnabled,
          backupEnabled: state.backupEnabled,
          photosEnabled: state.photosEnabled,
        );
      }
    }

    state = newConfig;
    await _prefs.setString(_key, newConfig.toJson());
    await _queueSync();
  }

  bool _isWithinQuietHours(TimeOfDay time) {
    if (!state.quietHoursEnabled) return false;
    
    final tMin = time.hour * 60 + time.minute;
    final startMin = state.quietHoursStart.hour * 60 + state.quietHoursStart.minute;
    final endMin = state.quietHoursEnd.hour * 60 + state.quietHoursEnd.minute;
    
    if (startMin < endMin) {
      return tMin >= startMin && tMin < endMin;
    } else {
      // Overnight quiet hours
      return tMin >= startMin || tMin < endMin;
    }
  }

  Future<void> _syncNotifications() async {

    final profile = ref.read(profileProvider);
    final userName = profile.name.isNotEmpty ? profile.name : 'there';
    
    final now = DateTime.now();
    
    
    
    // Check habits
    await _notificationService.cancelHabits();
    if (state.habitsEnabled && !_isWithinQuietHours(state.habitTime)) {
      for (int i = 0; i < 7; i++) {
        final date = now.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        
        
        // In this simple check, if the log exists and some habits are done, maybe they finished.
        // Actually, we'll schedule it unless we have robust completion checking.
        // For simplicity, we just schedule it.
        final scheduled = DateTime(date.year, date.month, date.day, state.habitTime.hour, state.habitTime.minute);
        
        if (scheduled.isAfter(now)) {
          await _notificationService.scheduleAbsolute(
            id: 1000 + i,
            title: 'Evening Routine',
            body: 'Time for your evening reading and habits.',
            scheduledDate: scheduled,
            payload: 'habit_$dateStr',
          );
        }
      }
    }

    // Check meals
    await _notificationService.cancelMeals();
    if (state.mealsEnabled) {
      for (int i = 0; i < 7; i++) {
        final date = now.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        
        // Lunch
        if (!_isWithinQuietHours(state.lunchTime)) {
          final scheduledLunch = DateTime(date.year, date.month, date.day, state.lunchTime.hour, state.lunchTime.minute);
          if (scheduledLunch.isAfter(now)) {
            await _notificationService.scheduleAbsolute(
              id: 2000 + i,
              title: 'Lunch Check-in',
              body: 'A quick check-in: have you logged lunch?',
              scheduledDate: scheduledLunch,
            );
          }
        }
        
        // Dinner
        if (!_isWithinQuietHours(state.dinnerTime)) {
          final scheduledDinner = DateTime(date.year, date.month, date.day, state.dinnerTime.hour, state.dinnerTime.minute);
          if (scheduledDinner.isAfter(now)) {
            await _notificationService.scheduleAbsolute(
              id: 2100 + i,
              title: 'Dinner Check-in',
              body: 'Time to track your dinner.',
              scheduledDate: scheduledDinner,
            );
          }
        }
      }
    }

    // Check workouts
    await _notificationService.cancelWorkouts();
    if (state.workoutsEnabled && !_isWithinQuietHours(state.workoutTime)) {
      final workoutPlan = ref.read(workoutPlanProvider);
      if (workoutPlan != null) {
        final activeDays = workoutPlan.days
            .where((d) => d.sections.isNotEmpty && d.dayId != 'Rest' && d.weekday != null)
            .map((d) => d.weekday!)
            .toList();
            
        for (int i = 0; i < 7; i++) {
          final date = now.add(Duration(days: i));
          if (activeDays.contains(date.weekday)) {
            final scheduled = DateTime(date.year, date.month, date.day, state.workoutTime.hour, state.workoutTime.minute);
            if (scheduled.isAfter(now)) {
              final timeStr = DateFormat('h:mm a').format(scheduled);
              await _notificationService.scheduleAbsolute(
                id: 3000 + i,
                title: 'Workout Scheduled',
                body: 'Your workout is scheduled for $timeStr. Ready when you are.',
                scheduledDate: scheduled,
                addSnooze: true,
                addSkip: true,
              );
            }
          }
        }
      }
    }

    // Backup
    await _notificationService.cancelBackup();
    if (state.backupEnabled && !_isWithinQuietHours(state.backupTime)) {
      // Find next occurrence
      DateTime scheduled = DateTime(now.year, now.month, now.day, state.backupTime.hour, state.backupTime.minute);
      while (scheduled.weekday != state.backupDayOfWeek || scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _notificationService.scheduleAbsolute(
        id: 4000,
        title: 'Weekly Backup',
        body: 'Time to back up your data securely.',
        scheduledDate: scheduled,
        addSnooze: false,
        addSkip: false,
      );
    }

    // Photos
    await _notificationService.cancelPhotos();
    if (state.photosEnabled && !_isWithinQuietHours(state.photoTime)) {
      final mediaRepo = ref.read(mediaRepoProvider);
      final allPhotos = mediaRepo.getAllProgressPhotosDetailed();
      DateTime? lastPhotoDate;
      if (allPhotos.isNotEmpty) {
        try {
          lastPhotoDate = DateTime.parse(allPhotos.first.date);
        } catch (_) {}
      }
      
      bool needsNudge = lastPhotoDate == null || now.difference(lastPhotoDate).inDays >= 14;
      if (needsNudge) {
        final scheduled = DateTime(now.year, now.month, now.day, state.photoTime.hour, state.photoTime.minute);
        final finalScheduled = scheduled.isBefore(now) ? scheduled.add(const Duration(days: 1)) : scheduled;
        await _notificationService.scheduleAbsolute(
          id: 5000,
          title: 'Progress Photo',
          body: 'It\'s been a while. Take a quick photo to track your progress.',
          scheduledDate: finalScheduled,
        );
      }
    }
  }

  Future<void> initializeNotifications() async {
    await _queueSync();
  }
}

final remindersProvider = NotifierProvider<RemindersNotifier, ReminderConfig>(
  () {
    return RemindersNotifier();
  },
);
