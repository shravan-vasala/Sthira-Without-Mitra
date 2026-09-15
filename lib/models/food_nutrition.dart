import 'package:isar/isar.dart';

part 'food_nutrition.g.dart';

@embedded
class FoodNutrition {
  double kcal;
  double proteinG;
  double carbsG;
  double fatG;

  FoodNutrition({
    this.kcal = 0.0,
    this.proteinG = 0.0,
    this.carbsG = 0.0,
    this.fatG = 0.0,
  });

  factory FoodNutrition.fromJson(Map<String, dynamic> json) {
    return FoodNutrition(
      kcal: (json['kcal'] as num?)?.toDouble() ?? 0.0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'kcal': kcal,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
  };

  /// Compute the total macros/calories based on the consumed grams/servings and the nutrition basis
  static FoodNutrition compute({
    double? consumedGrams,
    double? consumedServings,
    required FoodNutrition baseNutrition,
    required bool isPer100g,
    double? servingGrams,
  }) {
    if ((consumedGrams == null || consumedGrams <= 0) &&
        (consumedServings == null || consumedServings <= 0)) {
      return FoodNutrition();
    }

    double multiplier = 1.0;

    if (isPer100g) {
      if (consumedGrams != null) {
        multiplier = consumedGrams / 100.0;
      } else if (consumedServings != null) {
        if (servingGrams != null && servingGrams > 0) {
          multiplier = (consumedServings * servingGrams) / 100.0;
        } else {
          // Cannot convert safely from servings to 100g basis without a defined serving mass.
          throw const FormatException(
            'Missing serving_grams for per-100g conversion.',
          );
        }
      }
    } else {
      // Basis is per-serving
      if (consumedServings != null && consumedGrams == null) {
        multiplier = consumedServings;
      } else if (consumedGrams != null) {
        if (servingGrams != null && servingGrams > 0) {
          multiplier = consumedGrams / servingGrams;
        } else {
          // Cannot convert safely from grams to per-serving basis without a defined serving mass.
          throw const FormatException(
            'Missing serving_grams for per-serving conversion.',
          );
        }
      }
    }

    return FoodNutrition(
      kcal: (baseNutrition.kcal * multiplier).clamp(0.0, 99999.0),
      proteinG: (baseNutrition.proteinG * multiplier).clamp(0.0, 9999.0),
      carbsG: (baseNutrition.carbsG * multiplier).clamp(0.0, 9999.0),
      fatG: (baseNutrition.fatG * multiplier).clamp(0.0, 9999.0),
    );
  }
}
