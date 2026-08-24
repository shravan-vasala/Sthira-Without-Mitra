import 'dart:math';

import 'mitra_relationship.dart';
import 'mitra_relationship_context.dart';
import 'mitra_relationship_decision.dart';
import 'mitra_relationship_event.dart';

class MitraRelationshipEngine {
  final MitraRelationshipContext _context = MitraRelationshipContext();

  MitraRelationshipContext get debugContext => _context; // For debug lab

  MitraRelationshipDecision evaluate(MitraRelationshipEvent event) {
    // 1. Identify Milestones
    final milestone = _determineMilestone(event);

    // 2. Update Context
    _context.addEvent(event);
    if (milestone != MitraRelationshipMilestone.none) {
      _context.lastMilestone = milestone;
    }

    // 3. Determine Familiarity
    final familiarity = _calculateFamiliarity();
    final isFamiliar = familiarity >= 0.40;

    // 4. Determine Tone
    final tone = _determineTone(familiarity, event);
    _context.currentTone = tone;

    // 5. Generate Reason
    final reason = _generateReason(tone, milestone, event);

    return MitraRelationshipDecision(
      event: event,
      tone: tone,
      milestone: milestone,
      isFamiliar: isFamiliar,
      familiarity: familiarity,
      reason: reason,
    );
  }

  MitraRelationshipMilestone _determineMilestone(MitraRelationshipEvent event) {
    if (_context.totalInteractionCount == 0 && event.type == MitraRelationshipEventType.firstInteraction) {
      return MitraRelationshipMilestone.firstInteraction;
    }

    if (_context.completedWorkoutCount == 0 && event.type == MitraRelationshipEventType.workoutCompleted) {
      return MitraRelationshipMilestone.firstWorkout;
    }

    if (event.type == MitraRelationshipEventType.returnedAfterGap) {
      return MitraRelationshipMilestone.returnAfterLongGap;
    }

    // Example of interaction milestone (e.g. 50th meaningful interaction)
    if (event.type == MitraRelationshipEventType.meaningfulProgress && _context.meaningfulInteractionCount == 49) {
      return MitraRelationshipMilestone.interactionMilestone;
    }

    return MitraRelationshipMilestone.none;
  }

  double _calculateFamiliarity() {
    // Determine bounded score based on meaningful interactions and length of relationship
    // This is NOT XP. It's a deterministic contextual score.
    // Max score components: 
    // Meaningful interactions: up to 0.6
    // Workouts: up to 0.2
    // Longevity (days since first interaction): up to 0.2

    double meaningfulScore = min(_context.meaningfulInteractionCount / 50.0, 1.0) * 0.6;
    double workoutScore = min(_context.completedWorkoutCount / 20.0, 1.0) * 0.2;
    
    double longevityScore = 0.0;
    if (_context.firstInteractionTime != null) {
      final days = DateTime.now().difference(_context.firstInteractionTime!).inDays;
      longevityScore = min(days / 30.0, 1.0) * 0.2;
    }

    double totalFamiliarity = meaningfulScore + workoutScore + longevityScore;
    
    return totalFamiliarity.clamp(0.0, 1.0);
  }

  MitraRelationshipTone _determineTone(double familiarity, MitraRelationshipEvent event) {
    // If the user returns after a gap, we maintain the existing tone or use warm acknowledgement
    if (event.type == MitraRelationshipEventType.returnedAfterGap) {
      return _context.currentTone != MitraRelationshipTone.reserved 
          ? _context.currentTone 
          : MitraRelationshipTone.warm;
    }

    if (familiarity < 0.20) return MitraRelationshipTone.reserved;
    if (familiarity < 0.40) return MitraRelationshipTone.warm;
    if (familiarity < 0.65) return MitraRelationshipTone.familiar;
    if (familiarity < 0.85) return MitraRelationshipTone.playful;
    return MitraRelationshipTone.deeplyFamiliar;
  }

  String _generateReason(MitraRelationshipTone tone, MitraRelationshipMilestone milestone, MitraRelationshipEvent event) {
    if (event.type == MitraRelationshipEventType.returnedAfterGap) {
      return 'User returned after a period away; relationship remains intact.';
    }
    
    if (milestone != MitraRelationshipMilestone.none) {
      return 'Achieved relationship milestone: ${milestone.name}.';
    }

    return 'Familiarity derived from interaction history supports a ${tone.name} tone.';
  }

  void resetRelationship() {
    _context.reset();
  }
}
