import 'package:flutter/services.dart';

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
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.heavyImpact();
    });
  }

  static void destructive() {
    if (!enabled) return;
    HapticFeedback.vibrate();
  }
}
