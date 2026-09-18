import 'package:flutter/services.dart';
import '../theme/app_motion.dart';


class Haptics {
  Haptics._();

  static bool enabled = true;

  static void tap() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  static void toggle() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  static void success() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  static void milestone() {
    if (!enabled) return;
    // Vibrate twice for a milestone
    HapticFeedback.heavyImpact();
    Future.delayed(const Motion.instant, () {
      HapticFeedback.heavyImpact();
    });
  }

  static void destructive() {
    if (!enabled) return;
    HapticFeedback.vibrate();
  }

  static void error() {
    if (!enabled) return;
    HapticFeedback.vibrate();
    Future.delayed(const Motion.instant, () {
      HapticFeedback.vibrate();
    });
  }
}
