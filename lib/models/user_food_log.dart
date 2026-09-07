import 'package:isar/isar.dart';

part 'user_food_log.g.dart';

@collection
class UserFoodLog {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  final String normalizedName; // e.g., "idli", "sambar", "chicken curry"

  final String originalName;

  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  final bool isPer100g;
  final double? servingGrams;
  final String? provenance; // 'verified', 'estimated', 'yours'

  final DateTime addedAt;

  UserFoodLog({
    required this.normalizedName,
    required this.originalName,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.isPer100g = false,
    this.servingGrams,
    this.provenance,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
        'name': originalName,
        'kcal': kcal,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'is_per_100g': isPer100g,
        if (servingGrams != null) 'serving_grams': servingGrams,
        if (provenance != null) 'provenance': provenance,
      };
}
