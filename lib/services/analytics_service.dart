import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Singleton instance
  static final AnalyticsService instance = AnalyticsService._();

  AnalyticsService._();

  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      if (kDebugMode) {
        debugPrint('Analytics Event: $name | Params: $parameters');
      }
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to log analytics event: $e');
      }
    }
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService.instance;
});
