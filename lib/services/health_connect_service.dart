import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:isar/isar.dart';
import '../models/app_config.dart';

import '../models/feature_availability.dart';

enum StepsSource { healthConnect, manual, none }

class HealthConnectService {
  static const String _backfillDoneKey = 'health_connect_backfill_done';

  final Health _health = Health();
  late final Isar _isar;
  bool _configured = false;

  Future<void> init() async {
    _isar = Isar.getInstance()!;
  }

  Future<void> _ensureConfigured() async {
    if (!_configured) {
      await _health.configure();
      _configured = true;
    }
  }

  Future<FeatureAvailability> getAvailability() async {
    if (!await isAvailable()) return FeatureAvailability.unavailable;
    if (!await isAuthorized()) return FeatureAvailability.disabled;
    return FeatureAvailability.available;
  }

  /// Check if Health Connect app is installed on the device.
  Future<bool> isAvailable() async {
    try {
      await _ensureConfigured();
      final status = await _health.getHealthConnectSdkStatus();
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (_) {
      return false;
    }
  }

  /// Check if we already have STEPS + SLEEP_SESSION read permission.
  Future<bool> isAuthorized() async {
    try {
      await _ensureConfigured();
      final types = [HealthDataType.STEPS, HealthDataType.SLEEP_SESSION];
      final perms = [HealthDataAccess.READ, HealthDataAccess.READ];
      return await _health.hasPermissions(types, permissions: perms) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request STEPS + SLEEP_SESSION read permission from Health Connect.
  Future<bool> requestPermission() async {
    try {
      await _ensureConfigured();
      // Request activity recognition first (required for step data)
      await Permission.activityRecognition.request();

      final types = [HealthDataType.STEPS, HealthDataType.SLEEP_SESSION];
      final perms = [HealthDataAccess.READ, HealthDataAccess.READ];
      return await _health.requestAuthorization(types, permissions: perms);
    } catch (_) {
      return false;
    }
  }

  /// Request historical data access (needed for >30 day backfill).
  Future<bool> requestHistoryAccess() async {
    try {
      await _ensureConfigured();
      return await _health.requestHealthDataHistoryAuthorization();
    } catch (_) {
      return false;
    }
  }

  /// Get today's total step count from Health Connect.
  Future<int?> getTodaySteps() async {
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps;
    } catch (_) {
      return null;
    }
  }

  /// Get step count for a specific calendar day.
  Future<int?> getStepsForDate(DateTime date) async {
    try {
      await _ensureConfigured();
      final start = DateTime(date.year, date.month, date.day);
      final end = start
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps;
    } catch (_) {
      return null;
    }
  }

  /// Get sleep hours for a specific calendar day.
  /// Health Connect often stores sleep sessions from previous night to current morning.
  Future<double?> getSleepForDate(DateTime date) async {
    try {
      await _ensureConfigured();
      // Sleep for a date usually means sleep ending on that date
      final start = DateTime(
        date.year,
        date.month,
        date.day - 1,
        18,
        0,
      ); // 6 PM previous day
      final end = DateTime(
        date.year,
        date.month,
        date.day,
        18,
        0,
      ); // 6 PM current day

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_SESSION],
        startTime: start,
        endTime: end,
      );

      if (healthData.isEmpty) return null;

      // Deduplicate overlapping sleep sessions
      healthData.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
      double totalMinutes = 0;
      DateTime? currentStart;
      DateTime? currentEnd;

      for (final data in healthData) {
        if (currentStart == null) {
          currentStart = data.dateFrom;
          currentEnd = data.dateTo;
        } else {
          if (data.dateFrom.isBefore(currentEnd!)) {
            // Overlapping, extend currentEnd if this session ends later
            if (data.dateTo.isAfter(currentEnd)) {
              currentEnd = data.dateTo;
            }
          } else {
            // No overlap, add previous interval and start new
            totalMinutes += currentEnd.difference(currentStart).inMinutes;
            currentStart = data.dateFrom;
            currentEnd = data.dateTo;
          }
        }
      }
      if (currentStart != null && currentEnd != null) {
        totalMinutes += currentEnd.difference(currentStart).inMinutes;
      }

      return double.parse((totalMinutes / 60).toStringAsFixed(1));
    } catch (_) {
      return null;
    }
  }

  /// Whether the 90-day backfill has already been done.
  bool get isBackfillDone {
    final config = _isar.appConfigs
        .where()
        .keyEqualTo(_backfillDoneKey)
        .findFirstSync();
    return config?.value == 'true';
  }

  Future<List<HealthDailyData>> backfillLast90Days() async {
    if (isBackfillDone) return [];

    final hasAuth = await isAuthorized();
    if (!hasAuth) {
      final granted = await requestPermission();
      if (!granted) return [];
    }

    final historyGranted = await requestHistoryAccess();
    if (!historyGranted) {
      return [];
    }

    final List<HealthDailyData> results = [];
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');

    for (int i = 1; i <= 90; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = dateFormat.format(date);

      final steps = await getStepsForDate(date);
      final sleep = await getSleepForDate(date);

      if ((steps != null && steps > 0) || (sleep != null && sleep > 0)) {
        results.add(HealthDailyData(dateStr: dateStr, steps: steps, sleepHours: sleep));
      }
    }

    await _isar.writeTxn(() async {
      await _isar.appConfigs.put(
        AppConfig(key: _backfillDoneKey, value: 'true'),
      );
    });
    
    return results;
  }

  Future<List<HealthDailyData>> syncLast7Days() async {
    final List<HealthDailyData> results = [];
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');

    for (int i = 0; i <= 6; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = dateFormat.format(date);

      final steps = await getStepsForDate(date);
      final sleep = await getSleepForDate(date);

      if ((steps != null && steps > 0) || (sleep != null && sleep > 0)) {
        results.add(HealthDailyData(dateStr: dateStr, steps: steps, sleepHours: sleep));
      }
    }

    return results;
  }

  Future<HealthDailyData?> syncToday() async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final steps = await getTodaySteps();
    final sleep = await getSleepForDate(now);
    
    if (steps != null || sleep != null) {
      return HealthDailyData(dateStr: dateStr, steps: steps, sleepHours: sleep);
    }
    return null;
  }

  /// Try reading today's steps to verify permission.
  /// [hasPermissions] is unreliable on Android Health Connect after process death.
  Future<bool> canReadSteps() async {
    try {
      final steps = await getTodaySteps();
      return steps != null;
    } catch (_) {
      return false;
    }
  }
}

class HealthDailyData {
  final String dateStr;
  final int? steps;
  final double? sleepHours;

  HealthDailyData({
    required this.dateStr,
    this.steps,
    this.sleepHours,
  });
}

