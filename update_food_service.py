import re

file_path = "lib/services/gemini_food_service.dart"
with open(file_path, "r", encoding="utf-8") as f:
    code = f.read()

# Replace _fallbackLookup with _fallbackBatchLookup
old_fallback = """  Future<Map<String, dynamic>> _fallbackLookup(String dishName) async {
    final normalized = dishName.toLowerCase().trim();
    final isar = Isar.getInstance()!;
    final cached = isar.foodSearchCaches
        .where()
        .normalizedQueryEqualTo('fallback_$normalized')
        .findFirstSync();
    
    if (cached != null) {
      try {
        return jsonDecode(cached.cachedResponseJson) as Map<String, dynamic>;
      } catch (_) {}
    }

    final prompt = '''
Provide the nutritional values per 100 grams for the dish: "$dishName".
Return ONLY a JSON object:
{
  "kcal": 0,
  "protein_g": 0.0,
  "carbs_g": 0.0,
  "fat_g": 0.0
}
''';
    final response = await aiClient.generateJson(
      prompt: prompt,
      systemInstruction: 'You are a nutrition database. Provide exact values per 100g.',
      useFirebase: isSignedIn,
      apiKey: apiKey,
    );
    
    if (response != null) {
      final safeResponse = {
        'kcal': (response['kcal'] as num?)?.clamp(0, 900).toDouble() ?? 0.0,
        'protein_g': (response['protein_g'] as num?)?.clamp(0, 100).toDouble() ?? 0.0,
        'carbs_g': (response['carbs_g'] as num?)?.clamp(0, 100).toDouble() ?? 0.0,
        'fat_g': (response['fat_g'] as num?)?.clamp(0, 100).toDouble() ?? 0.0,
      };

      await isar.writeTxn(() async {
        await isar.foodSearchCaches.put(FoodSearchCache(
          normalizedQuery: 'fallback_$normalized',
          cachedResponseJson: jsonEncode(safeResponse),
        ));
      });
      return safeResponse;
    }
    
    return {"kcal": 0.0, "protein_g": 0.0, "carbs_g": 0.0, "fat_g": 0.0};
  }"""

new_fallback = """  Future<Map<String, Map<String, dynamic>>> _fallbackBatchLookup(List<String> dishNames) async {
    final isar = Isar.getInstance()!;
    final Map<String, Map<String, dynamic>> results = {};
    final List<String> toFetch = [];
    
    for (final dish in dishNames) {
      final normalized = dish.toLowerCase().trim();
      final cached = isar.foodSearchCaches.where().normalizedQueryEqualTo('fallback_$normalized').findFirstSync();
      if (cached != null) {
        try {
           results[dish] = jsonDecode(cached.cachedResponseJson) as Map<String, dynamic>;
        } catch (_) { toFetch.add(dish); }
      } else {
        toFetch.add(dish);
      }
    }
    
    if (toFetch.isEmpty) return results;

    final namesList = toFetch.map((n) => '"$n"').join(', ');
    final prompt = '''
Provide the nutritional values per 100 grams for EACH of these foods: $namesList
Return ONLY a JSON object containing an array called "items":
{
  "items": [
    {
      "name": "Exact Name that I queried",
      "kcal": 0,
      "protein_g": 0.0,
      "carbs_g": 0.0,
      "fat_g": 0.0
    }
  ]
}
''';
    final response = await aiClient.generateJson(
      prompt: prompt,
      systemInstruction: 'You are a nutrition database. Provide exact values per 100g.',
      useFirebase: isSignedIn,
      apiKey: apiKey,
    );
    
    if (response != null && response['items'] is List) {
      await isar.writeTxn(() async {
        for (var item in response['items']) {
          if (item is! Map) continue;
          final name = item['name']?.toString();
          if (name == null) continue;
          
          final safeResponse = {
            'kcal': (item['kcal'] as num?)?.clamp(0, 900).toDouble() ?? 0.0,
            'protein_g': (item['protein_g'] as num?)?.clamp(0, 100).toDouble() ?? 0.0,
            'carbs_g': (item['carbs_g'] as num?)?.clamp(0, 100).toDouble() ?? 0.0,
            'fat_g': (item['fat_g'] as num?)?.clamp(0, 100).toDouble() ?? 0.0,
          };
          
          results[name] = safeResponse;
          
          // if there is a slight mismatch in case, store it under the original queried name as well
          final queriedName = toFetch.firstWhere((element) => element.toLowerCase().trim() == name.toLowerCase().trim(), orElse: () => name);
          results[queriedName] = safeResponse;
          
          final normalized = queriedName.toLowerCase().trim();
          await isar.foodSearchCaches.put(FoodSearchCache(
            normalizedQuery: 'fallback_$normalized',
            cachedResponseJson: jsonEncode(safeResponse),
          ));
        }
      });
    }
    
    // Fill in default for any failures
    for (final dish in toFetch) {
      if (!results.containsKey(dish)) {
        results[dish] = {"kcal": 0.0, "protein_g": 0.0, "carbs_g": 0.0, "fat_g": 0.0};
      }
    }
    
    return results;
  }"""
code = code.replace(old_fallback, new_fallback)

# Now we rewrite _processAiResponse block
process_regex = r'Future<Map<String, dynamic>\?> _processAiResponse\(Map<String, dynamic>\? aiResponse\) async \{.*?\n    return aiResponse;\n  \}'

new_process = """  Future<Map<String, dynamic>?> _processAiResponse(Map<String, dynamic>? aiResponse) async {
    if (aiResponse == null) return null;
    await nutritionLookup.load();
    
    double totalCal = 0;
    double totalP = 0;
    double totalC = 0;
    double totalF = 0;
    bool hadUnknown = false;
    
    final items = aiResponse['items'] as List<dynamic>? ?? [];
    List<String> unknownNames = [];
    
    for (var item in items) {
      if (item is! Map) continue;
      final name = item['name']?.toString() ?? 'Unknown';
      if (nutritionLookup.match(name) == null) {
        if (!unknownNames.contains(name)) unknownNames.add(name);
      }
    }
    
    Map<String, Map<String, dynamic>> batchResults = {};
    if (unknownNames.isNotEmpty) {
      hadUnknown = true;
      batchResults = await _fallbackBatchLookup(unknownNames);
    }
    
    for (var item in items) {
      if (item is! Map) continue;
      final name = item['name']?.toString() ?? 'Unknown';
      double grams = (item['estimated_grams'] as num?)?.toDouble() ?? 100.0;
      grams = grams.clamp(1.0, 1500.0);
      item['estimated_grams'] = grams;
      
      final Map<String, dynamic>? match = nutritionLookup.match(name);
      Map<String, dynamic> per100g;
      
      if (match != null) {
        per100g = match['per100g'] as Map<String, dynamic>;
      } else {
        per100g = batchResults[name] ?? {"kcal": 0.0, "protein_g": 0.0, "carbs_g": 0.0, "fat_g": 0.0};
      }
      
      final multiplier = grams / 100.0;
      final kcal = ((per100g['kcal'] as num?)?.toDouble() ?? 0) * multiplier;
      final p = ((per100g['protein_g'] as num?)?.toDouble() ?? 0) * multiplier;
      final c = ((per100g['carbs_g'] as num?)?.toDouble() ?? 0) * multiplier;
      final f = ((per100g['fat_g'] as num?)?.toDouble() ?? 0) * multiplier;
      
      item['calories'] = kcal.round();
      item['protein_g'] = double.parse(p.toStringAsFixed(1));
      item['carbs_g'] = double.parse(c.toStringAsFixed(1));
      item['fat_g'] = double.parse(f.toStringAsFixed(1));
      
      totalCal += kcal;
      totalP += p;
      totalC += c;
      totalF += f;
    }
    
    aiResponse['total'] = {
      'calories': totalCal.round(),
      'protein_g': double.parse(totalP.toStringAsFixed(1)),
      'carbs_g': double.parse(totalC.toStringAsFixed(1)),
      'fat_g': double.parse(totalF.toStringAsFixed(1)),
    };
    
    if (hadUnknown) {
      final currentConfidence = aiResponse['confidence']?.toString().toLowerCase() ?? 'low';
      if (currentConfidence == 'high') {
        aiResponse['confidence'] = 'medium';
      } else if (currentConfidence == 'medium') {
        aiResponse['confidence'] = 'low';
      }
      aiResponse['lookup'] = 'partial';
    }
    
    return aiResponse;
  }"""
code = re.sub(process_regex, new_process, code, flags=re.DOTALL)

# Delete redundant textModelsToTry from verifyApiKey
redundant_models = """    final modelsToTry = [
      'gemini-3.6-flash',
      'gemini-3.5-flash',
      'gemini-3.1-flash-lite',
    ];"""
code = code.replace(redundant_models, "    final modelsToTry = AiClient.textModelsToTry;")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(code)

print("Updated gemini_food_service")
