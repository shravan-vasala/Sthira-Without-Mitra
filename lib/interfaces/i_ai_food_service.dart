import 'dart:typed_data';
import '../services/ai_client.dart';
import '../services/ai_profiler.dart';

abstract class IAiFoodService {
  Future<Map<String, dynamic>?> analyzeFoodImage(
    List<Uint8List> imageBytesList,
    String mimeType, [
    String? userContext,
    bool skipCache = false,
    bool isAlreadyProcessed = false,
    CancellationToken? cancellationToken,
    AiProfileSession? profiler,
  ]);

  Future<Map<String, dynamic>?> analyzeFoodText(
    String description, [
    CancellationToken? cancellationToken,
    AiProfileSession? profiler,
  ]);

  Stream<String> suggestMealStream({
    required int remainingCalories,
    required double remainingProtein,
    required double remainingCarbs,
    required double remainingFat,
    String? mealName,
    int? mealsLeft,
    List<String>? previousMeals,
    String? targetDate,
    CancellationToken? cancellationToken,
  });

  Future<void> verifyApiKey(String key);
}
