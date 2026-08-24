import 'dart:collection';

import 'mitra_app_context.dart';
import 'mitra_context_snapshot.dart';
import 'mitra_context_types.dart';

class MitraContextEngine {
  final MitraAppContext _context = MitraAppContext();
  MitraContextSnapshot? _lastSnapshot;
  final List<MitraContextSnapshot> _recentTransitions = [];
  
  UnmodifiableListView<MitraContextSnapshot> get recentTransitions => UnmodifiableListView(_recentTransitions);

  MitraContextSnapshot get currentSnapshot => _createSnapshot();

  void updateScreen(MitraAppScreen screen) {
    if (_context.currentScreen != screen) {
      _context.previousScreen = _context.currentScreen;
      _context.currentScreen = screen;
      _evaluateAndEmit();
    }
  }

  void updateLifecycle(MitraAppLifecycle lifecycle) {
    if (_context.lifecycleState != lifecycle) {
      if (_context.lifecycleState == MitraAppLifecycle.background && lifecycle == MitraAppLifecycle.foreground) {
        _context.sessionStartTime = DateTime.now();
      }
      _context.lifecycleState = lifecycle;
      _evaluateAndEmit();
    }
  }

  void updateActivity(MitraUserActivity activity) {
    if (_context.currentActivity != activity) {
      _context.currentActivity = activity;
      _evaluateAndEmit();
    }
  }

  void pingInteraction() {
    _context.lastUserInteractionTime = DateTime.now();
    _evaluateAndEmit();
  }

  void _evaluateAndEmit() {
    final prospective = _createSnapshot();
    if (_lastSnapshot == null || prospective != _lastSnapshot) {
      _lastSnapshot = prospective;
      _recentTransitions.add(prospective);
      if (_recentTransitions.length > 5) {
        _recentTransitions.removeAt(0);
      }
    }
  }

  MitraContextSnapshot _createSnapshot() {
    final now = DateTime.now();
    return MitraContextSnapshot(
      currentScreen: _context.currentScreen,
      previousScreen: _context.previousScreen,
      currentActivity: _context.currentActivity,
      lifecycleState: _context.lifecycleState,
      sessionStartTime: _context.sessionStartTime,
      lastUserInteractionTime: _context.lastUserInteractionTime,
      timeOfDay: _determineTimeOfDay(now),
      timeSinceLastInteraction: now.difference(_context.lastUserInteractionTime),
    );
  }

  MitraTimeOfDay _determineTimeOfDay(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) return MitraTimeOfDay.morning;
    if (hour >= 12 && hour < 17) return MitraTimeOfDay.afternoon;
    if (hour >= 17 && hour < 21) return MitraTimeOfDay.evening;
    return MitraTimeOfDay.night;
  }
}
