import 'mitra_relationship.dart';
import 'mitra_relationship_event.dart';

class MitraRelationshipDecision {
  final MitraRelationshipEvent event;
  final MitraRelationshipTone tone;
  final MitraRelationshipMilestone milestone;
  final bool isFamiliar;
  final double familiarity;
  final String reason;

  const MitraRelationshipDecision({
    required this.event,
    required this.tone,
    required this.milestone,
    required this.isFamiliar,
    required this.familiarity,
    required this.reason,
  });
}
