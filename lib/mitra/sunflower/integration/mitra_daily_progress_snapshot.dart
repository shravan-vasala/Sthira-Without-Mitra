import '../mitra_sunflower_progress.dart';

enum DataAvailability {
  complete,
  partial,
  unknown,
}

class MitraDailyProgressSnapshot {
  final DateTime date;
  final double coreDailyProgress; // 0.0 to 1.0
  final SupportingWellnessContext supportingContext;
  
  final double normalizedSteps;
  final double normalizedWater;
  final double normalizedSleep;
  
  final DataAvailability availability;

  const MitraDailyProgressSnapshot({
    required this.date,
    required this.coreDailyProgress,
    required this.supportingContext,
    required this.normalizedSteps,
    required this.normalizedWater,
    required this.normalizedSleep,
    required this.availability,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MitraDailyProgressSnapshot &&
        other.date == date &&
        other.coreDailyProgress == coreDailyProgress &&
        other.supportingContext == supportingContext &&
        other.normalizedSteps == normalizedSteps &&
        other.normalizedWater == normalizedWater &&
        other.normalizedSleep == normalizedSleep &&
        other.availability == availability;
  }

  @override
  int get hashCode {
    return date.hashCode ^
        coreDailyProgress.hashCode ^
        supportingContext.hashCode ^
        normalizedSteps.hashCode ^
        normalizedWater.hashCode ^
        normalizedSleep.hashCode ^
        availability.hashCode;
  }
}
