class AiLogEntry {
  final DateTime timestamp;
  final String purpose;
  final String model;
  final int durationMs;
  final String outcome;

  AiLogEntry({
    required this.timestamp,
    required this.purpose,
    required this.model,
    required this.durationMs,
    required this.outcome,
  });
}

class AiLogger {
  static final List<AiLogEntry> logs = [];

  static void log({
    required String purpose,
    required String model,
    required int durationMs,
    required String outcome,
  }) {
    logs.insert(
      0,
      AiLogEntry(
        timestamp: DateTime.now(),
        purpose: purpose,
        model: model,
        durationMs: durationMs,
        outcome: outcome,
      ),
    );
    if (logs.length > 20) {
      logs.removeLast();
    }
  }
}
