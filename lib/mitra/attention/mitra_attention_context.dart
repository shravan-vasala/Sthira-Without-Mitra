import 'mitra_attention.dart';

class MitraAttentionContext {
  DateTime? lastOpportunityTime;
  DateTime? lastAcceptedOpportunityTime;
  DateTime? lastSuppressedOpportunityTime;
  MitraOpportunityType? lastOpportunityType;
  int consecutiveSuppressions = 0;
  DateTime? quietUntil;

  void recordOpportunity(DateTime time, MitraOpportunityType type) {
    lastOpportunityTime = time;
    lastOpportunityType = type;
  }

  void recordSuppression(DateTime time) {
    lastSuppressedOpportunityTime = time;
    consecutiveSuppressions++;
    
    // Gradual quiet period penalty based on consecutive opportunistic rejections
    if (consecutiveSuppressions > 3) {
      quietUntil = time.add(const Duration(minutes: 5));
    } else if (consecutiveSuppressions > 1) {
      quietUntil = time.add(const Duration(seconds: 30));
    }
  }

  void recordAccepted(DateTime time) {
    lastAcceptedOpportunityTime = time;
    consecutiveSuppressions = 0;
    quietUntil = null;
  }

  void reset() {
    lastOpportunityTime = null;
    lastAcceptedOpportunityTime = null;
    lastSuppressedOpportunityTime = null;
    lastOpportunityType = null;
    consecutiveSuppressions = 0;
    quietUntil = null;
  }
}
