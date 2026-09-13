import 'dart:typed_data';
import '../services/ai_client.dart';

abstract class IAiFoodService {
  Future<Map<String, dynamic>?> analyzeFoodImage(
    List<Uint8List> imageBytesList,
    String mimeType, [
    String? userContext,
    bool skipCache = false,
    CancellationToken? cancellationToken,
  ]);

  Future<Map<String, dynamic>?> analyzeFoodText(String description, [CancellationToken? cancellationToken]);

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
