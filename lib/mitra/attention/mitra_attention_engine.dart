import '../mitra_event.dart';
import '../context/mitra_context_types.dart';
import '../mitra_personality_decision.dart';
import '../mitra_personality.dart';
import 'mitra_attention.dart';
import 'mitra_attention_context.dart';
import 'mitra_opportunity.dart';
import 'mitra_opportunity_decision.dart';

class MitraAttentionEngine {
  final MitraAttentionContext _context = MitraAttentionContext();
  MitraAttentionContext get debugContext => _context;

  MitraOpportunityDecision evaluate(
    MitraOpportunity opportunity,
    DateTime now,
  ) {
    final ctx = opportunity.contextSnapshot;
    final personality = opportunity.personalityDecision;

    // 1. HARD RULE: Background -> suppress
    if (ctx.lifecycleState == MitraAppLifecycle.background ||
        ctx.lifecycleState == MitraAppLifecycle.inactive) {
      return _suppress(
        reason: 'App is backgrounded or inactive.',
        interruptionRisk: MitraInterruptionRisk.none,
        now: now,
      );
    }

    // 2. HARD RULE: Navigation Transition -> suppress
    if (ctx.currentActivity == MitraUserActivity.transitioning) {
      return _suppress(
        reason: 'User is transitioning between screens.',
        interruptionRisk: MitraInterruptionRisk.high,
        recommendedDelay: const Duration(milliseconds: 1200),
        now: now,
      );
    }

    // 3. HARD RULE: Quiet Period
    if (_context.quietUntil != null && now.isBefore(_context.quietUntil!)) {
      return _suppress(
        reason: 'Mitra is currently in a quiet period.',
        interruptionRisk: MitraInterruptionRisk.medium,
        now: now,
      );
    }
    
    // Evaluate if this is a "special/important" event
    final isSpecial = personality.significance == MitraEventSignificance.special ||
                      personality.significance == MitraEventSignificance.important;
                      
    // 4. RULE: Active User Input (engaged) -> suppress or delay
    if (ctx.currentActivity == MitraUserActivity.engaged) {
      if (!isSpecial) {
        return _suppress(
          reason: 'User is actively engaged; suppressing trivial event.',
          interruptionRisk: MitraInterruptionRisk.critical,
          recommendedDelay: const Duration(seconds: 3),
          now: now,
        );
      } else {
        // Special event during engagement: High risk, but let it proceed with a delay if appropriate
        // (Actually, the rules say "They must never bypass active critical interaction")
        return _suppress(
          reason: 'User is actively engaged; suppressing important event due to critical interruption risk.',
          interruptionRisk: MitraInterruptionRisk.critical,
          recommendedDelay: const Duration(seconds: 2),
          now: now,
        );
      }
    }

    // 5. RULE: Active Workout -> suppress unless important
    if (ctx.currentScreen == MitraAppScreen.workout && ctx.currentActivity != MitraUserActivity.idle) {
      if (!isSpecial) {
        return _suppress(
          reason: 'Active workout in progress; suppressing trivial event.',
          interruptionRisk: MitraInterruptionRisk.high,
          now: now,
        );
      }
      // If special, we can proceed.
    }

    // 6. RULE: Rest Timer Active -> suppress trivial ambient behaviour
    if (ctx.isRestTimerActive) {
      if (!isSpecial) {
        return _suppress(
          reason: 'Rest Timer is active; suppressing trivial ambient behaviour.',
          interruptionRisk: MitraInterruptionRisk.medium,
          now: now,
        );
      }
    }

    // Evaluate base score
    double score = 50.0;
    MitraOpportunityType oppType = MitraOpportunityType.contextual;
    MitraAttentionLevel attLevel = MitraAttentionLevel.available;
    MitraInterruptionRisk intRisk = MitraInterruptionRisk.low;

    if (ctx.currentActivity == MitraUserActivity.idle) {
      score += 20;
      attLevel = MitraAttentionLevel.focused;
    }

    if (opportunity.event.type == MitraEventType.userReturn) {
      score += 15;
      oppType = MitraOpportunityType.returnToApp;
    }

    if (isSpecial) {
      score += 25;
      if (personality.significance == MitraEventSignificance.special) {
        oppType = MitraOpportunityType.milestone;
      } else {
        oppType = MitraOpportunityType.celebratory;
      }
    }
    
    // Penalty: Recent Mitra Reaction
    if (_context.lastAcceptedOpportunityTime != null) {
      final diff = now.difference(_context.lastAcceptedOpportunityTime!);
      if (diff.inSeconds < 10) {
        score -= 40;
      } else if (diff.inSeconds < 30) {
        score -= 20;
      }
    }

    // Final decision threshold
    final shouldProceed = score >= 50.0 && personality.shouldReact;

    final decision = MitraOpportunityDecision(
      type: oppType,
      attentionLevel: attLevel,
      interruptionRisk: intRisk,
      score: score,
      shouldProceed: shouldProceed,
      reason: shouldProceed 
          ? 'Score ${score.toStringAsFixed(0)} indicates a good opportunity.'
          : 'Score ${score.toStringAsFixed(0)} is too low or Personality suppressed it.',
    );

    if (shouldProceed) {
      _context.recordAccepted(now);
      _context.recordOpportunity(now, oppType);
    } else {
      // If personality wanted to react but we suppressed it, count it
      if (personality.shouldReact) {
        _context.recordSuppression(now);
      }
    }

    return decision;
  }

  MitraOpportunityDecision _suppress({
    required String reason,
    required MitraInterruptionRisk interruptionRisk,
    Duration? recommendedDelay,
    required DateTime now,
  }) {
    _context.recordSuppression(now);
    return MitraOpportunityDecision(
      type: MitraOpportunityType.none,
      attentionLevel: MitraAttentionLevel.none,
      interruptionRisk: interruptionRisk,
      score: 0.0,
      shouldProceed: false,
      recommendedDelay: recommendedDelay,
      reason: reason,
    );
  }

  void resetContext() {
    _context.reset();
  }
}
