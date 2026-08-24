import '../mitra_event.dart';
import '../context/mitra_context_snapshot.dart';
import '../mitra_personality_decision.dart';

class MitraOpportunity {
  final MitraEvent event;
  final MitraContextSnapshot contextSnapshot;
  final MitraPersonalityDecision personalityDecision;

  const MitraOpportunity({
    required this.event,
    required this.contextSnapshot,
    required this.personalityDecision,
  });
}
