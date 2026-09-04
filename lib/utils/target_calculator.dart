class TargetMacros {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;

  TargetMacros({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

class TargetCalculator {
  /// Calculate suggested targets using Mifflin-St Jeor equation.
  static TargetMacros calculate({
    required double heightCm,
    required double? weightKg,
    required int? age,
    required String? gender,
    required String? goal,
    required String? activityLevel,
  }) {
    final weight = weightKg ?? 70.0;
    final a = age ?? 30;
    final isMale = (gender ?? 'M').toUpperCase() == 'M';

    // Mifflin-St Jeor BMR
    double bmr = (10 * weight) + (6.25 * heightCm) - (5 * a);
    bmr += isMale ? 5 : -161;

    // Activity multiplier
    double multiplier = 1.2; // Sedentary
    switch (activityLevel?.toLowerCase()) {
      case 'lightly active':
      case 'light':
        multiplier = 1.375;
        break;
      case 'moderately active':
      case 'moderate':
        multiplier = 1.55;
        break;
      case 'very active':
      case 'active':
        multiplier = 1.725;
        break;
      case 'extra active':
        multiplier = 1.9;
        break;
    }

    double tdee = bmr * multiplier;

    // Goal adjustment
    if (goal != null) {
      if (goal.toLowerCase().contains('lose')) {
        tdee *= 0.8; // -20%
      } else if (goal.toLowerCase().contains('gain') || goal.toLowerCase().contains('build')) {
        tdee *= 1.1; // +10%
      }
    }

    int targetCalories = tdee.round();
    if (targetCalories < 1200) targetCalories = 1200;

    // Macros:
    // Protein: 1.8g / kg
    double protein = weight * 1.8;
    
    // Fat: 25% of total calories
    double fat = (targetCalories * 0.25) / 9;

    // Carbs: remainder
    double caloriesFromProtein = protein * 4;
    double caloriesFromFat = fat * 9;
    double carbs = (targetCalories - caloriesFromProtein - caloriesFromFat) / 4;
    if (carbs < 0) carbs = 0;

    return TargetMacros(
      calories: targetCalories,
      proteinG: _roundToNearest5(protein),
      fatG: _roundToNearest5(fat),
      carbsG: _roundToNearest5(carbs),
    );
  }

  static int _roundToNearest5(double value) {
    return (value / 5).round() * 5;
  }
}
