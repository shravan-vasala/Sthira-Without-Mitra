import 'mitra_sunflower.dart';

enum SupportingWellnessContext {
  neutral,
  supportive,
  strong,
}

class MitraSunflowerProgress {
  final double coreProgress; // 0.0 to 1.0
  final SupportingWellnessContext supportingContext;
  final MitraDailyProgressCategory category;
  
  // Legacy fields preserved temporarily for existing Debug Lab callers
  final int stepsContribution;
  final int waterContribution;
  final int sleepContribution;
  final int workoutContribution;
  final int habitContribution;
  final int nutritionContribution;

  const MitraSunflowerProgress({
    this.coreProgress = 0.0,
    this.supportingContext = SupportingWellnessContext.neutral,
    this.category = MitraDailyProgressCategory.none,
    this.stepsContribution = 0,
    this.waterContribution = 0,
    this.sleepContribution = 0,
    this.workoutContribution = 0,
    this.habitContribution = 0,
    this.nutritionContribution = 0,
  });

  // Legacy additive sum
  int get totalContribution => 
      stepsContribution + 
      waterContribution + 
      sleepContribution + 
      workoutContribution + 
      habitContribution + 
      nutritionContribution;

  MitraSunflowerProgress copyWith({
    double? coreProgress,
    SupportingWellnessContext? supportingContext,
    MitraDailyProgressCategory? category,
    int? stepsContribution,
    int? waterContribution,
    int? sleepContribution,
    int? workoutContribution,
    int? habitContribution,
    int? nutritionContribution,
  }) {
    return MitraSunflowerProgress(
      coreProgress: coreProgress ?? this.coreProgress,
      supportingContext: supportingContext ?? this.supportingContext,
      category: category ?? this.category,
      stepsContribution: stepsContribution ?? this.stepsContribution,
      waterContribution: waterContribution ?? this.waterContribution,
      sleepContribution: sleepContribution ?? this.sleepContribution,
      workoutContribution: workoutContribution ?? this.workoutContribution,
      habitContribution: habitContribution ?? this.habitContribution,
      nutritionContribution: nutritionContribution ?? this.nutritionContribution,
    );
  }
}
