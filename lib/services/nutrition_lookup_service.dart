import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../models/user_food_log.dart';

import '../models/nutrition_lookup_result.dart';
import '../models/food_nutrition.dart';

class NutritionLookupService {
  List<Map<String, dynamic>> _nutritionTable = [];
  bool _isLoaded = false;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/nutrition_table.json',
      );
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _nutritionTable = List<Map<String, dynamic>>.from(jsonList);
      _isLoaded = true;
    } catch (e) {
      // ignore: avoid_print
      print('Failed to load nutrition table: $e');
    }
  }

  /// Returns the matched item if found, otherwise null.
  NutritionLookupResult? match(String dishName) {
    if (!_isLoaded || dishName.trim().isEmpty) return null;

    final queryTokens = _tokenize(dishName);
    if (queryTokens.isEmpty) return null;
    final queryStr = queryTokens.join(' ');

    // 0. Check UserFoodLog (Personalized Local DB) first (Exact match)
    final isar = Isar.getInstance();
    if (isar != null) {
      final userFood = isar.userFoodLogs
          .where()
          .normalizedNameEqualTo(queryStr)
          .findFirstSync();
      if (userFood != null) {
        return NutritionLookupResult(
          id: 'user_food_${userFood.id}',
          name: userFood.originalName,
          baseNutrition: userFood.baseNutrition,
          isPer100g: userFood.isPer100g,
          servingGrams: userFood.servingGrams,
        );
      }
    }

    // 1. Exact match on static table name
    for (var item in _nutritionTable) {
      if (_normalize(item['name'] as String) == queryStr) {
        return _mapToResult(item);
      }
    }

    // 2. Exact match on aliases
    for (var item in _nutritionTable) {
      final aliases = List<String>.from(item['aliases'] ?? []);
      for (var alias in aliases) {
        if (_normalize(alias) == queryStr) {
          return _mapToResult(item);
        }
      }
    }

    // 3. Token-subset match
    final candidates = <Map<String, dynamic>>[];
    final neutralModifiers = {'plain', 'steamed', 'white', 'cooked'};

    for (var item in _nutritionTable) {
      final nameTokens = _tokenize(item['name'] as String);
      final aliases = List<String>.from(item['aliases'] ?? []);

      bool matched = false;
      int matchedTokensCount = 0;

      // Check name token subset
      if (nameTokens.isNotEmpty &&
          nameTokens.every((t) => queryTokens.contains(t))) {
        matched = true;
        matchedTokensCount = nameTokens.length;
      }

      // Check aliases token subset
      if (!matched) {
        for (var alias in aliases) {
          final aliasTokens = _tokenize(alias);
          if (aliasTokens.isEmpty) continue;

          // Single-token alias strict rule
          if (aliasTokens.length == 1) {
            final t = aliasTokens.first;
            // Check if query is exactly that token + neutral modifiers
            final nonNeutralQueryTokens = queryTokens
                .where((qt) => !neutralModifiers.contains(qt))
                .toList();
            if (nonNeutralQueryTokens.length == 1 &&
                nonNeutralQueryTokens.first == t) {
              matched = true;
              matchedTokensCount = 1;
              break;
            }
          } else {
            // Multi-token alias
            if (aliasTokens.every((t) => queryTokens.contains(t))) {
              matched = true;
              matchedTokensCount = aliasTokens.length;
              break;
            }
          }
        }
      }

      if (matched) {
        candidates.add({
          'item': item,
          'matchedTokensCount': matchedTokensCount,
          'nameLength': (item['name'] as String).length,
        });
      }
    }

    if (candidates.isEmpty) return null;

    // Sort by most matched tokens wins, then longest (most specific) name
    candidates.sort((a, b) {
      final cmp1 = (b['matchedTokensCount'] as int).compareTo(
        a['matchedTokensCount'] as int,
      );
      if (cmp1 != 0) return cmp1;
      return (b['nameLength'] as int).compareTo(a['nameLength'] as int);
    });

    return _mapToResult(candidates.first['item'] as Map<String, dynamic>);
  }

  NutritionLookupResult _mapToResult(Map<String, dynamic> item) {
    final per100g = item['per100g'] as Map<String, dynamic>?;
    final perServing = item['perServing'] as Map<String, dynamic>?;
    
    // nutrition_table.json generator uses 'per100g' specifically. 
    final isPer100g = per100g != null;
    final nutSource = per100g ?? perServing ?? {};

    return NutritionLookupResult(
      id: item['id'] as String? ?? 'unknown',
      name: item['name'] as String? ?? 'Unknown',
      baseNutrition: FoodNutrition(
        kcal: (nutSource['kcal'] as num?)?.toDouble() ?? 0.0,
        proteinG: (nutSource['protein_g'] as num?)?.toDouble() ?? 0.0,
        carbsG: (nutSource['carbs_g'] as num?)?.toDouble() ?? 0.0,
        fatG: (nutSource['fat_g'] as num?)?.toDouble() ?? 0.0,
      ),
      isPer100g: isPer100g,
      servingGrams: (item['defaultPortionG'] as num?)?.toDouble(), // Default serving grams in JSON
      baseQuantityUnit: item['base_quantity_unit'] as String?,
      provenance: 'local_db',
    );
  }

  List<String> _tokenize(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .trim();
    if (cleaned.isEmpty) return [];
    return cleaned.split(RegExp(r'\s+'));
  }

  String _normalize(String input) {
    return _tokenize(input).join(' ');
  }
}
