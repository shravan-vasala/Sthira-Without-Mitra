import 'dart:convert';
import 'package:flutter/services.dart';

class NutritionLookupService {
  List<Map<String, dynamic>> _nutritionTable = [];
  bool _isLoaded = false;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final jsonString = await rootBundle.loadString('assets/data/nutrition_table.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _nutritionTable = List<Map<String, dynamic>>.from(jsonList);
      _isLoaded = true;
    } catch (e) {
      print('Failed to load nutrition table: $e');
    }
  }

  /// Returns the matched item if found, otherwise null.
  /// Uses a basic fuzzy/normalized matching against name and aliases.
  Map<String, dynamic>? match(String dishName) {
    if (!_isLoaded || dishName.trim().isEmpty) return null;

    final query = _normalize(dishName);

    // 1. Exact match on name
    for (var item in _nutritionTable) {
      if (_normalize(item['name'] as String) == query) {
        return item;
      }
    }

    // 2. Exact match on aliases
    for (var item in _nutritionTable) {
      final aliases = List<String>.from(item['aliases'] ?? []);
      for (var alias in aliases) {
        if (_normalize(alias) == query) {
          return item;
        }
      }
    }

    // 3. Partial match (if query is inside name or alias)
    for (var item in _nutritionTable) {
      final name = _normalize(item['name'] as String);
      if (name.contains(query) || query.contains(name)) {
        return item;
      }
      final aliases = List<String>.from(item['aliases'] ?? []);
      for (var alias in aliases) {
        final normAlias = _normalize(alias);
        if (normAlias.contains(query) || query.contains(normAlias)) {
          return item;
        }
      }
    }

    return null;
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
