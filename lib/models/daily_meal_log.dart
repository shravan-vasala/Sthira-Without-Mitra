import 'package:isar/isar.dart';

part 'daily_meal_log.g.dart';

@collection
class DailyMealLog {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  final String date; // yyyy-MM-dd

  @ignore
  Map<String, MealSlotLog> customSlots;

  List<CustomSlotEntry> get isarCustomSlots => customSlots.entries
      .map(
        (e) => CustomSlotEntry()
          ..key = e.key
          ..value = e.value,
      )
      .toList();
  set isarCustomSlots(List<CustomSlotEntry> list) {
    customSlots = {
      for (var e in list)
        if (e.key != null && e.value != null) e.key!: e.value!,
    };
  }

  DailyMealLog({required this.date, Map<String, MealSlotLog>? customSlots})
    : customSlots = customSlots ?? {};

  int get totalCalories =>
      customSlots.values.fold(0, (sum, slot) => sum + slot.totalCalories);

  double get totalProtein =>
      customSlots.values.fold(0, (sum, slot) => sum + slot.totalProtein);

  double get totalCarbs =>
      customSlots.values.fold(0, (sum, slot) => sum + slot.totalCarbs);

  double get totalFat =>
      customSlots.values.fold(0, (sum, slot) => sum + slot.totalFat);

  int get loggedSlotsCount => customSlots.values
      .where(
        (s) => s.items.isNotEmpty || s.photoPath != null || s.totalCalories > 0,
      )
      .length;

  factory DailyMealLog.fromJson(Map<String, dynamic> json) {
    final Map<String, MealSlotLog> slots = {};

    // Legacy fields migration
    if (json['breakfast'] != null)
      slots['breakfast'] = MealSlotLog.fromJson(
        json['breakfast'] as Map<String, dynamic>,
      );
    if (json['lunch'] != null)
      slots['lunch'] = MealSlotLog.fromJson(
        json['lunch'] as Map<String, dynamic>,
      );
    if (json['snack'] != null)
      slots['snack'] = MealSlotLog.fromJson(
        json['snack'] as Map<String, dynamic>,
      );
    if (json['dinner'] != null)
      slots['dinner'] = MealSlotLog.fromJson(
        json['dinner'] as Map<String, dynamic>,
      );

    // New format
    if (json['customSlots'] != null) {
      final map = json['customSlots'] as Map<String, dynamic>;
      for (final entry in map.entries) {
        slots[entry.key] = MealSlotLog.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    return DailyMealLog(date: json['date'] as String, customSlots: slots);
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'customSlots': customSlots.map((k, v) => MapEntry(k, v.toJson())),
  };

  DailyMealLog copyWith({Map<String, MealSlotLog>? customSlots}) {
    return DailyMealLog(
      date: date,
      customSlots: customSlots ?? this.customSlots,
    );
  }
}

@embedded
class CustomSlotEntry {
  String? key;
  MealSlotLog? value;
}

@embedded
class MealSlotLog {
  String? name;
  String? emoji;
  String? photoPath;
  List<MealItemLog> items;
  int totalCalories;
  double totalProtein;
  double totalCarbs;
  double totalFat;
  String? confidence; // "high", "medium", "low"

  MealSlotLog({
    this.name,
    this.emoji,
    this.photoPath,
    this.items = const [],
    this.totalCalories = 0,
    this.totalProtein = 0.0,
    this.totalCarbs = 0.0,
    this.totalFat = 0.0,
    this.confidence,
  });

  factory MealSlotLog.fromJson(Map<String, dynamic> json) {
    return MealSlotLog(
      name: json['name'] as String?,
      emoji: json['emoji'] as String?,
      photoPath: json['photoPath'] as String?,
      items:
          (json['items'] as List?)
              ?.map((i) => MealItemLog.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      totalCalories: json['totalCalories'] as int? ?? 0,
      totalProtein: (json['totalProtein'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (json['totalCarbs'] as num?)?.toDouble() ?? 0.0,
      totalFat: (json['totalFat'] as num?)?.toDouble() ?? 0.0,
      confidence: json['confidence'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (emoji != null) 'emoji': emoji,
    if (photoPath != null) 'photoPath': photoPath,
    'items': items.map((i) => i.toJson()).toList(),
    'totalCalories': totalCalories,
    'totalProtein': totalProtein,
    'totalCarbs': totalCarbs,
    'totalFat': totalFat,
    if (confidence != null) 'confidence': confidence,
  };
}

@embedded
class MealItemLog {
  String? name;
  String? portion;
  int? calories;
  double? proteinG;
  double? carbsG;
  double? fatG;
  bool resolved;

  MealItemLog({
    this.name,
    this.portion,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.resolved = true,
  });

  factory MealItemLog.fromJson(Map<String, dynamic> json) {
    return MealItemLog(
      name: json['name'] as String? ?? 'Unknown',
      portion: json['portion'] as String? ?? '',
      calories: json['calories'] as int? ?? 0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
      resolved: json['resolved'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'portion': portion,
    'calories': calories,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    'resolved': resolved,
  };
}
