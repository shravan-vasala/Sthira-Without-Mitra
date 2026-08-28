import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleai_dart/googleai_dart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_ai/firebase_ai.dart' as vertex;
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_search_cache.dart';
import '../providers/app_providers.dart';
import '../interfaces/i_ai_food_service.dart';

import 'ai_client.dart';

class GeminiFoodService implements IAiFoodService {
  final String? apiKey;
  final bool isSignedIn;
  final AiClient aiClient;

  GeminiFoodService({this.apiKey, this.isSignedIn = false, required this.aiClient});

  static const _jsonShape = '''
Return ONLY a JSON object with the exact following structure and types. Do NOT include markdown blocks or any other text.
{
  "items": [
    {
      "name": "Name of the dish (string)",
      "portion": "Estimated portion size (e.g. 1 bowl, 2 pieces)",
      "calories": 0,
      "protein_g": 0.0,
      "carbs_g": 0.0,
      "fat_g": 0.0
    }
  ],
  "total": {
    "calories": 0,
    "protein_g": 0.0,
    "carbs_g": 0.0,
    "fat_g": 0.0
  },
  "confidence": "high|medium|low"
}
If you cannot identify the food, provide a generic "Unknown Food" response with 0 values and low confidence.
''';

  static const _cuisineHint = '''
IMPORTANT: The cuisine is predominantly Telugu / South Indian home cooking (Andhra Pradesh & Telangana style), but may also include urban restaurant and café food.

Common dishes to recognize accurately:
- RICE MEALS: White rice (annam) with pappu (dal), sambar, rasam, curd rice (perugu annam), lemon rice (nimmakaya pulihora), tamarind rice (chintapandu pulihora), tomato rice, coconut rice, biryani (Hyderabadi dum biryani), pulao
- CURRIES & GRAVIES: Chicken curry (kodi kura), mutton curry (mamsam kura), fish curry (chepala pulusu), egg curry (guddu pulusu), gutti vankaya (stuffed brinjal), dondakaya (ivy gourd), bendakaya (okra/bhindi), beerakaya (ridge gourd), sorakaya (bottle gourd), aloo gobi, paneer curry, dal tadka, tomato pappu, dosakaya pappu
- BREAKFAST/TIFFIN: Idli, dosa (plain/masala/pesarattu), upma, poha (atukulu), puri/poori with curry, vada (garelu), uttapam, ragi mudde, jowar roti
- PICKLES & SIDES: Avakaya (mango pickle), gongura pachadi, tomato pachadi, peanut chutney, coconut chutney, onion chutney, nuvvula podi (sesame powder), karam podi (spice powder with oil on rice)
- SNACKS: Mirchi bajji, punugulu, bonda, samosa, murukku (janthikalu), mixture
- SWEETS: Payasam, gulab jamun, laddu, jalebi, pootharekulu
- NON-VEG: Chicken fry (kodi vepudu), fish fry (chepala vepudu), prawn curry (royyala kura), keema, liver fry, egg bhurji
- ROTI/BREAD: Chapati, phulka, paratha, naan, roti with ghee

URBAN / RESTAURANT FOOD (also commonly eaten):
- TANDOOR: Tandoori chicken, chicken tikka, paneer tikka, seekh kebab, tandoori roti, butter naan, garlic naan, kulcha, tandoori prawns, reshmi kebab, malai tikka
- SALADS: Caesar salad, Greek salad, garden salad, paneer/chicken salad bowl, quinoa salad, sprout salad, fruit salad, coleslaw
- RICE BOWLS: Burrito bowl, poke bowl, teriyaki chicken bowl, paneer tikka rice bowl, Mexican rice bowl, Buddha bowl, grain bowl
- NORTH INDIAN RESTAURANT: Butter chicken, dal makhani, palak paneer, kadai paneer, chole bhature, rajma chawal, shahi paneer, malai kofta, paneer butter masala
- CAFÉ & WESTERN: Sandwich, wrap, burger, pizza, pasta, grilled chicken, French fries, smoothie bowl, açaí bowl, avocado toast, omelette
- DRINKS: Chai, coffee, lassi, buttermilk (majjiga), fresh juice, smoothie, milkshake, protein shake

CRITICAL — PLATE & BOWL SIZE ESTIMATION:
The user typically orders moderate, single-person portions (not family-style or shared plates). When analyzing images:
- Use objects in the photo (spoons, forks, hands, phone, table edge) as size references to estimate plate diameter
- Standard Indian restaurant bowl = ~300-400ml capacity (~15cm diameter)
- Standard dinner plate = ~25cm diameter
- Small katori/bowl = ~150ml (~10cm diameter)
- Typical single-person restaurant serving is 1 moderate bowl or 1 plate — do NOT overestimate
- If the portion looks small-to-medium, estimate conservatively rather than generously

Portion estimation guidelines:
- 1 plate of rice = ~200g cooked (~250 kcal)
- 1 bowl of sambar/rasam = ~150ml (~80-100 kcal)
- 1 bowl of pappu (dal) = ~150ml (~120-150 kcal)
- 1 idli = ~40g (~60 kcal), typical serving is 3-4
- 1 plain dosa = ~100g (~120 kcal), masala dosa = ~180 kcal
- 1 chapati/roti = ~30g (~80 kcal), butter naan = ~150 kcal
- 1 piece chicken curry = ~100g (~180 kcal)
- Curd/yogurt serving = ~100g (~60 kcal)
- 1 tandoori chicken leg = ~150g (~250 kcal)
- 1 salad bowl (restaurant, single serving) = ~250-300g (~200-350 kcal depending on dressing)
- 1 rice bowl (restaurant, single serving) = ~350-400g (~400-550 kcal)
- 1 smoothie bowl = ~300ml (~250-400 kcal)
- 1 soup bowl = ~250ml (~100-200 kcal)
- Telugu meals often use generous amounts of oil and ghee — account for this
- Restaurant food typically has more oil/butter than home cooking — factor this in
- AIR FRYER AVAILABLE AT HOME: The user has an air fryer and sometimes uses it for fried items (chicken fry, fish fry, french fries, snacks). Not everything is air-fried though — look for visual cues: if the food looks dry/crispy with little visible oil, assume air-fried (lower fat). If it looks oily/glistening, assume traditional frying. When uncertain, estimate a moderate amount of oil (between air-fried and deep-fried).
- Pay close attention to cooked vs raw states (cooked rice expands 2-3x, meat shrinks ~25%)
- When in doubt about portion size, estimate for a moderate single-person meal, not a large/shared serving
''';

  static const _systemInstruction =
      'You are an expert clinical dietitian and nutritionist specializing in Indian and Telugu cuisine. '
      'You accurately identify specific regional dishes, cooking methods (especially the heavy use of oil/ghee in Indian cooking), '
      'and you are highly skilled at estimating single-person portion sizes visually. You never overestimate single servings. '
      'You strictly output only valid JSON data.\n\n'
      'EXAMPLE:\n'
      'User: I had 2 idlis with coconut chutney and a small bowl of sambar.\n'
      'JSON Output:\n'
      '{\n'
      '  "items": [\n'
      '    { "name": "Idli", "portion": "2 pieces", "calories": 120, "protein_g": 4.0, "carbs_g": 24.0, "fat_g": 0.0 },\n'
      '    { "name": "Coconut Chutney", "portion": "2 tbsp", "calories": 70, "protein_g": 1.0, "carbs_g": 2.0, "fat_g": 7.0 },\n'
      '    { "name": "Sambar", "portion": "1 small bowl (100ml)", "calories": 60, "protein_g": 2.5, "carbs_g": 8.0, "fat_g": 2.0 }\n'
      '  ],\n'
      '  "total": { "calories": 250, "protein_g": 7.5, "carbs_g": 34.0, "fat_g": 9.0 },\n'
      '  "confidence": "high"\n'
      '}';

  @override
  Future<Map<String, dynamic>?> analyzeFoodImage(
    Uint8List imageBytes,
    String mimeType, [
    String? userContext,
  ]) async {
    _ensureApiKey();
    final hint = userContext != null && userContext.trim().isNotEmpty
        ? '\nUser provided context/hint: "${userContext.trim()}". Use this to help identify the food, but still estimate macros realistically.'
        : '';
    final prompt = '''
Analyze this food image and estimate its nutritional content. $_cuisineHint$hint
$_jsonShape
''';
    return aiClient.generateJson(
      prompt: prompt,
      systemInstruction: _systemInstruction,
      imageBytes: imageBytes,
      mimeType: mimeType,
      useFirebase: isSignedIn,
      apiKey: apiKey,
    );
  }

  /// Estimate macros from a free-text description of what was eaten at home.
  @override
  Future<Map<String, dynamic>?> analyzeFoodText(String description) async {
    _ensureApiKey();
    final trimmed = description.trim();
    if (trimmed.isEmpty) {
      throw Exception('Please describe what you ate.');
    }

    final normalizedQuery = trimmed.toLowerCase();
    final isar = Isar.getInstance()!;
    final cached = isar.foodSearchCaches
        .where()
        .normalizedQueryEqualTo(normalizedQuery)
        .findFirstSync();

    if (cached != null) {
      try {
        return jsonDecode(cached.cachedResponseJson) as Map<String, dynamic>;
      } catch (_) {
        // Fallback to API if cache is corrupted
      }
    }

    final prompt = '''
Estimate nutritional content for this home-cooked meal description.
$_cuisineHint
Meal description:
"""
$trimmed
"""
$_jsonShape
''';
    final response = await aiClient.generateJson(
      prompt: prompt,
      systemInstruction: _systemInstruction,
      useFirebase: isSignedIn,
      apiKey: apiKey,
    );

    if (response != null) {
      await isar.writeTxn(() async {
        await isar.foodSearchCaches.put(FoodSearchCache(
          normalizedQuery: normalizedQuery,
          cachedResponseJson: jsonEncode(response),
        ));
      });
    }

    return response;
  }

  /// Suggest a meal that fits within the remaining daily macros.
  @override
  Stream<String> suggestMealStream({
    required int remainingCalories,
    required double remainingProtein,
    required double remainingCarbs,
    required double remainingFat,
    String? mealName,
    int? mealsLeft,
    List<String>? previousMeals,
  }) async* {
    _ensureApiKey();

    final bucketedCalories = (remainingCalories ~/ 50) * 50;
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    final cacheKey = 'meal_suggestion_${dateStr}_$bucketedCalories';
    final prefs = await SharedPreferences.getInstance();
    
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      yield cached;
      return;
    }

    String mealContext = '';
    if (mealName != null && mealsLeft != null && mealsLeft > 1) {
      mealContext = 'The user is asking for a "$mealName" suggestion. There are $mealsLeft meals left to eat today (including this one), so DO NOT use up all the remaining macros for this single meal. Instead, roughly divide the remaining macros by $mealsLeft to get a sensible target for this specific meal. Be realistic and do not suggest massive meals (e.g. keep single meal suggestions under 800-1000 calories).';
    } else {
      mealContext = 'This is the final meal/snack of the day, so try to use up as much of the remaining macros as possible without going over calories. If the remaining calories are very high, suggest a realistic meal and do not force an unrealistic 1200+ calorie dish.';
    }

    String historyContext = '';
    if (previousMeals != null && previousMeals.isNotEmpty) {
      final recentMeals = previousMeals.take(2).join(", ");
      historyContext = 'The user has already eaten the following today: $recentMeals. Please balance the diet based on what they already ate, and avoid suggesting the exact same things.';
    } else {
      historyContext = 'This is the first meal of the day. Focus purely on hitting a healthy balance for this meal.';
    }

    final prompt = '''
You are an expert dietitian. The user needs a meal suggestion to hit their remaining macros for the day.
Make the suggestion simple and mostly home-cooked meals.

Remaining Macros for the ENTIRE rest of the day:
- Calories: $remainingCalories kcal
- Protein: ${remainingProtein.toStringAsFixed(1)} g
- Carbs: ${remainingCarbs.toStringAsFixed(1)} g
- Fat: ${remainingFat.toStringAsFixed(1)} g

$mealContext

$historyContext

$_cuisineHint

Suggest ONE specific simple, home-cooked meal, prioritizing protein. If the target calories for this meal are very low (e.g. < 150), suggest a small healthy snack.
Keep it brief and friendly. Provide the meal name, portion, and approximate macros.
Do NOT use markdown formatting (no asterisks).
Do NOT use JSON.
''';
    
    try {
      final stream = aiClient.generateTextStream(
        prompt: prompt,
        systemInstruction: 'You are an expert clinical dietitian and nutritionist specializing in Indian and Telugu cuisine.',
        useFirebase: isSignedIn,
        apiKey: apiKey,
      );
      
      final buffer = StringBuffer();
      await for (final chunk in stream) {
        buffer.write(chunk);
        yield chunk;
      }
      
      if (buffer.isNotEmpty) {
        prefs.setString(cacheKey, buffer.toString());
      }
    } catch (e) {
      if (e is AiException && (e.message.contains('traffic') || e.message.contains('rate limited') || e.message.contains('later'))) {
        yield "Our AI is currently taking a breather to handle traffic, but here's a quick idea: Try a simple grilled chicken salad, or a bowl of dal with rice and veggies! This should easily fit your remaining $remainingCalories calories.";
      } else {
        rethrow;
      }
    }
  }

  void _ensureApiKey() {
    if (!isSignedIn && (apiKey == null || apiKey!.isEmpty)) {
      throw Exception(
        'Gemini API key is not configured. Please add it in Profile -> AI Settings, or sign in to Cloud Sync.',
      );
    }
  }

  @override
  Future<void> verifyApiKey(String key) async {
    final client = GoogleAIClient(
      config: GoogleAIConfig.googleAI(
        authProvider: ApiKeyProvider(key.trim()),
      ),
    );

    final modelsToTry = [
      'gemini-3.6-flash',
      'gemini-3.1-flash-lite',
      'gemini-2.5-flash',
    ];

    String lastError = '';

    try {
      for (final model in modelsToTry) {
        try {
          final response = await client.models.generateContent(
            model: model,
            request: GenerateContentRequest(
              contents: [Content.text("Respond exactly with 'OK'")],
            ),
          ).timeout(const Duration(seconds: 15));
          if (response.text != null && response.text!.isNotEmpty) {
            return; // Success!
          }
        } catch (e) {
          final errorString = e.toString();
          if (errorString.contains('API_KEY_INVALID') || errorString.contains('API key not valid') || errorString.contains('disabled') || errorString.contains('has not been used in project')) {
            throw AiException('Your API Key is invalid or not authorized.');
          } else if (errorString.contains('403') || errorString.contains('forbidden')) {
            lastError = 'Access Forbidden (403). Ensure your API key has no IP/app restrictions, your region is supported, and billing is enabled in Google Cloud.';
            continue; // Try next model
          } else if (errorString.contains('404') || errorString.contains('not found')) {
            lastError = 'Model $model unavailable (404)';
            continue; // Try next model
          } else if (errorString.contains('429') || errorString.contains('quota')) {
            throw AiException('We\'re experiencing heavy traffic! Please wait a minute.');
          } else if (errorString.contains('TimeoutException') || errorString.contains('Timeout') || errorString.contains('SocketException') || errorString.contains('Failed host lookup')) {
             lastError = 'Connection timed out or offline';
             continue; 
          }
          lastError = errorString;
          continue; // Try next model on 404 etc.
        }
      }
      throw AiException("Failed to verify API key: $lastError");
    } finally {
      client.close();
    }
  }
}
