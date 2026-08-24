import '../mitra_sunflower_state.dart';
import 'mitra_sunflower_animation_state.dart';
import 'mitra_sunflower_animation_transition.dart';
import 'mitra_sunflower_animation_choreography.dart';
import 'mitra_sunflower_animation_snapshot.dart';

class MitraSunflowerAnimationController {
  final void Function(MitraSunflowerAnimationTransition)? onTransitionRequested;
  
  MitraSunflowerAnimationState _currentState = MitraSunflowerAnimationState.idle;
  MitraSunflowerAnimationTransition? _activeTransition;
  DateTime? _transitionStartTime;

  MitraSunflowerAnimationController({this.onTransitionRequested});

  bool _isReducedMotion = false;
  
  // Anti-thrashing & Phase 20 Daily Latch state
  MitraSunflowerState? _lastProcessedState;
  MitraSunflowerState? _dailyHighWaterMark;
  DateTime? _latchDate;
  bool _isInitialized = false;
  
  // Phase 20 Debug Helpers
  MitraSunflowerState? get debugDailyHighWaterMark => _dailyHighWaterMark;
  DateTime? get debugLatchDate => _latchDate;
  bool get debugIsInitialized => _isInitialized;
  
  void debugResetLatch() {
    _isInitialized = false;
    _latchDate = null;
    _dailyHighWaterMark = null;
  }
  
  MitraSunflowerAnimationSnapshot get currentSnapshot => MitraSunflowerAnimationSnapshot(
    currentState: _currentState,
    activeTransition: _activeTransition,
    isReducedMotion: _isReducedMotion,
  );

  void setReducedMotion(bool enabled) {
    _isReducedMotion = enabled;
  }

  int _getStateWeight(MitraSunflowerState state) {
    switch (state) {
      case MitraSunflowerState.seed: return 0;
      case MitraSunflowerState.sprout: return 1;
      case MitraSunflowerState.youngPlant: return 2;
      case MitraSunflowerState.growing: return 3;
      case MitraSunflowerState.blooming: return 4;
      case MitraSunflowerState.fullBloom: return 5;
      case MitraSunflowerState.resting: return -1;
    }
  }

  MitraSunflowerAnimationState _mapStateToAnimationState(MitraSunflowerState state) {
    switch (state) {
      case MitraSunflowerState.seed: return MitraSunflowerAnimationState.idle;
      case MitraSunflowerState.sprout: return MitraSunflowerAnimationState.waking;
      case MitraSunflowerState.youngPlant: return MitraSunflowerAnimationState.growing;
      case MitraSunflowerState.growing: return MitraSunflowerAnimationState.flourishing;
      case MitraSunflowerState.blooming: return MitraSunflowerAnimationState.blooming;
      case MitraSunflowerState.fullBloom: return MitraSunflowerAnimationState.exceptionalBlooming;
      case MitraSunflowerState.resting: return MitraSunflowerAnimationState.resting;
    }
  }

  void processPhase12Snapshot(MitraSunflowerState state, DateTime now) {
    final bool isSameDay = _latchDate != null && 
        _latchDate!.year == now.year && 
        _latchDate!.month == now.month && 
        _latchDate!.day == now.day;

    if (!isSameDay) {
      // New day reset
      _dailyHighWaterMark = state;
      _latchDate = now;
      _isInitialized = true;
      _currentState = _mapStateToAnimationState(state);
      _activeTransition = null;
      _transitionStartTime = null;
      _lastProcessedState = state;
      return;
    }

    if (!_isInitialized) {
      // App restart / initial resume on same day
      _dailyHighWaterMark = state;
      _latchDate = now;
      _isInitialized = true;
      _currentState = _mapStateToAnimationState(state);
      _activeTransition = null;
      _transitionStartTime = null;
      _lastProcessedState = state;
      return;
    }

    if (_lastProcessedState == state) {
      return;
    }
    
    final currentWeight = _getStateWeight(state);
    final highWaterMarkWeight = _dailyHighWaterMark != null ? _getStateWeight(_dailyHighWaterMark!) : -1;

    // Backward Suppression
    if (currentWeight <= highWaterMarkWeight && state != MitraSunflowerState.resting) {
      // Ignore lower states. Keep the highest achieved visual state.
      _lastProcessedState = state; 
      return;
    }

    // Forward Transition
    if (state != MitraSunflowerState.resting) {
      _dailyHighWaterMark = state;
    }
    _lastProcessedState = state;

    // Determine target transition based on Phase 12 state
    MitraSunflowerAnimationTransition? targetTransition;
    
    switch (state) {
      case MitraSunflowerState.seed:
        targetTransition = MitraSunflowerAnimationChoreography.reset;
        break;
      case MitraSunflowerState.sprout:
        targetTransition = MitraSunflowerAnimationChoreography.wake;
        break;
      case MitraSunflowerState.youngPlant:
        targetTransition = MitraSunflowerAnimationChoreography.grow;
        break;
      case MitraSunflowerState.growing:
        targetTransition = MitraSunflowerAnimationChoreography.flourish;
        break;
      case MitraSunflowerState.blooming:
        targetTransition = MitraSunflowerAnimationChoreography.bloom;
        break;
      case MitraSunflowerState.fullBloom:
        targetTransition = MitraSunflowerAnimationChoreography.exceptionalBloom;
        break;
      case MitraSunflowerState.resting:
        if (_currentState == MitraSunflowerAnimationState.idle || 
            _currentState == MitraSunflowerAnimationState.flourishing ||
            _currentState == MitraSunflowerAnimationState.blooming ||
            _currentState == MitraSunflowerAnimationState.exceptionalBlooming ||
            _currentState == MitraSunflowerAnimationState.settling) {
          targetTransition = MitraSunflowerAnimationChoreography.settle;
        } else {
          targetTransition = MitraSunflowerAnimationChoreography.rest;
        }
        break;
    }

    if (targetTransition != null) {
      requestTransition(targetTransition, now);
    }
  }

  void requestTransition(MitraSunflowerAnimationTransition transition, DateTime now) {
    if (_isReducedMotion) {
      // Complete immediately
      _currentState = transition.toState;
      _activeTransition = null;
      onTransitionRequested?.call(transition);
      return;
    }

    if (_activeTransition != null) {
      if (!transition.priority.canInterrupt(_activeTransition!.priority)) {
        // Discard or queue. For now, discard if priority is lower.
        return;
      }
    }

    _activeTransition = transition;
    _currentState = transition.fromState;
    _transitionStartTime = now;
    onTransitionRequested?.call(transition);
  }

  void requestSmallProgress(DateTime now) {
    requestTransition(MitraSunflowerAnimationChoreography.smallProgress, now);
  }

  void requestIdle(DateTime now) {
    // Only idle if we aren't doing something else
    if (_activeTransition == null) {
      requestTransition(MitraSunflowerAnimationChoreography.idle, now);
    }
  }

  void tick(DateTime now) {
    if (_activeTransition == null || _transitionStartTime == null) return;

    final elapsed = now.difference(_transitionStartTime!);
    if (elapsed >= _activeTransition!.duration) {
      // Transition complete
      _currentState = _activeTransition!.toState;
      
      // If we finished settling, automatically go to rest
      if (_currentState == MitraSunflowerAnimationState.settling) {
        requestTransition(MitraSunflowerAnimationChoreography.rest, now);
      } else {
        _activeTransition = null;
      }
    }
  }

  void forceState(MitraSunflowerAnimationState state) {
    _currentState = state;
    _activeTransition = null;
    _transitionStartTime = null;
  }
}
