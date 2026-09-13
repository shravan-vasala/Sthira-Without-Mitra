import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/reminder_config.dart';
import '../models/habit.dart';
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
      if (state.workoutsEnabled) queueSync();
    });

    ref.listen(progressPhotosStreamProvider, (prev, next) {
      if (state.photosEnabled) queueSync();
    });
    
    // Listen to daily logs to cancel/skip completed tasks
    ref.listen(dailyLogsUpdateProvider, (prev, next) {
      if (state.habitsEnabled || state.mealsEnabled) queueSync();
    });

    final jsonStr = _prefs.getString(_key);
    if (jsonStr != null) {
      return ReminderConfig.fromJson(jsonStr);
    }
    return ReminderConfig();
  }

  bool _isSyncing = false;
  bool _needsSync = false;

  Future<void> queueSync() async {
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
    await queueSync();
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

  String _buildPayload(String type, String dateStr) {
    return jsonEncode({'v': 1, 'type': type, 'date': dateStr});
  }

  DateTime _applySnooze(DateTime scheduled, String payload) {
    final snoozes = _prefs.getInt('snoozeCount_$payload') ?? 0;
    if (snoozes > 0) {
      // Add 60 mins per snooze. Cap at 3 snoozes to prevent pushing it past midnight blindly.
      final cappedSnoozes = snoozes > 3 ? 3 : snoozes;
      var newScheduled = scheduled.add(Duration(minutes: 60 * cappedSnoozes));
      // Walk past quiet hours if necessary
      while (_isWithinQuietHours(TimeOfDay.fromDateTime(newScheduled))) {
        newScheduled = newScheduled.add(const Duration(minutes: 30));
      }
      return newScheduled;
    }
    return scheduled;
  }

  bool _isSkipped(String payload) {
    final skips = _prefs.getStringList('skipped_reminders') ?? [];
    return skips.contains(payload);
  }

  Future<void> _syncNotifications() async {

    final profile = ref.read(profileProvider);
    final userName = profile.name.isNotEmpty ? profile.name : 'there';
    
    final now = DateTime.now();
    
    final dailyLogRepo = ref.read(dailyLogRepoProvider);
    final habitRepo = ref.read(habitRepoProvider);
    final mealRepo = ref.read(mealRepoProvider);
    
    // Check habits
    await _notificationService.cancelHabits();
    if (state.habitsEnabled && !_isWithinQuietHours(state.habitTime)) {
      final activeHabits = habitRepo.getHabits().length;
      
      for (int i = 0; i < 7; i++) {
        final date = now.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final payload = _buildPayload('habit', dateStr);
        
        if (_isSkipped(payload)) continue;

        // Skip if habits are done
        bool allDone = false;
        if (activeHabits > 0) {
           final completions = habitRepo.getCompletions(dateStr);
           final completedCount = completions.completions.values.where((v) => v == true || v == 'done').length;
           final maxScore = habitRepo.getHabits().fold<double>(0.0, (sum, h) => sum + (h.type == HabitType.counter ? h.target : 1.0));
           final currentScore = completions.completions.values.fold<double>(0.0, (sum, val) => sum + (val is num ? val.toDouble() : (val == true || val == 'done' ? 1.0 : 0.0)));
           if (currentScore >= maxScore && maxScore > 0) allDone = true;
        }
        if (allDone) continue;

        final baseScheduled = DateTime(date.year, date.month, date.day, state.habitTime.hour, state.habitTime.minute);
        final scheduled = _applySnooze(baseScheduled, payload);
        
        if (scheduled.isAfter(now)) {
          await _notificationService.scheduleAbsolute(
            id: 1000 + i,
            title: 'Evening Routine',
            body: '$userName, time for your evening reading and habits.',
            scheduledDate: scheduled,
            payload: payload,
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
          final payload = _buildPayload('lunch', dateStr);
          if (!_isSkipped(payload) && !mealRepo.isMealLogged(dateStr, 'lunch')) {
            final baseScheduled = DateTime(date.year, date.month, date.day, state.lunchTime.hour, state.lunchTime.minute);
            final scheduled = _applySnooze(baseScheduled, payload);

            if (scheduled.isAfter(now)) {
              await _notificationService.scheduleAbsolute(
                id: 2000 + i,
                title: 'Lunch Check-in',
                body: 'A quick check-in: have you logged lunch?',
                scheduledDate: scheduled,
                payload: payload,
              );
            }
          }
        }
        
        // Dinner
        if (!_isWithinQuietHours(state.dinnerTime)) {
          final payload = _buildPayload('dinner', dateStr);
          if (!_isSkipped(payload) && !mealRepo.isMealLogged(dateStr, 'dinner')) {
            final baseScheduled = DateTime(date.year, date.month, date.day, state.dinnerTime.hour, state.dinnerTime.minute);
            final scheduled = _applySnooze(baseScheduled, payload);

            if (scheduled.isAfter(now)) {
              await _notificationService.scheduleAbsolute(
                id: 2100 + i,
                title: 'Dinner Check-in',
                body: 'Time to track your dinner.',
                scheduledDate: scheduled,
                payload: payload,
              );
            }
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
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final payload = _buildPayload('workout', dateStr);
            
            if (_isSkipped(payload)) continue;

            final workoutStatus = dailyLogRepo.getLog(dateStr)?.workoutStatus;
            if (workoutStatus == 'completed' || workoutStatus == 'skipped') continue;

            final baseScheduled = DateTime(date.year, date.month, date.day, state.workoutTime.hour, state.workoutTime.minute);
            final scheduled = _applySnooze(baseScheduled, payload);

            if (scheduled.isAfter(now)) {
              final timeStr = DateFormat('h:mm a').format(scheduled);
              await _notificationService.scheduleAbsolute(
                id: 3000 + i,
                title: 'Workout Scheduled',
                body: 'Your workout is scheduled for $timeStr. Ready when you are.',
                scheduledDate: scheduled,
                addSnooze: true,
                addSkip: true,
                payload: payload,
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
      final payload = _buildPayload('backup', DateFormat('yyyy-MM-dd').format(scheduled));
      if (!_isSkipped(payload)) {
        final finalScheduled = _applySnooze(scheduled, payload);
        await _notificationService.scheduleAbsolute(
          id: 4000,
          title: 'Weekly Backup',
          body: 'Time to back up your data securely.',
          scheduledDate: finalScheduled,
          addSnooze: false,
          addSkip: false,
          payload: payload,
        );
      }
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
        final payload = _buildPayload('photo', DateFormat('yyyy-MM-dd').format(now));
        if (!_isSkipped(payload)) {
          final scheduled = DateTime(now.year, now.month, now.day, state.photoTime.hour, state.photoTime.minute);
          final finalScheduled = scheduled.isBefore(now) ? scheduled.add(const Duration(days: 1)) : scheduled;
          final finalSnoozed = _applySnooze(finalScheduled, payload);
          await _notificationService.scheduleAbsolute(
            id: 5000,
            title: 'Progress Photo',
            body: 'It\'s been a while. Take a quick photo to track your progress.',
            scheduledDate: finalSnoozed,
            payload: payload,
          );
        }
      }
    }
  }

  Future<void> initializeNotifications() async {
    await queueSync();
  }
  
  Future<void> clearOnSignOut() async {
     await _notificationService.cancelAll();
     await _prefs.remove('skipped_reminders');
     state = ReminderConfig();
  }
}

final remindersProvider = NotifierProvider<RemindersNotifier, ReminderConfig>(
  () {
    return RemindersNotifier();
  },
);
