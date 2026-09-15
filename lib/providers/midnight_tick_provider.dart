import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

/// Triggers precisely at midnight local time to roll over the app's 'today' state.
final midnightTickProvider = NotifierProvider<MidnightTickNotifier, void>(() {
  return MidnightTickNotifier();
});

class MidnightTickNotifier extends Notifier<void> {
  Timer? _timer;

  @override
  void build() {
    _scheduleMidnightTick();

    ref.onDispose(() {
      _timer?.cancel();
    });
  }

  void _scheduleMidnightTick() {
    _timer?.cancel();
    
    final now = DateTime.now();
    // Next midnight
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final msUntilMidnight = nextMidnight.difference(now).inMilliseconds;

    // Schedule timer exactly when midnight strikes
    _timer = Timer(Duration(milliseconds: msUntilMidnight + 100), () {
      // Midnight has struck while app is open!
      // Invalidate the selected date provider to force a refresh of today
      ref.invalidate(selectedDateProvider);
      
      // Reschedule for the next day
      _scheduleMidnightTick();
    });
  }
}
