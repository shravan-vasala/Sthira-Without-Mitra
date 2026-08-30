import 'dart:typed_data';

abstract class IAiFoodService {
  Future<Map<String, dynamic>?> analyzeFoodImage(
    List<Uint8List> imageBytesList,
    String mimeType, [
    String? userContext,
    bool skipCache = false,
  ]);

  Future<Map<String, dynamic>?> analyzeFoodText(String description);

  Stream<String> suggestMealStream({
    required int remainingCalories,
    required double remainingProtein,
    required double remainingCarbs,
    required double remainingFat,
    String? mealName,
    int? mealsLeft,
    List<String>? previousMeals,
  });

  Future<void> verifyApiKey(String key);
}
