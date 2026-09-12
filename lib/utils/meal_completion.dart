import '../models/user_profile.dart';
import '../models/daily_meal_log.dart';

class MealCompletion {
  /// Calculates the total number of expected meals for a given day.
  /// 
  /// The formula is: 
  /// `total recurring slots (isDefault == true) + any additionally logged custom slots (non-empty)`
  static int calculateTotalMeals(UserProfile profile, DailyMealLog mealLog) {
    final defaultIds = profile.customMealSlots
        .where((s) => s['isDefault'] == true)
        .map((s) => s['id'] as String)
        .toSet();
        
    final loggedIds = mealLog.customSlots.entries
        .where((e) => 
            e.value.items.isNotEmpty || 
            e.value.photoPath != null || 
            e.value.totalCalories > 0)
        .map((e) => e.key)
        .toSet();

    final customLoggedCount = loggedIds.difference(defaultIds).length;
    return defaultIds.length + customLoggedCount;
  }
}
