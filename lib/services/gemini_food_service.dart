import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:googleai_dart/googleai_dart.dart';
import 'package:isar/isar.dart' hide Schema;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/food_search_cache.dart';
import '../interfaces/i_ai_food_service.dart';
import 'nutrition_lookup_service.dart';
import '../utils/time_utils.dart';
import 'package:crypto/crypto.dart';

import 'ai_client.dart';
import '../models/food_nutrition.dart';
import '../models/nutrition_lookup_result.dart';

class GeminiFoodService implements IAiFoodService {
  final String? apiKey;
  final AiClient aiClient;
  final NutritionLookupService nutritionLookup;

  GeminiFoodService({
    this.apiKey,
    required this.aiClient,
    required this.nutritionLookup,
  });

  static const _jsonShape = '''
Return ONLY a JSON object with the exact following structure and types. Do NOT include markdown blocks or any other text.
{
  "items": [
    {
      "name": "Name of the dish (string)",
      "portion": "Estimated portion size (e.g. 1 bowl, 2 pieces)",
      "estimated_grams": 0,
      "estimated_nutrition_if_unknown": {
        "kcal": 0,
        "protein_g": 0.0,
        "carbs_g": 0.0,
        "fat_g": 0.0
      }
    }
  ],
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
      'and you are highly skilled at estimating single-person portion sizes visually. Provide unbiased estimates based on standard recipes. '
      'You strictly output only valid JSON data.\n\n'
      'EXAMPLE:\n'
      'User: I had 2 idlis with coconut chutney and a small bowl of sambar.\n'
      'JSON Output:\n'
      '{\n'
      '  "items": [\n'
      '    { "name": "Idli", "portion": "2 pieces", "estimated_grams": 80 },\n'
      '    { "name": "Coconut Chutney", "portion": "2 tbsp", "estimated_grams": 30 },\n'
      '    { "name": "Sambar", "portion": "1 small bowl (100ml)", "estimated_grams": 100 }\n'
      '  ],\n'
      '  "confidence": "high"\n'
      '}';

  static final Map<String, dynamic> _foodAnalysisSchema = {
    'type': 'OBJECT',
    'properties': {
      'items': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'name': {'type': 'STRING', 'description': 'Name of the dish'},
            'portion': {
              'type': 'STRING',
              'description': 'Estimated portion size (e.g. 1 bowl, 2 pieces)',
            },
            'estimated_grams': {
              'type': 'NUMBER',
              'description': 'Estimated weight in grams',
            },
            'estimated_nutrition_if_unknown': {
              'type': 'OBJECT',
              'description':
                  'Only provide if the dish is rare or complex. Guess the macros per 100g.',
              'properties': {
                'kcal': {'type': 'NUMBER'},
                'protein_g': {'type': 'NUMBER'},
                'carbs_g': {'type': 'NUMBER'},
                'fat_g': {'type': 'NUMBER'},
              },
            },
          },
          'required': ['name', 'portion', 'estimated_grams'],
        },
      },
      'confidence': {
        'type': 'STRING',
        'enum': ['high', 'medium', 'low'],
        'description': 'Confidence in the analysis',
      },
    },
    'required': ['items', 'confidence'],
  };

  @override
  Future<Map<String, dynamic>?> analyzeFoodImage(
    List<Uint8List> imageBytesList,
    String mimeType, [
    String? userContext,
    bool skipCache = false,
    CancellationToken? cancellationToken,
  ]) async {
    _ensureApiKey();
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    final hint = userContext != null && userContext.trim().isNotEmpty
        ? '\nUser provided context/hint: "${userContext.trim()}". Use this to help identify the food, but still estimate macros realistically.'
        : '';
    final prompt =
        '''
Analyze these food images (different angles of the SAME meal) and estimate its nutritional content.
IMPORTANT: Since these are different angles of the same meal, do NOT double count the dishes. Identify the unique items present.
$_cuisineHint$hint
$_jsonShape
''';
    final response = await aiClient.generateJson(
      prompt: prompt,
      systemInstruction: _systemInstruction,
      imageBytesList: imageBytesList,
      mimeType: mimeType,
      apiKey: apiKey ?? '',
      skipCache: skipCache,
      responseSchema: _foodAnalysisSchema,
      cancellationToken: cancellationToken,
      overallDeadline: deadline,
    );
    return _processAiResponse(response, cancellationToken: cancellationToken);
  }

  /// Estimate macros from a free-text description of what was eaten at home.
  @override
  Future<Map<String, dynamic>?> analyzeFoodText(
    String description, [
    CancellationToken? cancellationToken,
  ]) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    final trimmed = description.trim();
    if (trimmed.isEmpty) {
      throw Exception('Please describe what you ate.');
    }

    final normalizedQuery = trimmed.toLowerCase();
    final isar = Isar.getInstance(Isar.instanceNames.first)!;
    final cached = isar.foodSearchCaches
        .where()
        .normalizedQueryEqualTo(normalizedQuery)
        .findFirstSync();

    if (cached != null) {
      try {
        final decoded =
            jsonDecode(cached.cachedResponseJson) as Map<String, dynamic>;
        if (!decoded.containsKey('total')) {
          // Legacy cached raw data lacking totals — process it
          return await _processAiResponse(
            decoded,
            cancellationToken: cancellationToken,
          );
        }
        return decoded;
      } catch (_) {
        // Fallback to API if cache is corrupted
      }
    }

    // 0. Heuristic Local Parser (Zero-Latency Interceptor)
    bool isFullyLocal = true;
    final List<Map<String, dynamic>> localItems = [];
    final List<String> unresolvedParts = [];

    final splitParts = normalizedQuery
        .split(RegExp(r'\+|\b(and)\b|,'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await nutritionLookup.load();

    for (var part in splitParts) {
      final match = RegExp(
        r'^(\d+(?:\.\d+)?)\s*(g|grams?|ml|bowl|cup|plate|piece|idlis?|dosas?|chapatis?|rotis?|tbsp|tsp)?\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(part);
      String queryName = part;
      double quantity = 1.0;
      String? parsedUnit;

      if (match != null) {
        quantity = double.tryParse(match.group(1) ?? '1') ?? 1.0;
        parsedUnit = match.group(2)?.toLowerCase();
        final possibleName = match.group(3)?.trim() ?? '';
        if (possibleName.isNotEmpty) {
          queryName = possibleName;
        } else if (match.group(2) != null) {
          queryName = match.group(2)!;
        }
      }

      if (queryName.endsWith('s') && !queryName.endsWith('ss')) {
        queryName = queryName.substring(0, queryName.length - 1);
      }

      final localMatch = nutritionLookup.match(queryName);
      if (localMatch != null) {
        try {
          final isPer100g = localMatch.isPer100g;
          final userServing = localMatch.servingGrams;
          final userProv = localMatch.provenance;

          double? explicitGrams;
          double? explicitServings;
          double defGrams = userServing ?? 100.0;

          if (parsedUnit == 'g' ||
              parsedUnit == 'gram' ||
              parsedUnit == 'grams' ||
              parsedUnit == 'ml') {
            explicitGrams = quantity;
            defGrams = quantity;
            quantity = 1.0;
          } else {
            explicitServings = quantity;
            if (parsedUnit == 'cup') {
              defGrams = 240.0;
            } else if (parsedUnit == 'bowl')
              defGrams = 250.0;
            else if (parsedUnit == 'tbsp')
              defGrams = 15.0;
            else if (parsedUnit == 'tsp')
              defGrams = 5.0;
            else if (!isPer100g && userServing != null)
              defGrams = userServing;
          }

          final double totalGrams =
              explicitGrams ?? (defGrams * (explicitServings ?? 1.0));

          final computed = FoodNutrition.compute(
            consumedGrams: explicitGrams,
            consumedServings: explicitServings,
            baseNutrition: localMatch.baseNutrition,
            isPer100g: isPer100g,
            servingGrams:
                (parsedUnit != null &&
                    ['cup', 'bowl', 'tbsp', 'tsp'].contains(parsedUnit))
                ? defGrams
                : localMatch.servingGrams,
          );

          localItems.add({
            "name": localMatch.name,
            "portion": explicitGrams != null
                ? "${explicitGrams}g"
                : "$quantity (${defGrams}g)",
            "estimated_grams": totalGrams,
            "calories": computed.kcal.round(),
            "protein_g": double.parse(computed.proteinG.toStringAsFixed(1)),
            "carbs_g": double.parse(computed.carbsG.toStringAsFixed(1)),
            "fat_g": double.parse(computed.fatG.toStringAsFixed(1)),
            "resolved": true,
            "provenance": userProv ?? "database",
            "is_per_100g": isPer100g,
            "serving_grams": defGrams,
            "baseNutrition": localMatch.baseNutrition.toJson(),
            "computedNutrition": computed.toJson(),
          });
        } catch (e) {
          isFullyLocal = false;
          unresolvedParts.add(part);
        }
      } else {
        isFullyLocal = false;
        unresolvedParts.add(part);
      }
    }

    if (isFullyLocal && localItems.isNotEmpty) {
      double tCal = 0, tP = 0, tC = 0, tF = 0;
      for (var item in localItems) {
        tCal += item['calories'];
        tP += item['protein_g'];
        tC += item['carbs_g'];
        tF += item['fat_g'];
      }
      return {
        "items": localItems,
        "confidence": "high",
        "total": {
          "calories": tCal.round(),
          "protein_g": double.parse(tP.toStringAsFixed(1)),
          "carbs_g": double.parse(tC.toStringAsFixed(1)),
          "fat_g": double.parse(tF.toStringAsFixed(1)),
        },
      };
    }

    // AI is only given what the local parser failed to understand
    _ensureApiKey();
    final aiTargetText = unresolvedParts.join(" and ");

    final prompt =
        '''
Estimate nutritional content for this home-cooked meal description.
$_cuisineHint
Meal description:
"""
$aiTargetText
"""
$_jsonShape
''';
    final response = await aiClient.generateJson(
      prompt: prompt,
      systemInstruction: _systemInstruction,
      apiKey: apiKey ?? '',
      responseSchema: _foodAnalysisSchema,
      cancellationToken: cancellationToken,
      overallDeadline: deadline,
    );

    // Merge AI response with Local items
    final aiParsed = await _processAiResponse(
      response,
      cancellationToken: cancellationToken,
    );
    if (aiParsed != null && localItems.isNotEmpty) {
      final allItems = [...localItems, ...(aiParsed['items'] ?? [])];
      double tCal = 0, tP = 0, tC = 0, tF = 0;
      int unresolvedCount = 0;
      for (var item in allItems) {
        tCal += item['calories'] ?? 0;
        tP += item['protein_g'] ?? 0;
        tC += item['carbs_g'] ?? 0;
        tF += item['fat_g'] ?? 0;
        if (item['resolved'] == false) unresolvedCount++;
      }
      aiParsed['items'] = allItems;
      aiParsed['total'] = {
        "calories": tCal.round(),
        "protein_g": double.parse(tP.toStringAsFixed(1)),
        "carbs_g": double.parse(tC.toStringAsFixed(1)),
        "fat_g": double.parse(tF.toStringAsFixed(1)),
        if (unresolvedCount > 0) 'unresolved_count': unresolvedCount,
      };
      // Store the final merged result
      if (!(cancellationToken?.isCancelled ?? false)) {
        await isar.writeTxn(() async {
          await isar.foodSearchCaches.put(
            FoodSearchCache(
              normalizedQuery: normalizedQuery,
              cachedResponseJson: jsonEncode(aiParsed),
              timestamp: DateTime.now(),
              schemaVersion: '1',
            ),
          );
        });
      }
      return aiParsed;
    }

    if (aiParsed != null && !(cancellationToken?.isCancelled ?? false)) {
      await isar.writeTxn(() async {
        await isar.foodSearchCaches.put(
          FoodSearchCache(
            normalizedQuery: normalizedQuery,
            cachedResponseJson: jsonEncode(aiParsed),
            timestamp: DateTime.now(),
            schemaVersion: '1',
          ),
        );
      });
    }

    return aiParsed;
  }

  Future<Map<String, dynamic>?> _processAiResponse(
    Map<String, dynamic>? aiResponse, {
    CancellationToken? cancellationToken,
  }) async {
    if (aiResponse == null) return null;
    await nutritionLookup.load();

    double totalCal = 0;
    double totalP = 0;
    double totalC = 0;
    double totalF = 0;
    bool hadUnknown = false;

    final items = aiResponse['items'] as List<dynamic>? ?? [];

    for (var item in items) {
      if (item is! Map) continue;
      final name = item['name']?.toString() ?? 'Unknown';
      double grams = (item['estimated_grams'] as num?)?.toDouble() ?? 100.0;
      grams = grams.clamp(1.0, 1500.0);
      item['estimated_grams'] = grams;

      final NutritionLookupResult? match = nutritionLookup.match(name);
      FoodNutrition baseNut;
      bool isPer100g = true;
      double? servingGrams;
      String? provenance;

      if (match != null) {
        baseNut = match.baseNutrition;
        isPer100g = match.isPer100g;
        servingGrams = match.servingGrams;
        provenance = 'database';
      } else {
        hadUnknown = true;
        final fallbackMap = item['estimated_nutrition_if_unknown'];
        if (fallbackMap != null && fallbackMap is Map) {
          baseNut = FoodNutrition(
            kcal: (fallbackMap['kcal'] as num?)?.toDouble() ?? 0.0,
            proteinG: (fallbackMap['protein_g'] as num?)?.toDouble() ?? 0.0,
            carbsG: (fallbackMap['carbs_g'] as num?)?.toDouble() ?? 0.0,
            fatG: (fallbackMap['fat_g'] as num?)?.toDouble() ?? 0.0,
          );
          if (baseNut.kcal == 0) {
            // validate math if AI hallucinates 0 kcal but gives macros
            baseNut.kcal =
                (baseNut.proteinG * 4) +
                (baseNut.carbsG * 4) +
                (baseNut.fatG * 9);
          }
          isPer100g = true;
          servingGrams = null;
          provenance = 'ai_estimate';
        } else {
          baseNut = FoodNutrition(); // All zeroes
          isPer100g = true;
          provenance = 'ai_estimate';
        }
      }

      final computed = FoodNutrition.compute(
        consumedGrams:
            grams, // AI currently only outputs grams or assumes grams
        baseNutrition: baseNut,
        isPer100g: isPer100g,
        servingGrams: servingGrams,
      );

      item['calories'] = computed.kcal.round();
      item['protein_g'] = double.parse(computed.proteinG.toStringAsFixed(1));
      item['carbs_g'] = double.parse(computed.carbsG.toStringAsFixed(1));
      item['fat_g'] = double.parse(computed.fatG.toStringAsFixed(1));
      item['baseNutrition'] = baseNut.toJson();
      item['computedNutrition'] = computed.toJson();
      item['is_per_100g'] = isPer100g;
      item['serving_grams'] = servingGrams;
      item['provenance'] = provenance;

      if (computed.kcal == 0 && baseNut.kcal == 0) {
        item['resolved'] = false;
      } else {
        item['resolved'] = true;
        totalCal += computed.kcal;
        totalP += computed.proteinG;
        totalC += computed.carbsG;
        totalF += computed.fatG;
      }
    }

    final unresolvedCount = items
        .where((i) => i is Map && i['resolved'] == false)
        .length;

    aiResponse['total'] = {
      'calories': totalCal.round(),
      'protein_g': double.parse(totalP.toStringAsFixed(1)),
      'carbs_g': double.parse(totalC.toStringAsFixed(1)),
      'fat_g': double.parse(totalF.toStringAsFixed(1)),
      if (unresolvedCount > 0) 'unresolved_count': unresolvedCount,
    };

    if (hadUnknown || unresolvedCount > 0) {
      final currentConfidence =
          aiResponse['confidence']?.toString().toLowerCase() ?? 'low';
      if (currentConfidence == 'high') {
        aiResponse['confidence'] = 'medium';
      } else if (currentConfidence == 'medium') {
        aiResponse['confidence'] = 'low';
      }
      aiResponse['lookup'] = 'partial';
    }

    return aiResponse;
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
    String? targetDate,
    CancellationToken? cancellationToken,
  }) async* {
    _ensureApiKey();

    final bucketedCalories = (remainingCalories ~/ 100) * 100;
    final bucketedProtein = (remainingProtein ~/ 10) * 10;
    final bucketedCarbs = (remainingCarbs ~/ 10) * 10;
    final bucketedFat = (remainingFat ~/ 5) * 5;
    final historyHash = previousMeals != null
        ? sha256
              .convert(utf8.encode(previousMeals.join()))
              .toString()
              .substring(0, 8)
        : 'none';
    final ml = mealsLeft ?? 1;

    final dateStr = targetDate ?? todayKey();
    final mName = mealName?.replaceAll(' ', '_') ?? 'final';
    final cacheKey =
        'meal_suggestion_${dateStr}_${mName}_${bucketedCalories}_${bucketedProtein}_${bucketedCarbs}_${bucketedFat}_${ml}_$historyHash';

    final prefs = await SharedPreferences.getInstance();

    // Prune old keys
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('meal_suggestion_'))
        .toList();
    final twoDaysAgo = DateTime.now()
        .subtract(const Duration(days: 2))
        .toIso8601String()
        .substring(0, 10);
    for (final key in keys) {
      if (key.length >= 26) {
        final keyDate = key.substring(16, 26); // extracts YYYY-MM-DD
        if (keyDate.compareTo(twoDaysAgo) < 0) {
          prefs.remove(key);
        }
      }
    }

    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      yield cached;
      return;
    }

    String mealContext = '';
    if (mealName != null && mealsLeft != null && mealsLeft > 1) {
      mealContext =
          'The user is asking for a "$mealName" suggestion. There are $mealsLeft meals left to eat today (including this one), so DO NOT use up all the remaining macros for this single meal. Instead, roughly divide the remaining macros by $mealsLeft to get a sensible target for this specific meal. Be realistic and do not suggest massive meals (e.g. keep single meal suggestions under 800-1000 calories).';
    } else {
      mealContext =
          'This is the final meal/snack of the day, so try to use up as much of the remaining macros as possible without going over calories. If the remaining calories are very high, suggest a realistic meal and do not force an unrealistic 1200+ calorie dish.';
    }

    String historyContext = '';
    if (previousMeals != null && previousMeals.isNotEmpty) {
      final recentMeals = previousMeals.take(2).join(", ");
      historyContext =
          'The user has already eaten the following today: $recentMeals. Please balance the diet based on what they already ate, and avoid suggesting the exact same things.';
    } else {
      historyContext =
          'This is the first meal of the day. Focus purely on hitting a healthy balance for this meal.';
    }

    final prompt =
        '''
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
        systemInstruction:
            'You are an expert clinical dietitian and nutritionist specializing in Indian and Telugu cuisine.',
        apiKey: apiKey ?? '',
        cancellationToken: cancellationToken,
        overallDeadline: DateTime.now().add(const Duration(seconds: 15)),
      );

      final buffer = StringBuffer();
      await for (final chunk in stream) {
        if (cancellationToken?.isCancelled ?? false) break;
        buffer.write(chunk);
        yield chunk;
      }

      if (buffer.isNotEmpty && !(cancellationToken?.isCancelled ?? false)) {
        // ignore: unawaited_futures
        prefs.setString(cacheKey, buffer.toString());
      }
    } on TimeoutException {
      yield "Our AI is taking too long to respond. Here's a generic quick idea: Try a simple grilled chicken salad, or a bowl of dal with rice and veggies! Please verify the macros manually to ensure it fits your budget.";
    } catch (e) {
      if (e is AiException &&
          (e.message.contains('traffic') ||
              e.message.contains('rate limited') ||
              e.message.contains('later'))) {
        yield "Our AI is currently taking a breather. Here's a generic quick idea: Try a simple grilled chicken salad, or a bowl of dal with rice and veggies! Please verify the macros manually to ensure it fits your budget.";
      } else {
        rethrow;
      }
    }
  }

  void _ensureApiKey() {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception(
        'Gemini API key is not configured. Please add it in Profile -> AI Settings.',
      );
    }
  }

  @override
  Future<void> verifyApiKey(String key) async {
    final trimmedKey = key.trim();
    final client = GoogleAIClient(
      config: GoogleAIConfig.googleAI(authProvider: ApiKeyProvider(trimmedKey)),
    );

    final deadline = DateTime.now().add(const Duration(seconds: 30));
    AiErrorCause? lastCause;

    try {
      for (String modelName in AiClient.textModelsToTry) {
        if (DateTime.now().isAfter(deadline)) break;

        try {
          final remaining = deadline.difference(DateTime.now());
          final attemptTimeout = remaining < const Duration(seconds: 10)
              ? remaining
              : const Duration(seconds: 10);

          await client.models
              .generateContent(
                model: modelName,
                request: GenerateContentRequest(
                  contents: [Content.text('ping')],
                  generationConfig: const GenerationConfig(maxOutputTokens: 10),
                ),
              )
              .timeout(attemptTimeout);

          return; // Success!
        } catch (e) {
          lastCause = classifyAiError(e.toString());

          switch (lastCause) {
            case AiErrorCause.invalidKey:
              throw AiException(
                'This key cannot access the requested Gemini service.',
                cause: lastCause,
              );
            case AiErrorCause.offline:
              throw AiException(
                'Couldn\'t reach Gemini. Check your connection and try again.',
                cause: lastCause,
              );
            case AiErrorCause.rateLimited:
              throw AiException(
                'Gemini quota or rate limit reached. Check usage or try later.',
                cause: lastCause,
              );
            case AiErrorCause.notFound:
              continue; // Try next model
            case AiErrorCause.timeout:
            case AiErrorCause.overloaded:
              continue; // Bounded transient loop
            default:
              throw AiException(
                'Couldn\'t verify the key. Please try again.',
                cause: lastCause,
              );
          }
        }
      }

      if (lastCause == AiErrorCause.timeout ||
          DateTime.now().isAfter(deadline)) {
        throw AiException(
          'Verification timed out. Please try again.',
          cause: AiErrorCause.timeout,
        );
      } else if (lastCause == AiErrorCause.notFound) {
        throw AiException(
          'Model unavailable or unsupported for the requested API operation.',
          cause: AiErrorCause.notFound,
        );
      }

      throw AiException(
        'Couldn\'t verify the key. Please try again.',
        cause: lastCause ?? AiErrorCause.unknown,
      );
    } finally {
      client.close();
    }
  }
}
