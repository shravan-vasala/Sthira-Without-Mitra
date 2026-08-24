import 'mitra_event.dart';
import 'mitra_personality.dart';

class MitraPersonalityDecision {
  final MitraEvent event;
  final MitraEventSignificance significance;
  final MitraEmotionalState emotionalState;
  final MitraReactionIntensity intensity;
  final bool shouldReact;
  final String reason;

  const MitraPersonalityDecision({
    required this.event,
    required this.significance,
    required this.emotionalState,
    required this.intensity,
    required this.shouldReact,
    required this.reason,
  });
}
