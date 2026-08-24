import 'mitra_event.dart';
import 'mitra_personality.dart';
import 'mitra_personality_context.dart';
import 'mitra_personality_decision.dart';

class MitraPersonalityEngine {
  final MitraPersonalityContext _context = MitraPersonalityContext();

  MitraPersonalityContext get context => _context;

  MitraPersonalityDecision evaluate(MitraEvent event) {
    final significance = _mapSignificance(event);
    
    // Evaluate Anti-Annoyance logic
    final suppressionResult = _evaluateSuppression(significance);
    if (suppressionResult.isSuppressed) {
      return MitraPersonalityDecision(
        event: event,
        significance: significance,
        emotionalState: suppressionResult.state,
        intensity: MitraReactionIntensity.silent,
        shouldReact: false,
        reason: suppressionResult.reason,
      );
    }

    // Determine target emotion and intensity based on significance and context
    final stateAndIntensity = _determineEmotionAndIntensity(event, significance);
    
    // Finalize decision
    final decision = MitraPersonalityDecision(
      event: event,
      significance: significance,
      emotionalState: stateAndIntensity.state,
      intensity: stateAndIntensity.intensity,
      shouldReact: true,
      reason: stateAndIntensity.reason,
    );

    // Update context
    _context.recordReaction(significance, decision.intensity, decision.emotionalState);
    
    return decision;
  }

  MitraEventSignificance _mapSignificance(MitraEvent event) {
    switch (event.type) {
      case MitraEventType.navigationIdle:
        return MitraEventSignificance.trivial;
      case MitraEventType.notice:
        return MitraEventSignificance.trivial;
      case MitraEventType.manualInteraction:
        return MitraEventSignificance.trivial;
      case MitraEventType.userReturn:
        return MitraEventSignificance.meaningful;
      case MitraEventType.workoutCompleted:
        return MitraEventSignificance.important;
      case MitraEventType.achievement:
        return MitraEventSignificance.special; // Assuming achievement is a milestone here
    }
  }

  _SuppressionResult _evaluateSuppression(MitraEventSignificance significance) {
    switch (significance) {
      case MitraEventSignificance.trivial:
        if (_context.hasReactedRecently(MitraEventSignificance.trivial, const Duration(minutes: 5))) {
          return _SuppressionResult(true, MitraEmotionalState.resting, 'Trivial reaction occurred within the last 5 minutes.');
        }
        break;
      case MitraEventSignificance.meaningful:
        if (_context.hasReactedRecently(MitraEventSignificance.meaningful, const Duration(seconds: 60))) {
          return _SuppressionResult(true, MitraEmotionalState.resting, 'Meaningful reaction occurred within the last 60 seconds.');
        }
        break;
      case MitraEventSignificance.important:
        if (_context.hasReactedRecently(MitraEventSignificance.important, const Duration(seconds: 15))) {
          return _SuppressionResult(true, MitraEmotionalState.resting, 'Important reaction occurred within the last 15 seconds.');
        }
        break;
      case MitraEventSignificance.special:
        // Special events generally bypass suppression
        break;
    }
    return _SuppressionResult(false, MitraEmotionalState.calm, '');
  }

  _EmotionResult _determineEmotionAndIntensity(MitraEvent event, MitraEventSignificance significance) {
    switch (significance) {
      case MitraEventSignificance.trivial:
        return _EmotionResult(
          MitraEmotionalState.curious,
          MitraReactionIntensity.micro,
          'Trivial event allowed after cooldown. Curiosity piqued.',
        );
      case MitraEventSignificance.meaningful:
        if (event.type == MitraEventType.userReturn) {
          return _EmotionResult(
            MitraEmotionalState.encouraging,
            MitraReactionIntensity.warm,
            'User returned. Warmly encouraging presence.',
          );
        }
        return _EmotionResult(
          MitraEmotionalState.encouraging,
          MitraReactionIntensity.warm,
          'Meaningful event. Providing warm encouragement.',
        );
      case MitraEventSignificance.important:
        return _EmotionResult(
          MitraEmotionalState.proud,
          MitraReactionIntensity.celebration, // Or warm depending on momentum
          'Important event. Feeling proud.',
        );
      case MitraEventSignificance.special:
        return _EmotionResult(
          MitraEmotionalState.celebratory,
          MitraReactionIntensity.special,
          'Special event detected. Full celebration.',
        );
    }
  }
}

class _SuppressionResult {
  final bool isSuppressed;
  final MitraEmotionalState state;
  final String reason;
  _SuppressionResult(this.isSuppressed, this.state, this.reason);
}

class _EmotionResult {
  final MitraEmotionalState state;
  final MitraReactionIntensity intensity;
  final String reason;
  _EmotionResult(this.state, this.intensity, this.reason);
}
