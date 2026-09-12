class TargetParser {
  /// Parses a rep display string (e.g. "10-12", "12", "8 - 10") and returns the upper bound target.
  static int parseRepTarget(String repStr) {
    if (repStr.trim().isEmpty) return 0;
    
    if (repStr.contains('-')) {
      final parts = repStr.split('-');
      if (parts.length >= 2) {
        return int.tryParse(parts.last.trim()) ?? 0;
      }
    }
    
    final numMatch = RegExp(r'\d+').firstMatch(repStr);
    if (numMatch != null) {
      return int.parse(numMatch.group(0)!);
    }
    
    return 0;
  }
}
