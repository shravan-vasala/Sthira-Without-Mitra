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
        // We have servings but basis is per100g. We must know the serving size in grams to convert.
        if (servingGrams != null && servingGrams > 0) {
          multiplier = (consumedServings * servingGrams) / 100.0;
        } else {
          // Cannot convert safely. Assume 1 serving = 100g as fallback or just 1:1.
          multiplier = consumedServings;
        }
      }
    } else {
      // Basis is per-serving
      if (consumedServings != null) {
        multiplier = consumedServings;
      } else if (consumedGrams != null) {
        // We have grams, but basis is per-serving. We must know serving size.
        if (servingGrams != null && servingGrams > 0) {
          multiplier = consumedGrams / servingGrams;
        } else {
          // Cannot convert safely. DO NOT GUESS 100g! Assume 1 multiplier to avoid silent errors.
          multiplier = 1.0;
        }
      }
    }

    return FoodNutrition(
      kcal: baseNutrition.kcal * multiplier,
      proteinG: baseNutrition.proteinG * multiplier,
      carbsG: baseNutrition.carbsG * multiplier,
      fatG: baseNutrition.fatG * multiplier,
    );
  }
}
