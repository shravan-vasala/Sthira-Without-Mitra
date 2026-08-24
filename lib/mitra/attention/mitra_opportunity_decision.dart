import 'mitra_attention.dart';

class MitraOpportunityDecision {
  final MitraOpportunityType type;
  final MitraAttentionLevel attentionLevel;
  final MitraInterruptionRisk interruptionRisk;
  final double score;
  final bool shouldProceed;
  final Duration? recommendedDelay;
  final String reason;

  const MitraOpportunityDecision({
    required this.type,
    required this.attentionLevel,
    required this.interruptionRisk,
    required this.score,
    required this.shouldProceed,
    this.recommendedDelay,
    required this.reason,
  });
}
