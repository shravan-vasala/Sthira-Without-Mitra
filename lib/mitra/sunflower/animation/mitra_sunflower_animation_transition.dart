import 'mitra_sunflower_animation_state.dart';
import 'mitra_sunflower_animation_priority.dart';

class MitraSunflowerAnimationTransition {
  final String name;
  final MitraSunflowerAnimationState fromState;
  final MitraSunflowerAnimationState toState;
  final MitraSunflowerAnimationPriority priority;
  final Duration duration;

  const MitraSunflowerAnimationTransition({
    required this.name,
    required this.fromState,
    required this.toState,
    required this.priority,
    required this.duration,
  });

  @override
  String toString() => 'Transition($name, priority: ${priority.name})';
}
