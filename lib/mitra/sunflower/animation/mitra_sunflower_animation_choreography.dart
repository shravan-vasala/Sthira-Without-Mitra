import 'mitra_sunflower_animation_state.dart';
import 'mitra_sunflower_animation_priority.dart';
import 'mitra_sunflower_animation_transition.dart';

class MitraSunflowerAnimationChoreography {
  static const MitraSunflowerAnimationTransition wake = MitraSunflowerAnimationTransition(
    name: 'WAKE',
    fromState: MitraSunflowerAnimationState.resting,
    toState: MitraSunflowerAnimationState.waking,
    priority: MitraSunflowerAnimationPriority.growthTransition,
    duration: Duration(milliseconds: 3000),
  );

  static const MitraSunflowerAnimationTransition grow = MitraSunflowerAnimationTransition(
    name: 'GROW',
    fromState: MitraSunflowerAnimationState.waking,
    toState: MitraSunflowerAnimationState.growing,
    priority: MitraSunflowerAnimationPriority.growthTransition,
    duration: Duration(milliseconds: 2500),
  );

  static const MitraSunflowerAnimationTransition flourish = MitraSunflowerAnimationTransition(
    name: 'FLOURISH',
    fromState: MitraSunflowerAnimationState.growing,
    toState: MitraSunflowerAnimationState.flourishing,
    priority: MitraSunflowerAnimationPriority.growthTransition,
    duration: Duration(milliseconds: 2000),
  );

  static const MitraSunflowerAnimationTransition bloom = MitraSunflowerAnimationTransition(
    name: 'BLOOM',
    fromState: MitraSunflowerAnimationState.flourishing,
    toState: MitraSunflowerAnimationState.blooming,
    priority: MitraSunflowerAnimationPriority.bloom,
    duration: Duration(milliseconds: 4000),
  );

  static const MitraSunflowerAnimationTransition exceptionalBloom = MitraSunflowerAnimationTransition(
    name: 'EXCEPTIONAL_BLOOM',
    fromState: MitraSunflowerAnimationState.blooming,
    toState: MitraSunflowerAnimationState.exceptionalBlooming,
    priority: MitraSunflowerAnimationPriority.bloom,
    duration: Duration(milliseconds: 4000),
  );

  static const MitraSunflowerAnimationTransition settle = MitraSunflowerAnimationTransition(
    name: 'SETTLE',
    fromState: MitraSunflowerAnimationState.blooming,
    toState: MitraSunflowerAnimationState.settling,
    priority: MitraSunflowerAnimationPriority.growthTransition,
    duration: Duration(milliseconds: 2500),
  );

  static const MitraSunflowerAnimationTransition rest = MitraSunflowerAnimationTransition(
    name: 'REST',
    fromState: MitraSunflowerAnimationState.settling,
    toState: MitraSunflowerAnimationState.resting,
    priority: MitraSunflowerAnimationPriority.growthTransition,
    duration: Duration(milliseconds: 3000),
  );

  static const MitraSunflowerAnimationTransition reset = MitraSunflowerAnimationTransition(
    name: 'RESET',
    fromState: MitraSunflowerAnimationState.resting,
    toState: MitraSunflowerAnimationState.resetting,
    priority: MitraSunflowerAnimationPriority.growthTransition,
    duration: Duration(milliseconds: 2000),
  );
  
  static const MitraSunflowerAnimationTransition idle = MitraSunflowerAnimationTransition(
    name: 'IDLE',
    fromState: MitraSunflowerAnimationState.idle,
    toState: MitraSunflowerAnimationState.idle,
    priority: MitraSunflowerAnimationPriority.idle,
    duration: Duration(milliseconds: 5000),
  );

  static const MitraSunflowerAnimationTransition smallProgress = MitraSunflowerAnimationTransition(
    name: 'SMALL_PROGRESS',
    fromState: MitraSunflowerAnimationState.idle,
    toState: MitraSunflowerAnimationState.idle,
    priority: MitraSunflowerAnimationPriority.smallProgress,
    duration: Duration(milliseconds: 1500),
  );

  static const MitraSunflowerAnimationTransition mitraArrived = MitraSunflowerAnimationTransition(
    name: 'MITRA_ARRIVED',
    fromState: MitraSunflowerAnimationState.idle,
    toState: MitraSunflowerAnimationState.idle,
    priority: MitraSunflowerAnimationPriority.smallProgress,
    duration: Duration(milliseconds: 1500),
  );

  static const MitraSunflowerAnimationTransition mitraTouching = MitraSunflowerAnimationTransition(
    name: 'MITRA_TOUCHING',
    fromState: MitraSunflowerAnimationState.idle,
    toState: MitraSunflowerAnimationState.idle,
    priority: MitraSunflowerAnimationPriority.smallProgress,
    duration: Duration(milliseconds: 2000),
  );

  static const MitraSunflowerAnimationTransition mitraDeparting = MitraSunflowerAnimationTransition(
    name: 'MITRA_DEPARTING',
    fromState: MitraSunflowerAnimationState.idle,
    toState: MitraSunflowerAnimationState.idle,
    priority: MitraSunflowerAnimationPriority.smallProgress,
    duration: Duration(milliseconds: 1500),
  );
}
