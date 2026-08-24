import 'mitra_personality.dart';

class MitraPersonalityContext {
  DateTime? lastMeaningfulEvent;
  MitraReactionIntensity lastReactionIntensity = MitraReactionIntensity.silent;
  MitraEmotionalState currentMomentum = MitraEmotionalState.calm;
  
  final Map<MitraEventSignificance, DateTime> _lastReactionTimes = {};
  
  void recordReaction(MitraEventSignificance significance, MitraReactionIntensity intensity, MitraEmotionalState state) {
    _lastReactionTimes[significance] = DateTime.now();
    lastReactionIntensity = intensity;
    currentMomentum = state;
    if (significance == MitraEventSignificance.meaningful || 
        significance == MitraEventSignificance.important || 
        significance == MitraEventSignificance.special) {
      lastMeaningfulEvent = DateTime.now();
    }
  }

  DateTime? getLastReactionTime(MitraEventSignificance significance) {
    return _lastReactionTimes[significance];
  }

  bool hasReactedRecently(MitraEventSignificance significance, Duration window) {
    final lastTime = _lastReactionTimes[significance];
    if (lastTime == null) return false;
    return DateTime.now().difference(lastTime) < window;
  }
}
