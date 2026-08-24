class DailyLog {
  final String date; // yyyy-MM-dd
  final double? weight;
  final int? steps;
  final String? stepsSource; // 'healthConnect' | 'manual' | null
  final double? sleepHours;
  final String? sleepSource; // 'healthConnect' | 'manual' | null
  final double? bodyFat;
  final bool workoutCompleted;
  final String? workoutDayId;
  final int? waterMl;
  final int? screenTimeMinutes;
  final DateTime? updatedAt;

  DailyLog({
    required this.date,
    this.weight,
    this.steps,
    this.stepsSource,
    this.sleepHours,
    this.sleepSource,
    this.bodyFat,
    this.workoutCompleted = false,
    this.workoutDayId,
    this.waterMl,
    this.screenTimeMinutes,
    this.updatedAt,
  });

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    return DailyLog(
      date: json['date'] as String,
      weight: (json['weight'] as num?)?.toDouble(),
      steps: json['steps'] as int?,
      stepsSource: json['stepsSource'] as String?,
      sleepHours: (json['sleepHours'] as num?)?.toDouble(),
      sleepSource: json['sleepSource'] as String?,
      bodyFat: (json['bodyFat'] as num?)?.toDouble(),
      workoutCompleted: json['workoutCompleted'] as bool? ?? false,
      workoutDayId: json['workoutDayId'] as String?,
      waterMl: json['waterMl'] as int?,
      screenTimeMinutes: json['screenTimeMinutes'] as int?,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        if (weight != null) 'weight': weight,
        if (steps != null) 'steps': steps,
        if (stepsSource != null) 'stepsSource': stepsSource,
        if (sleepHours != null) 'sleepHours': sleepHours,
        if (sleepSource != null) 'sleepSource': sleepSource,
        if (bodyFat != null) 'bodyFat': bodyFat,
        'workoutCompleted': workoutCompleted,
        if (workoutDayId != null) 'workoutDayId': workoutDayId,
        if (waterMl != null) 'waterMl': waterMl,
        if (screenTimeMinutes != null) 'screenTimeMinutes': screenTimeMinutes,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  DailyLog copyWith({
    double? weight,
    int? steps,
    String? stepsSource,
    double? sleepHours,
    String? sleepSource,
    double? bodyFat,
    bool? workoutCompleted,
    String? workoutDayId,
    int? waterMl,
    int? screenTimeMinutes,
    DateTime? updatedAt,
  }) {
    return DailyLog(
      date: date,
      weight: weight ?? this.weight,
      steps: steps ?? this.steps,
      stepsSource: stepsSource ?? this.stepsSource,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepSource: sleepSource ?? this.sleepSource,
      bodyFat: bodyFat ?? this.bodyFat,
      workoutCompleted: workoutCompleted ?? this.workoutCompleted,
      workoutDayId: workoutDayId ?? this.workoutDayId,
      waterMl: waterMl ?? this.waterMl,
      screenTimeMinutes: screenTimeMinutes ?? this.screenTimeMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  DailyLog clearSleep() {
    return DailyLog(
      date: date,
      weight: weight,
      steps: steps,
      stepsSource: stepsSource,
      sleepHours: null,
      sleepSource: null,
      bodyFat: bodyFat,
      workoutCompleted: workoutCompleted,
      workoutDayId: workoutDayId,
      screenTimeMinutes: screenTimeMinutes,
      updatedAt: updatedAt,
    );
  }

  bool get hasAnyActivity =>
      weight != null ||
      steps != null ||
      sleepHours != null ||
      workoutCompleted ||
      screenTimeMinutes != null;
}
