import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      // Explicitly handle failure instead of defaulting to UTC silently
      throw Exception('Failed to resolve local timezone: $e');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Handle Snooze, Skip, and Mark Done actions
    final action = response.actionId;
    final payload = response.payload;
    if (action != null) {
      debugPrint('Notification Action received: $action with payload: $payload');
      // In a real app, this would route to a stream or provider
      // For now, it logs the action safely.
    }
  }

  Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      final bool? exactGranted = await androidImplementation.requestExactAlarmsPermission();
      return (granted ?? false) && (exactGranted ?? false);
    }
    return false;
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Cancels a specific range of IDs safely.
  Future<void> cancelRange(int startId, int endId) async {
    for (int i = startId; i <= endId; i++) {
      try {
        await _notificationsPlugin.cancel(i);
      } catch (_) {}
    }
  }

  /// Cancels habits (1000-1031)
  Future<void> cancelHabits() => cancelRange(1000, 1031);
  /// Cancels meals (2000-2031 lunch, 2100-2131 dinner)
  Future<void> cancelMeals() async {
    await cancelRange(2000, 2031);
    await cancelRange(2100, 2131);
  }
  /// Cancels workouts (3000-3031)
  Future<void> cancelWorkouts() => cancelRange(3000, 3031);
  /// Cancels backups (4000)
  Future<void> cancelBackup() => cancelRange(4000, 4000);
  /// Cancels photos (5000)
  Future<void> cancelPhotos() => cancelRange(5000, 5000);
  /// Cancels body fat (6000)
  Future<void> cancelBodyFat() => cancelRange(6000, 6000);

  Future<void> scheduleAbsolute({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    bool addSnooze = true,
    bool addSkip = true,
  }) async {
    if (!_initialized) await init();

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    final actions = <AndroidNotificationAction>[];
    if (addSnooze) {
      actions.add(const AndroidNotificationAction('snooze', 'Snooze'));
    }
    if (addSkip) {
      actions.add(const AndroidNotificationAction('skip', 'Skip Today'));
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'routine_reminders',
          'Routine Reminders',
          channelDescription: 'Daily habits, meals, and workouts',
          importance: Importance.high,
          priority: Priority.high,
          actions: actions.isNotEmpty ? actions : null,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> scheduleRestTimer(
    int seconds,
    String? exerciseName, {
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    if (!_initialized) await init();

    final title = 'Rest Complete!';
    final body = exerciseName != null
        ? 'Time for $exerciseName'
        : 'Your rest timer has finished.';

    try {
      await _notificationsPlugin.zonedSchedule(
        // Use ID 100 for rest timer to clearly separate from routine IDs
        100,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_timer',
            'Rest Timer',
            channelDescription: 'Notifications for rest timer completion',
            importance: Importance.max,
            priority: Priority.high,
            playSound: playSound,
            enableVibration: enableVibration,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // Ignore
    }
  }

  Future<void> cancelRestTimer() async {
    try {
      await _notificationsPlugin.cancel(100);
    } catch (e) {
      // Ignore
    }
  }


}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
