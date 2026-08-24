import 'dart:math';
import 'package:flutter/material.dart';

import '../../mitra_event.dart';
import '../../mitra_personality.dart';
import '../../mitra_personality_engine.dart';
import '../../mitra_personality_decision.dart';
import '../../attention/mitra_attention.dart';
import '../../attention/mitra_attention_engine.dart';
import '../../attention/mitra_opportunity.dart';
import '../../mitra_behaviour.dart';
import '../../mitra_behaviour_engine.dart';
import '../../context/mitra_context_types.dart';
import '../../context/mitra_context_snapshot.dart';
import '../../../widgets/mitra_interaction_engine.dart';
import 'mitra_daily_progress_snapshot.dart';
import 'mitra_sunflower_interaction_tier.dart';
import '../animation/mitra_sunflower_animation_choreography.dart';
import '../animation/mitra_sunflower_animation_transition.dart';

class MitraSunflowerInteractionSignal {
  final MitraDailyProgressSnapshot snapshot;
  final bool isMilestone;
  final double progressChange;

  MitraSunflowerInteractionSignal({
    required this.snapshot,
    this.isMilestone = false,
    this.progressChange = 0.0,
  });
}

class MitraCinematicIntegrationEngine {
  final MitraPersonalityEngine _personalityEngine = MitraPersonalityEngine();
  final MitraAttentionEngine _attentionEngine = MitraAttentionEngine();
  
  final GlobalKey<MitraInteractionEngineState> interactionKey;
  final GlobalKey<MitraBehaviourEngineState>? behaviourKey;
  final void Function(MitraSunflowerAnimationTransition) onContextualEvent;

  MitraCinematicIntegrationEngine({
    required this.interactionKey,
    this.behaviourKey,
    required this.onContextualEvent,
  });

  MitraDailyProgressSnapshot? _lastSnapshot;
  int _reactionGeneration = 0;
  bool _isRestTimerActive = false;
  final Random _random = Random();

  void updateTimerState(bool isActive) {
    _isRestTimerActive = isActive;
  }

  Future<void> onProgressSignal(MitraSunflowerInteractionSignal signal) async {
    // 1. Deduplication
    if (_lastSnapshot != null && _lastSnapshot!.coreDailyProgress == signal.snapshot.coreDailyProgress) {
      return;
    }
    _lastSnapshot = signal.snapshot;

    // 2. Map Phase 15 local signal to existing global event (Semantic Wrapper)
    final MitraEvent event = _mapToSemanticEvent(signal);

    // 3. Evaluate Personality (Phase 7 API remains unchanged)
    final personalityDecision = _personalityEngine.evaluate(event);
    if (!personalityDecision.shouldReact) return;

    // 4. Evaluate Opportunity (Phase 11 API remains unchanged)
    final opportunity = MitraOpportunity(
      event: event,
      personalityDecision: personalityDecision,
      contextSnapshot: MitraContextSnapshot(
        currentScreen: MitraAppScreen.home,
        previousScreen: MitraAppScreen.unknown,
        currentActivity: MitraUserActivity.idle,
        lifecycleState: MitraAppLifecycle.foreground,
        sessionStartTime: DateTime.now().subtract(const Duration(minutes: 30)),
        lastUserInteractionTime: DateTime.now().subtract(const Duration(seconds: 10)),
        timeOfDay: MitraTimeOfDay.morning,
        timeSinceLastInteraction: const Duration(seconds: 10),
        isRestTimerActive: _isRestTimerActive,
      ),
    );
    
    final attentionDecision = _attentionEngine.evaluate(opportunity, DateTime.now());
    if (attentionDecision.interruptionRisk == MitraInterruptionRisk.critical ||
        attentionDecision.interruptionRisk == MitraInterruptionRisk.high) {
      return;
    }

    // 5. Confirm Phase 6 SUNFLOWER behaviour (cooldown & anti-repetition check)
    final behaviourState = behaviourKey?.currentState;
    if (behaviourState != null) {
      if (behaviourState.getRemainingCooldown(MitraBehaviourCategory.sunflower) > Duration.zero) {
        return;
      }
      behaviourState.mitraContext.recordBehaviour(MitraBehaviourCategory.sunflower);
    }

    // 6. Tier Selection
    final tier = _determineTier(personalityDecision);
    if (tier == MitraSunflowerInteractionTier.none) return;

    // 7. Invoke Canonical Sequence
    final interactionState = interactionKey.currentState;
    if (interactionState == null) return;
    
    if (interactionState.currentMitraState != MitraState.idle && 
        interactionState.currentMitraState != MitraState.sunflowerNotice &&
        !interactionState.currentMitraState.name.contains('sunflower')) {
      return;
    }

    await interactionState.playNoticeSequence();
  }

  MitraEvent _mapToSemanticEvent(MitraSunflowerInteractionSignal signal) {
    if (signal.isMilestone) {
      return MitraEvent(MitraEventType.achievement); // maps to special
    } else if (signal.progressChange >= 0.3) {
      return MitraEvent(MitraEventType.workoutCompleted); // maps to important
    } else if (signal.progressChange > 0.0) {
      return MitraEvent(MitraEventType.userReturn); // maps to meaningful
    }
    return MitraEvent(MitraEventType.manualInteraction); // maps to trivial
  }

  MitraSunflowerInteractionTier _determineTier(MitraPersonalityDecision decision) {
    if (!decision.shouldReact) return MitraSunflowerInteractionTier.none;
    
    switch (decision.significance) {
      case MitraEventSignificance.trivial:
        return MitraSunflowerInteractionTier.microNotice;
      case MitraEventSignificance.meaningful:
        return MitraSunflowerInteractionTier.observe;
      case MitraEventSignificance.important:
        return MitraSunflowerInteractionTier.full;
      case MitraEventSignificance.special:
        return MitraSunflowerInteractionTier.special;
    }
  }

  int _determineReactionAction(String transitionName) {
    final double r = _random.nextDouble();
    switch (transitionName) {
      case 'WAKE':
        // Notice (8): high, Lean (3): medium
        return r < 0.6 ? 8 : 3;
      case 'GROW':
        // Proud (4): high, Bounce (2): medium, Lean (3): medium
        if (r < 0.5) return 4;
        if (r < 0.75) return 2;
        return 3;
      case 'FLOURISH':
        // Shuffle (1): high, Bounce (2): medium, Notice (8): medium
        if (r < 0.4) return 1;
        if (r < 0.7) return 2;
        return 8;
      case 'BLOOM':
        // Proud (4): high, Dance (0): medium, Notice (8): low
        if (r < 0.5) return 4;
        if (r < 0.8) return 0;
        return 8;
      case 'EXCEPTIONAL_BLOOM':
        // Bloom Celebration (5): very high, Proud (4): medium, Dance (0): medium
        if (r < 0.6) return 5;
        if (r < 0.8) return 4;
        return 0;
      default:
        return -1;
    }
  }

  Future<void> onSunflowerTransition(MitraSunflowerAnimationTransition transition) async {
    // Only react to positive growth transitions
    if (transition.name == 'RESET' || transition.name == 'REST' || transition.name == 'SETTLE' || transition.name == 'IDLE') {
      return;
    }

    final int currentGen = ++_reactionGeneration;

    // CHOREOGRAPHY: 1500ms visual growth transition + 500ms stillness before reacting
    await Future.delayed(const Duration(milliseconds: 2000));
    
    // Safety check against stale events and unmounted engine
    if (currentGen != _reactionGeneration) return;
    if (behaviourKey?.currentState?.mounted != true) return;

    final MitraEvent? event = _mapTransitionToEvent(transition);
    if (event == null) return;

    // Evaluate Personality (Handles Deduplication/Cooldown automatically via MitraPersonalityContext)
    final personalityDecision = _personalityEngine.evaluate(event);
    if (!personalityDecision.shouldReact) return;

    // Evaluate Opportunity
    final opportunity = MitraOpportunity(
      event: event,
      personalityDecision: personalityDecision,
      contextSnapshot: MitraContextSnapshot(
        currentScreen: MitraAppScreen.home,
        previousScreen: MitraAppScreen.unknown,
        currentActivity: MitraUserActivity.idle,
        lifecycleState: MitraAppLifecycle.foreground,
        sessionStartTime: DateTime.now().subtract(const Duration(minutes: 30)),
        lastUserInteractionTime: DateTime.now().subtract(const Duration(seconds: 10)),
        timeOfDay: MitraTimeOfDay.morning,
        timeSinceLastInteraction: const Duration(seconds: 10),
        isRestTimerActive: _isRestTimerActive,
      ),
    );
    
    final attentionDecision = _attentionEngine.evaluate(opportunity, DateTime.now());
    if (attentionDecision.interruptionRisk == MitraInterruptionRisk.critical ||
        attentionDecision.interruptionRisk == MitraInterruptionRisk.high) {
      return;
    }

    // Confirm Phase 6 SUNFLOWER behaviour (cooldown & anti-repetition check)
    final behaviourState = behaviourKey?.currentState;
    if (behaviourState != null) {
      if (behaviourState.getRemainingCooldown(MitraBehaviourCategory.sunflower) > Duration.zero) {
        return;
      }
      behaviourState.mitraContext.recordBehaviour(MitraBehaviourCategory.sunflower);
    }

    final interactionState = interactionKey.currentState;
    if (interactionState == null) return;
    
    if (interactionState.currentMitraState != MitraState.idle && 
        interactionState.currentMitraState != MitraState.sunflowerNotice &&
        !interactionState.currentMitraState.name.contains('sunflower')) {
      return;
    }

    // PHASE 28: DIORAMA CHOREOGRAPHY
    final int actionId = _determineReactionAction(transition.name);
    if (actionId == -2) {
      await interactionState.playNoticeSequence();
    } else if (actionId >= 0) {
      await interactionState.playIdleAction(actionId);
    }
  }

  MitraEvent? _mapTransitionToEvent(MitraSunflowerAnimationTransition transition) {
    switch (transition.name) {
      case 'EXCEPTIONAL_BLOOM':
      case 'BLOOM':
        return MitraEvent(MitraEventType.achievement); // special significance
      case 'FLOURISH':
      case 'GROW':
        return MitraEvent(MitraEventType.workoutCompleted); // important significance
      case 'WAKE':
        return MitraEvent(MitraEventType.userReturn); // meaningful significance
      default:
        return null;
    }
  }
}
