import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../widgets/mitra_interaction_engine.dart';
import 'mitra_event.dart';
import 'mitra_context.dart';
import 'mitra_behaviour.dart';
import 'attention/mitra_attention_engine.dart';
import 'attention/mitra_opportunity.dart';
import 'context/mitra_context_snapshot.dart';
import 'context/mitra_context_types.dart';
import 'mitra_personality_decision.dart';
import 'mitra_personality.dart';
import 'attention/mitra_attention.dart';

class MitraBehaviourEngine extends StatefulWidget {
  final double size;
  final bool showDebugBounds;
  final bool isHomeScreen;
  final void Function(MitraBehaviourCategory)? onAction;

  const MitraBehaviourEngine({
    super.key,
    required this.size,
    this.showDebugBounds = false,
    this.isHomeScreen = true,
    this.onAction,
  });

  @override
  State<MitraBehaviourEngine> createState() => MitraBehaviourEngineState();
}

class MitraBehaviourEngineState extends State<MitraBehaviourEngine> {
  final GlobalKey<MitraInteractionEngineState> _interactionKey = GlobalKey<MitraInteractionEngineState>();
  final Random _random = Random();
  final MitraContext _context = MitraContext();
  final MitraAttentionEngine _attentionEngine = MitraAttentionEngine();
  
  Timer? _idleTimer;

  MitraBehaviourState _behaviourState = MitraBehaviourState.idle;
  MitraBehaviourCategory _currentBehaviour = MitraBehaviourCategory.idle;
  MitraBehaviourPriority _currentPriority = MitraBehaviourPriority.idle;
  MitraEvent? _lastEvent;
  int _behaviourRunId = 0;

  // Debug Getters
  MitraBehaviourState get behaviourState => _behaviourState;
  MitraBehaviourCategory get currentBehaviour => _currentBehaviour;
  MitraBehaviourPriority get currentPriority => _currentPriority;
  MitraEvent? get lastEvent => _lastEvent;
  MitraContext get mitraContext => _context;
  MitraState? get currentInteractionState => _interactionKey.currentState?.currentMitraState;
  GlobalKey<MitraInteractionEngineState> get interactionKey => _interactionKey;

  @override
  void initState() {
    super.initState();
    _scheduleNextIdleCheck();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _scheduleNextIdleCheck() {
    _idleTimer?.cancel();
    if (!mounted) return;
    // 15-25 seconds evaluation window
    final delay = Duration(seconds: 15 + _random.nextInt(11));
    _idleTimer = Timer(delay, _onIdleTimerTick);
  }

  void _onIdleTimerTick() {
    if (!mounted) return;
    _scheduleNextIdleCheck(); // schedule next tick
    
    // Evaluate Attention safely before dispatching
    final opportunity = MitraOpportunity(
      event: MitraEvent(MitraEventType.navigationIdle),
      personalityDecision: MitraPersonalityDecision(
        event: MitraEvent(MitraEventType.navigationIdle),
        shouldReact: true,
        reason: 'Periodic idle check',
        significance: MitraEventSignificance.trivial,
        emotionalState: MitraEmotionalState.resting,
        intensity: MitraReactionIntensity.silent,
      ),
      contextSnapshot: MitraContextSnapshot(
        currentScreen: MitraAppScreen.home,
        previousScreen: MitraAppScreen.unknown,
        currentActivity: MitraUserActivity.idle,
        lifecycleState: MitraAppLifecycle.foreground,
        sessionStartTime: DateTime.now().subtract(const Duration(minutes: 30)),
        lastUserInteractionTime: DateTime.now().subtract(const Duration(seconds: 15)),
        timeOfDay: MitraTimeOfDay.morning,
        timeSinceLastInteraction: const Duration(seconds: 15),
        isRestTimerActive: false, // We assume false, the interaction engine itself will be suppressed by IgnorePointer but visually we don't want to dance during rest timer. Actually, RestTimer sets a global state.
      ),
    );

    final attention = _attentionEngine.evaluate(opportunity, DateTime.now());
    if (attention.interruptionRisk == MitraInterruptionRisk.critical || 
        attention.interruptionRisk == MitraInterruptionRisk.high) {
      return;
    }

    dispatch(MitraEvent(MitraEventType.navigationIdle));
  }

  // Cooldown definitions
  Duration _getCooldownFor(MitraBehaviourCategory category) {
    switch (category) {
      case MitraBehaviourCategory.peek: return const Duration(seconds: 45);
      case MitraBehaviourCategory.sunflower: return const Duration(minutes: 5);
      case MitraBehaviourCategory.achievement: return const Duration(seconds: 30); // Fast cooldown for user goals
      case MitraBehaviourCategory.notice: return const Duration(minutes: 5);
      case MitraBehaviourCategory.idle: return Duration.zero;
      case MitraBehaviourCategory.mischief: return const Duration(seconds: 90);
      case MitraBehaviourCategory.dance: return const Duration(minutes: 2);
      case MitraBehaviourCategory.shuffle: return const Duration(seconds: 30);
      case MitraBehaviourCategory.bounce: return const Duration(seconds: 30);
      case MitraBehaviourCategory.lean: return const Duration(seconds: 45);
      case MitraBehaviourCategory.proud: return const Duration(minutes: 5);
      case MitraBehaviourCategory.bloomCelebration: return const Duration(minutes: 10);
      case MitraBehaviourCategory.walkLeft: return const Duration(seconds: 60);
      case MitraBehaviourCategory.walkRight: return const Duration(seconds: 60);
      case MitraBehaviourCategory.noticeSunflower: return const Duration(minutes: 2);
      case MitraBehaviourCategory.peekHi: return const Duration(minutes: 5);
      case MitraBehaviourCategory.popInLeft: return const Duration(minutes: 2);
      case MitraBehaviourCategory.popInRight: return const Duration(minutes: 2);
    }
  }

  bool _isBehaviourOnCooldown(MitraBehaviourCategory category) {
    final lastExecution = _context.lastExecutionTimes[category];
    if (lastExecution == null) return false;
    final elapsed = DateTime.now().difference(lastExecution);
    return elapsed < _getCooldownFor(category);
  }

  Duration getRemainingCooldown(MitraBehaviourCategory category) {
    final lastExecution = _context.lastExecutionTimes[category];
    if (lastExecution == null) return Duration.zero;
    final elapsed = DateTime.now().difference(lastExecution);
    final total = _getCooldownFor(category);
    return elapsed > total ? Duration.zero : total - elapsed;
  }

  /// Entry point for external app events
  void dispatch(MitraEvent event) {
    if (!mounted) return;
    
    // 1. Is Mitra currently busy? 
    // 2. Priority check
    final incomingPriority = _getPriorityForEvent(event);
    if (_behaviourState != MitraBehaviourState.idle && incomingPriority.value <= _currentPriority.value) {
      // Ignore lower or equal priority events if busy
      return; 
    }

    setState(() {
      _lastEvent = event;
      _behaviourState = MitraBehaviourState.evaluating;
    });

    _evaluateAndPlay(event, incomingPriority);
  }

  MitraBehaviourPriority _getPriorityForEvent(MitraEvent event) {
    switch (event.type) {
      case MitraEventType.workoutCompleted:
      case MitraEventType.achievement:
        return MitraBehaviourPriority.achievement;
      case MitraEventType.manualInteraction:
        return MitraBehaviourPriority.critical;
      case MitraEventType.userReturn:
        return MitraBehaviourPriority.contextual;
      case MitraEventType.notice:
      case MitraEventType.navigationIdle:
        return MitraBehaviourPriority.opportunistic;
    }
  }

  Future<void> _evaluateAndPlay(MitraEvent event, MitraBehaviourPriority priority) async {
    final int currentRunId = ++_behaviourRunId;
    MitraBehaviourCategory? selected;

    // Opportunity Gate for passive events
    if (event.type == MitraEventType.navigationIdle) {
      if (_random.nextDouble() < 0.60) {
        _returnToIdle(currentRunId); // 60% chance to remain completely idle (stillness)
        return;
      }
    }

    // Map Event to desired Category
    switch (event.type) {
      case MitraEventType.workoutCompleted:
      case MitraEventType.achievement:
        selected = MitraBehaviourCategory.achievement;
        break;
      case MitraEventType.userReturn:
        selected = MitraBehaviourCategory.peek; // contextual lean-in
        break;
      case MitraEventType.manualInteraction:
        selected = MitraBehaviourCategory.sunflower;
        break;
      case MitraEventType.notice:
        selected = MitraBehaviourCategory.notice;
        break;
      case MitraEventType.navigationIdle:
        // Weighted random selection for playful actions
        final Map<MitraBehaviourCategory, int> weights;
        
        if (widget.isHomeScreen) {
          weights = {
            MitraBehaviourCategory.shuffle: 10,
            MitraBehaviourCategory.bounce: 8,
            MitraBehaviourCategory.notice: 7,
            MitraBehaviourCategory.noticeSunflower: 5,
            MitraBehaviourCategory.walkLeft: 5,
            MitraBehaviourCategory.walkRight: 5,
            MitraBehaviourCategory.lean: 4,
            MitraBehaviourCategory.dance: 3,
            MitraBehaviourCategory.proud: 2,
            MitraBehaviourCategory.mischief: 1,
            MitraBehaviourCategory.peekHi: 1, // VERY RARE
          };
        } else {
          // Off-screen Pop-in behaviors only
          weights = {
            MitraBehaviourCategory.popInLeft: 10,
            MitraBehaviourCategory.popInRight: 10,
          };
        }
        
        // Filter out cooldowns and history
        final validCandidates = weights.keys.where((c) {
          if (_isBehaviourOnCooldown(c)) return false;
          if (_context.usedRecently(c, limit: 1)) return false; // Anti-repetition
          return true;
        }).toList();

        if (validCandidates.isEmpty) {
          _returnToIdle(currentRunId);
          return;
        }

        int totalWeight = validCandidates.fold(0, (sum, c) => sum + weights[c]!);
        int randomWeight = _random.nextInt(totalWeight);
        
        for (var c in validCandidates) {
          randomWeight -= weights[c]!;
          if (randomWeight < 0) {
            selected = c;
            break;
          }
        }
        selected ??= validCandidates.first;
        break;
    }

    if (selected == null) {
      _returnToIdle(currentRunId);
      return;
    }

    // Play Phase 5 Animation
    setState(() {
      _currentPriority = priority;
      _currentBehaviour = selected!;
      _behaviourState = MitraBehaviourState.playing;
    });
    
    _context.recordBehaviour(selected);
    widget.onAction?.call(selected);

    try {
      if (selected == MitraBehaviourCategory.peek) {
        await _interactionKey.currentState?.playPeekSequence();
      } else if (selected == MitraBehaviourCategory.sunflower) {
        // TEMPORARY FOR PHASE 1 TESTING: Trigger Peacock Grand Display on tap
        _interactionKey.currentState?.playPeacockGrandDisplay();
      } else if (selected == MitraBehaviourCategory.achievement) {
        await _interactionKey.currentState?.playProgressReactionSequence();
      } else if (selected == MitraBehaviourCategory.notice) {
        await _interactionKey.currentState?.playNoticeSequence();
      } else if (selected == MitraBehaviourCategory.mischief) {
        await _interactionKey.currentState?.playMischiefSequence(1);
      } else if (selected == MitraBehaviourCategory.dance) {
        await _interactionKey.currentState?.playIdleAction(0); // dance
      } else if (selected == MitraBehaviourCategory.shuffle) {
        await _interactionKey.currentState?.playIdleAction(1); // shuffle
      } else if (selected == MitraBehaviourCategory.bounce) {
        await _interactionKey.currentState?.playIdleAction(2); // bounce
      } else if (selected == MitraBehaviourCategory.lean) {
        await _interactionKey.currentState?.playIdleAction(3); // lean
      } else if (selected == MitraBehaviourCategory.proud) {
        await _interactionKey.currentState?.playIdleAction(4); // proud
      } else if (selected == MitraBehaviourCategory.bloomCelebration) {
        await _interactionKey.currentState?.playIdleAction(5); // bloomCelebration
      } else if (selected == MitraBehaviourCategory.walkLeft) {
        await _interactionKey.currentState?.playIdleAction(6); // walkLeft
      } else if (selected == MitraBehaviourCategory.walkRight) {
        await _interactionKey.currentState?.playIdleAction(7); // walkRight
      } else if (selected == MitraBehaviourCategory.noticeSunflower) {
        await _interactionKey.currentState?.playIdleAction(8); // noticeSunflower
      } else if (selected == MitraBehaviourCategory.peekHi) {
        await _interactionKey.currentState?.playIdleAction(9); // peekHi
      } else if (selected == MitraBehaviourCategory.popInLeft) {
        // Set starting X to -45 to be hidden off-screen left before popping in
        await _interactionKey.currentState?.playIdleAction(10); 
      } else if (selected == MitraBehaviourCategory.popInRight) {
        // Set starting X to screen width before popping in right (handled by caller or provider)
        await _interactionKey.currentState?.playIdleAction(11);
      }
    } finally {
      _returnToIdle(currentRunId);
    }
  }

  void _returnToIdle([int? runId]) {
    if (!mounted) return;
    if (runId != null && runId != _behaviourRunId) return;

    setState(() {
      _behaviourState = MitraBehaviourState.idle;
      _currentBehaviour = MitraBehaviourCategory.idle;
      _currentPriority = MitraBehaviourPriority.idle;
    });
  }
  
  void resetEngine() {
    _interactionKey.currentState?.reset();
    _returnToIdle();
  }

  @override
  Widget build(BuildContext context) {
    return MitraInteractionEngine(
      key: _interactionKey,
      size: widget.size,
      showDebugBounds: widget.showDebugBounds,
    );
  }
}
