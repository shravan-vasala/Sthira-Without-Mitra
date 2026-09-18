const bool kEnableAiProfiling = bool.fromEnvironment('AI_PROFILE', defaultValue: false);

class AiProfileSession {
  final Map<String, Stopwatch> _timers = {};
  final Map<String, int> phaseMs = {};
  
  String? modelUsed;
  int attemptCount = 0;
  int imageCount = 0;
  int totalBytesSent = 0;
  int promptChars = 0;
  
  int? promptTokenCount;
  int? candidatesTokenCount;
  int? thoughtsTokenCount;
  int? cachedContentTokenCount;

  void startPhase(String phaseName) {
    if (!kEnableAiProfiling) return;
    _timers[phaseName] = Stopwatch()..start();
  }

  void endPhase(String phaseName) {
    if (!kEnableAiProfiling) return;
    final timer = _timers[phaseName];
    if (timer != null) {
      timer.stop();
      phaseMs[phaseName] = (phaseMs[phaseName] ?? 0) + timer.elapsedMilliseconds;
    }
  }

  // Pre-aggregated summary for logging/benchmarking
  Map<String, dynamic> toMap() {
    return {
      'pickMs': phaseMs['pickMs'],
      'fileReadMs': phaseMs['fileReadMs'],
      'preprocessMs': phaseMs['preprocessMs'],
      'hashMs': phaseMs['hashMs'],
      'cacheLookupMs': phaseMs['cacheLookupMs'],
      'networkMs': phaseMs['networkMs'],
      'parseMs': phaseMs['parseMs'],
      'cacheWriteMs': phaseMs['cacheWriteMs'],
      'nutritionLoadMs': phaseMs['nutritionLoadMs'],
      'nutritionMatchMs': phaseMs['nutritionMatchMs'],
      'totalMs': phaseMs['totalMs'],
      'modelUsed': modelUsed,
      'attemptCount': attemptCount,
      'imageCount': imageCount,
      'totalBytesSent': totalBytesSent,
      'promptChars': promptChars,
      'promptTokenCount': promptTokenCount,
      'candidatesTokenCount': candidatesTokenCount,
      'thoughtsTokenCount': thoughtsTokenCount,
      'cachedContentTokenCount': cachedContentTokenCount,
    };
  }
}

class AiProfiler {
  static final AiProfiler _instance = AiProfiler._internal();
  factory AiProfiler() => _instance;
  AiProfiler._internal();

  AiProfileSession? currentSession;
  
  // Optional listener for benchmarking without touching UI
  void Function(AiProfileSession session)? onSessionComplete;

  void startSession() {
    if (!kEnableAiProfiling) return;
    currentSession = AiProfileSession();
    currentSession!.startPhase('totalMs');
  }

  void endSession() {
    if (!kEnableAiProfiling || currentSession == null) return;
    currentSession!.endPhase('totalMs');
    onSessionComplete?.call(currentSession!);
    currentSession = null;
  }

  void startPhase(String phaseName) {
    currentSession?.startPhase(phaseName);
  }

  void endPhase(String phaseName) {
    currentSession?.endPhase(phaseName);
  }

  void recordMetadata({
    String? modelUsed,
    int? attemptCount,
    int? imageCount,
    int? totalBytesSent,
    int? promptChars,
    int? promptTokenCount,
    int? candidatesTokenCount,
    int? thoughtsTokenCount,
    int? cachedContentTokenCount,
  }) {
    if (currentSession == null) return;
    if (modelUsed != null) currentSession!.modelUsed = modelUsed;
    if (attemptCount != null) currentSession!.attemptCount = attemptCount;
    if (imageCount != null) currentSession!.imageCount = imageCount;
    if (totalBytesSent != null) currentSession!.totalBytesSent = totalBytesSent;
    if (promptChars != null) currentSession!.promptChars = promptChars;
    if (promptTokenCount != null) currentSession!.promptTokenCount = promptTokenCount;
    if (candidatesTokenCount != null) currentSession!.candidatesTokenCount = candidatesTokenCount;
    if (thoughtsTokenCount != null) currentSession!.thoughtsTokenCount = thoughtsTokenCount;
    if (cachedContentTokenCount != null) currentSession!.cachedContentTokenCount = cachedContentTokenCount;
  }
}
