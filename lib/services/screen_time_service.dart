import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

final screenTimeServiceProvider = Provider<ScreenTimeService>((ref) {
  return ScreenTimeService();
});

class ScreenTimeResult {
  final String status; // 'success', 'denied', 'unavailable', 'failed'
  final int? minutes;
  final String? measuredDate;
  final int? timestamp;
  final String? error;

  ScreenTimeResult({
    required this.status,
    this.minutes,
    this.measuredDate,
    this.timestamp,
    this.error,
  });

  factory ScreenTimeResult.fromJson(Map<dynamic, dynamic> json) {
    return ScreenTimeResult(
      status: json['status'] as String? ?? 'failed',
      minutes: json['minutes'] as int?,
      measuredDate: json['measuredDate'] as String?,
      timestamp: json['timestamp'] as int?,
      error: json['error'] as String?,
    );
  }
}

class ScreenTimeService {
  static const MethodChannel _channel = MethodChannel(
    'com.trufit.trufit_bodamma/screentime',
  );

  /// Returns true if the app has PACKAGE_USAGE_STATS permission
  Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool hasPermission = await _channel.invokeMethod('checkPermission');
      return hasPermission;
    } catch (e) {
      debugPrint('Error checking screen time permission: $e');
      return false;
    }
  }

  /// Opens the device settings page for Usage Access
  Future<void> openSettings() async {
    if (!Platform.isAndroid) return;

    // Attempt to launch the exact intent via Kotlin
    try {
      await _channel.invokeMethod('openUsageSettings');
    } catch (e) {
      debugPrint('Failed to open usage settings via native channel: $e');
      // ignore: unawaited_futures
      openAppSettings();
    }
  }

  /// Fetches screen time (totalTimeInForeground) structured result for the current native day
  Future<ScreenTimeResult> getScreenTimeForToday() async {
    if (!Platform.isAndroid) {
      return ScreenTimeResult(status: 'unsupported');
    }

    try {
      final resultMap = await _channel.invokeMethod('getScreenTime');
      if (resultMap is Map) {
        return ScreenTimeResult.fromJson(resultMap);
      }
      return ScreenTimeResult(
        status: 'failed',
        error: 'Invalid response format',
      );
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        debugPrint('Screen time permission denied.');
        return ScreenTimeResult(status: 'denied', error: e.message);
      }
      debugPrint('Failed to get screen time: ${e.message}');
      return ScreenTimeResult(status: 'failed', error: e.message);
    } catch (e) {
      debugPrint('Error getting screen time: $e');
      return ScreenTimeResult(status: 'failed', error: e.toString());
    }
  }
}
