import 'mitra_sunflower_animation_state.dart';
import 'mitra_sunflower_animation_transition.dart';

class MitraSunflowerAnimationSnapshot {
  final MitraSunflowerAnimationState currentState;
  final MitraSunflowerAnimationTransition? activeTransition;
  final bool isReducedMotion;

  const MitraSunflowerAnimationSnapshot({
    required this.currentState,
    this.activeTransition,
    this.isReducedMotion = false,
  });

  @override
  String toString() {
    return 'AnimationSnapshot(state: ${currentState.name}, activeTransition: ${activeTransition?.name})';
  }
}
